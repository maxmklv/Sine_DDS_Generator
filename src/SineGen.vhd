----------------------------------------------------------------------------------
-- Engineer: Maxim Mikhaylov
-- 
-- Design Name: Sine Wave Audio Generator
-- Module Name: SineGen - Behavior
-- Target Devices: Nexys A7-100T
-- Tool Versions: Vivado 2023.1.1
-- Description: Sine wave signal generator using a direct digital synthesis (DDS)  
-- approach to generate audio tones with adjustable frequency and volume.

-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity SineGen is
  Port 
  ( CLK100MHZ : in std_logic;              -- Clock (100 MHz)
    SW        : in unsigned(15 downto 0);  -- Switches
    
    AUD_PWM : out std_logic;
    AUD_SD  : out std_logic
   
  );
end SineGen;

architecture Behavior of SineGen is

-- signals
signal TC               : std_logic;
signal FsCount          : unsigned(9 downto 0);
signal PhaseAccum       : unsigned(11 downto 0);
signal sSine            : unsigned(9 downto 0);
signal sGain            : unsigned(3 downto 0);
signal Sine_x_Gain      : unsigned(13 downto 0);
signal D                : unsigned(11 downto 0);
signal SineTableData    : unsigned(9 downto 0);
signal SineTableAddress : unsigned(9 downto 0);
signal AmplifiedSine    : unsigned(9 downto 0);

-- data type to hold 1024 10-bit sine values from 0 to PI/2
type T_SineTable is array(0 to 1023) of unsigned(9 downto 0);
 
-- fuction to fill the table with those values
function CreateSineTable return T_SineTable is 
  variable Phase     : real;
  variable Sine      : integer;
  variable SineTable : T_SineTable;
begin
  for i in 0 to 1023 loop
    Phase        := MATH_PI*(real(i)/2048.0);
    Sine         := integer(512.0 + 511.0 * sin(Phase));
    SineTable(i) := to_unsigned(Sine, 10);
  end loop;
  return SineTable;
end function;
   
-- physical sine table ROM memory
constant SineTable : T_SineTable := CreateSineTable;
  
begin

  -- 10-bit counter
  process(CLK100MHZ)
  begin
    if rising_edge(CLK100MHZ) then
      if FsCount = "1111111111" then
        FsCount <= (others => '0');
      else
        FsCount <= FsCount + 1;
      end if;
    end if;
  end process;
    
  TC <= '1' when FsCount = "1111111111" else '0';
  
  -- Phase Accumulator
  process(CLK100MHZ)
  begin
    if rising_edge(CLK100MHZ) then
    D <= PhaseAccum + SW(15 downto 8);
      if TC = '1' then
        PhaseAccum <= D; 
      end if;
    end if;
  end process;
        
   -- Sine Generator
   
   -- exploit horizontal symmetry of sine wave
   SineTableAddress <= PhaseAccum(9 downto 0) when PhaseAccum(10) = '0' else not PhaseAccum(9 downto 0);
   
   -- read sine wave value from Block RAM
   process(CLK100MHZ)
   begin
     if rising_edge(CLK100MHZ) then
       SineTableData <= SineTable(to_integer(SineTableAddress));
     end if;
   end process;
   
   -- exploit vertical symmetry of sine wave
   sSine <= SineTableData when PhaseAccum(11) = '0' else not SineTableData; 
   
   -- Gain Adjust
   process(SW(2 downto 0)) -- process to turn 3 bit switches input + 1 to 4 bit sGain signal
     variable temp : integer;
   begin
     temp := to_integer(SW(2 downto 0));
     temp := temp + 1;
     sGain <= to_unsigned(temp, 4);
   end process;
  
   Sine_x_Gain <= sSine * sGain;
   AmplifiedSine <= Sine_x_Gain(12 downto 3);
   
   -- Pulse Width Modulator
   AUD_PWM <= '1' when AmplifiedSine > FsCount else '0';
   
   AUD_SD <= '1';
    
end Behavior;
