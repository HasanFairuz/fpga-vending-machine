-----------------------------------------------------------------------------
-- Testbench   : priority_enc_tb
-- DUT         : priority_enc
-- Description : Exhaustive testbench for the priority_enc combinational
--               component. All 16 possible input_coins values are driven
--               with both valid = '1' and valid = '0' (32 combinations
--               total), giving 100% input-space coverage. This includes
--               every one-hot coin case (Dollar/Quarter/Dime/Nickel
--               individually) as well as every possible non-one-hot
--               combination, verifying that priority resolution
--               (Dollar > Quarter > Dime > Nickel) is correctly applied
--               when multiple coin bits are asserted simultaneously, and
--               that valid = '0' forces the output to "000" regardless
--               of input_coins.
--
--               Each test vector is checked with an assert statement; any
--               mismatch is reported with severity error in the
--               transcript without halting simulation.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity priority_enc_tb is
end entity priority_enc_tb;

architecture sim of priority_enc_tb is

    component priority_enc is
        port (
            input_coins : in  std_logic_vector(3 downto 0);
            valid       : in  std_logic;
            value       : out std_logic_vector(2 downto 0)
        );
    end component;

    signal input_coins_tb : std_logic_vector(3 downto 0);
    signal valid_tb        : std_logic;
    signal value_tb         : std_logic_vector(2 downto 0);

    -- Expected encoded value for every input_coins combination, valid='1'.
    -- Index = to_integer(unsigned(input_coins)).
    type expected_array_type is array (0 to 15) of std_logic_vector(2 downto 0);
    constant EXPECTED_VALID : expected_array_type := (
        0  => "000",  -- 0000: no coin
        1  => "001",  -- 0001: Nickel only
        2  => "010",  -- 0010: Dime only
        3  => "010",  -- 0011: Dime+Nickel -> Dime wins
        4  => "011",  -- 0100: Quarter only
        5  => "011",  -- 0101: Quarter+Nickel -> Quarter wins
        6  => "011",  -- 0110: Quarter+Dime -> Quarter wins
        7  => "011",  -- 0111: Quarter+Dime+Nickel -> Quarter wins
        8  => "100",  -- 1000: Dollar only
        9  => "100",  -- 1001: Dollar+Nickel -> Dollar wins
        10 => "100",  -- 1010: Dollar+Dime -> Dollar wins
        11 => "100",  -- 1011: Dollar+Dime+Nickel -> Dollar wins
        12 => "100",  -- 1100: Dollar+Quarter -> Dollar wins
        13 => "100",  -- 1101: Dollar+Quarter+Nickel -> Dollar wins
        14 => "100",  -- 1110: Dollar+Quarter+Dime -> Dollar wins
        15 => "100"   -- 1111: all coins -> Dollar wins
    );

begin

    DUT : priority_enc
        port map (
            input_coins => input_coins_tb,
            valid       => valid_tb,
            value       => value_tb
        );

    stimulus : process
    begin
        -- Phase 1: valid = '1' for all 16 input_coins combinations.
        valid_tb <= '1';
        for i in 0 to 15 loop
            input_coins_tb <= std_logic_vector(to_unsigned(i, 4));
            wait for 10 ns;

            assert (value_tb = EXPECTED_VALID(i))
                report "FAIL (valid=1): input_coins=" & integer'image(i) &
                       " expected " & integer'image(to_integer(unsigned(EXPECTED_VALID(i)))) &
                       " got " & integer'image(to_integer(unsigned(value_tb)))
                severity error;

            wait for 10 ns;
        end loop;

        -- Phase 2: valid = '0' for all 16 input_coins combinations - output
        -- must always be forced to "000" regardless of input_coins.
        valid_tb <= '0';
        for i in 0 to 15 loop
            input_coins_tb <= std_logic_vector(to_unsigned(i, 4));
            wait for 10 ns;

            assert (value_tb = "000")
                report "FAIL (valid=0): input_coins=" & integer'image(i) &
                       " expected 000 (forced by valid=0)" &
                       " got " & integer'image(to_integer(unsigned(value_tb)))
                severity error;

            wait for 10 ns;
        end loop;

        report "priority_enc_tb: all 32 test vectors applied. Check transcript above for any FAIL/error reports.";
        wait;
    end process;

end architecture sim;
