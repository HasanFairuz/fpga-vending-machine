-----------------------------------------------------------------------------
-- Component   : PreScale
-- Description : Clock divider circuit (based on the Lab 6 reference
--               design) used to slow down the 50MHz FPGA input clock to a
--               rate suitable for human-paced switch interaction with the
--               vending machine.
--
--               An N-bit counter free-runs on every rising edge of clkIN.
--               The divided output clock, clkOUT, is taken from the
--               counter's most significant bit, giving clkOUT a period of
--               2^N input clock cycles (i.e. clkOUT toggles every 2^(N-1)
--               input cycles).
--
--               The generic prescale_N controls the counter width, and is
--               intended to be set small for fast ModelSim simulation
--               (e.g. 3-4 bits) and larger for real FPGA emulation
--               (suggested ~23 bits per the project manual, giving roughly
--               a 6Hz divided clock from a 50MHz input).
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PreScale is
    generic (
        prescale_N : integer := 23
    );
    port (
        clkIN  : in  std_logic;
        rst    : in  std_logic;
        clkOUT : out std_logic
    );
end entity PreScale;

architecture behavioral of PreScale is

    signal counter : unsigned(prescale_N - 1 downto 0);

begin

    process (clkIN, rst)
    begin
        if rst = '1' then
            counter <= (others => '0');
        elsif rising_edge(clkIN) then
            counter <= counter + 1;
        end if;
    end process;

    clkOUT <= counter(prescale_N - 1);

end architecture behavioral;
