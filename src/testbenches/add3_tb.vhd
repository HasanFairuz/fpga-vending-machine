-----------------------------------------------------------------------------
-- Testbench   : add3_tb
-- DUT         : add3
-- Description : Exhaustive testbench for the add3 combinational component.
--               Since add3 has only 16 possible 4-bit inputs, every input
--               value is driven and checked against its expected output,
--               giving 100% input-space coverage. Expected outputs for
--               inputs 0-9 follow the add-3 truth table in the project
--               manual (Fig. 1); inputs 10-15 are unreachable don't-care
--               cases in normal operation and are checked against this
--               design's defined default output of "0000".
--
--               Each test vector is checked with an assert statement; any
--               mismatch is reported with severity error in the
--               transcript without halting simulation, so the full set of
--               16 vectors is always exercised in a single run regardless
--               of any individual failure.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity add3_tb is
end entity add3_tb;

architecture sim of add3_tb is

    component add3 is
        port (
            A : in  std_logic_vector(3 downto 0);
            S : out std_logic_vector(3 downto 0)
        );
    end component;

    signal A_tb : std_logic_vector(3 downto 0);
    signal S_tb : std_logic_vector(3 downto 0);

    -- Expected output for every possible 4-bit input, indexed 0-15.
    type expected_array_type is array (0 to 15) of std_logic_vector(3 downto 0);
    constant EXPECTED : expected_array_type := (
        0  => "0000",  -- 0 -> 0
        1  => "0001",  -- 1 -> 1
        2  => "0010",  -- 2 -> 2
        3  => "0011",  -- 3 -> 3
        4  => "0100",  -- 4 -> 4
        5  => "1000",  -- 5 -> 8
        6  => "1001",  -- 6 -> 9
        7  => "1010",  -- 7 -> 10
        8  => "1011",  -- 8 -> 11
        9  => "1100",  -- 9 -> 12
        10 => "0000",  -- 10 -> unreachable, defined default 0
        11 => "0000",  -- 11 -> unreachable, defined default 0
        12 => "0000",  -- 12 -> unreachable, defined default 0
        13 => "0000",  -- 13 -> unreachable, defined default 0
        14 => "0000",  -- 14 -> unreachable, defined default 0
        15 => "0000"   -- 15 -> unreachable, defined default 0
    );

begin

    DUT : add3
        port map (
            A => A_tb,
            S => S_tb
        );

    stimulus : process
    begin
        for i in 0 to 15 loop
            A_tb <= std_logic_vector(to_unsigned(i, 4));
            wait for 10 ns;

            assert (S_tb = EXPECTED(i))
                report "FAIL: add3 input " & integer'image(i) &
                       " expected " & integer'image(to_integer(unsigned(EXPECTED(i)))) &
                       " got " & integer'image(to_integer(unsigned(S_tb)))
                severity error;

            wait for 10 ns;
        end loop;

        report "add3_tb: all 16 test vectors applied. Check transcript above for any FAIL/error reports.";
        wait;
    end process;

end architecture sim;
