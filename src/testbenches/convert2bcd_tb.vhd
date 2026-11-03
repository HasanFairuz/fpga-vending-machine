-----------------------------------------------------------------------------
-- Testbench   : convert2bcd_tb
-- DUT         : convert2bcd
-- Description : Exhaustive testbench for the convert2bcd structural
--               component. All 256 possible 8-bit binary inputs are
--               driven, and the resulting 12-bit BCD output is checked
--               against an independently-computed expected value (using
--               plain integer division/modulo arithmetic to extract the
--               hundreds, tens, and ones digits), rather than re-deriving
--               the DUT's own double-dabble/add3 algorithm. This keeps
--               the testbench's correctness independent of the DUT's
--               internal implementation.
--
--               Each test vector is checked with an assert statement; any
--               mismatch is reported with severity error in the
--               transcript without halting simulation, so the full set of
--               256 vectors is always exercised in a single run.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity convert2bcd_tb is
end entity convert2bcd_tb;

architecture sim of convert2bcd_tb is

    component convert2bcd is
        port (
            binary : in  std_logic_vector(7 downto 0);
            bcd    : out std_logic_vector(11 downto 0)
        );
    end component;

    signal binary_tb : std_logic_vector(7 downto 0);
    signal bcd_tb     : std_logic_vector(11 downto 0);

begin

    DUT : convert2bcd
        port map (
            binary => binary_tb,
            bcd    => bcd_tb
        );

    stimulus : process
        variable n            : integer;
        variable hundreds_exp : integer;
        variable tens_exp     : integer;
        variable ones_exp     : integer;
        variable expected_bcd : std_logic_vector(11 downto 0);
    begin
        for n in 0 to 255 loop
            binary_tb <= std_logic_vector(to_unsigned(n, 8));
            wait for 10 ns;

            -- Independent golden model: plain decimal digit decomposition,
            -- not derived from the DUT's add3/shift algorithm.
            hundreds_exp := n / 100;
            tens_exp     := (n mod 100) / 10;
            ones_exp     := n mod 10;

            expected_bcd := std_logic_vector(to_unsigned(hundreds_exp, 4)) &
                             std_logic_vector(to_unsigned(tens_exp, 4)) &
                             std_logic_vector(to_unsigned(ones_exp, 4));

            assert (bcd_tb = expected_bcd)
                report "FAIL: convert2bcd input " & integer'image(n) &
                       " expected bcd=" & integer'image(hundreds_exp) &
                       integer'image(tens_exp) & integer'image(ones_exp) &
                       " got hundreds/tens/ones=" &
                       integer'image(to_integer(unsigned(bcd_tb(11 downto 8)))) &
                       integer'image(to_integer(unsigned(bcd_tb(7 downto 4)))) &
                       integer'image(to_integer(unsigned(bcd_tb(3 downto 0))))
                severity error;

            wait for 10 ns;
        end loop;

        report "convert2bcd_tb: all 256 test vectors applied. Check transcript above for any FAIL/error reports.";
        wait;
    end process;

end architecture sim;
