-----------------------------------------------------------------------------
-- Testbench   : accumulator_tb
-- DUT         : accumulator (which internally instantiates priority_enc)
-- Description : Directed testbench for the accumulator sequential
--               component. Exercises:
--                 1) Reset behaviour (total clears to zero).
--                 2) Running-total accumulation for each of the four coin
--                    types in sequence (Nickel, Dime, Quarter, Dollar),
--                    matching the project manual's own example waveform
--                    values (5, 15, 40, 140 cents).
--                 3) The "enable" gate: a coin insertion attempt while
--                    enable = '0' must not change the running total.
--                 4) The "complete" gate: a coin insertion attempt while
--                    complete = '1' must not change the running total
--                    (transaction already finished).
--                 5) Priority resolution under a non-one-hot input: when
--                    multiple coin bits are asserted simultaneously
--                    (Dollar + Dime), the internal priority_enc must
--                    select Dollar, and only $1.00 is accumulated (not
--                    $1.10).
--                 6) A second reset, confirming the total clears again
--                    after non-zero accumulation.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity accumulator_tb is
end entity accumulator_tb;

architecture sim of accumulator_tb is

    component accumulator is
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            enable    : in  std_logic;
            mode      : in  std_logic_vector(1 downto 0);
            selection : in  std_logic_vector(3 downto 0);
            complete  : in  std_logic;
            total     : out unsigned(7 downto 0)
        );
    end component;

    constant CLK_PERIOD : time := 20 ns;

    signal clk_tb       : std_logic := '0';
    signal rst_tb       : std_logic := '0';
    signal enable_tb     : std_logic := '0';
    signal mode_tb       : std_logic_vector(1 downto 0) := "00";
    signal selection_tb  : std_logic_vector(3 downto 0) := "0000";
    signal complete_tb   : std_logic := '0';
    signal total_tb      : unsigned(7 downto 0);

    constant NICKEL  : std_logic_vector(3 downto 0) := "0001";
    constant DIME    : std_logic_vector(3 downto 0) := "0010";
    constant QUARTER : std_logic_vector(3 downto 0) := "0100";
    constant DOLLAR  : std_logic_vector(3 downto 0) := "1000";

    -- Stops the free-running clock once the stimulus process has finished,
    -- so that "run -all" in ModelSim terminates cleanly rather than
    -- running indefinitely.
    signal sim_done : boolean := false;

begin

    DUT : accumulator
        port map (
            clk       => clk_tb,
            rst       => rst_tb,
            enable    => enable_tb,
            mode      => mode_tb,
            selection => selection_tb,
            complete  => complete_tb,
            total     => total_tb
        );

    -----------------------------------------------------------------------
    -- Clock generation: free-running, 20 ns period, stops once sim_done
    -- is set so that "run -all" terminates cleanly.
    -----------------------------------------------------------------------
    clk_process : process
    begin
        while not sim_done loop
            clk_tb <= '0';
            wait for CLK_PERIOD / 2;
            clk_tb <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -----------------------------------------------------------------------
    -- Stimulus and checking.
    --
    -- Timing pattern used throughout: stimulus signals are always changed
    -- immediately after a rising clock edge has been observed (giving a
    -- full half-period of setup margin before the next edge samples
    -- them), and total_tb is checked shortly after the following rising
    -- edge has been processed. This avoids any race between a signal
    -- change and a coincident clock edge.
    -----------------------------------------------------------------------
    stimulus : process

        procedure check_total(expected : integer; msg : string) is
        begin
            assert (total_tb = to_unsigned(expected, 8))
                report "FAIL: " & msg & " - expected total=" & integer'image(expected) &
                       " got=" & integer'image(to_integer(total_tb))
                severity error;
        end procedure;

    begin
        -- 1) Reset: total must be zero.
        rst_tb <= '1';
        wait for CLK_PERIOD * 2;
        check_total(0, "after initial reset");
        rst_tb <= '0';
        wait until rising_edge(clk_tb);

        -- 2) Insert Nickel (5 cents).
        enable_tb    <= '1';
        complete_tb  <= '0';
        selection_tb <= NICKEL;
        wait until rising_edge(clk_tb); -- this edge captures the Nickel insertion
        wait for 1 ns;                  -- allow registered output to settle
        check_total(5, "after Nickel insertion");

        -- 3) Insert Dime (10 cents) -> total = 15.
        selection_tb <= DIME;
        wait until rising_edge(clk_tb);
        wait for 1 ns;
        check_total(15, "after Dime insertion");

        -- 4) Insert Quarter (25 cents) -> total = 40.
        selection_tb <= QUARTER;
        wait until rising_edge(clk_tb);
        wait for 1 ns;
        check_total(40, "after Quarter insertion");

        -- 5) Insert Dollar (100 cents) -> total = 140.
        selection_tb <= DOLLAR;
        wait until rising_edge(clk_tb);
        wait for 1 ns;
        check_total(140, "after Dollar insertion");

        -- 6) Enable gate test: attempt a Nickel insertion with enable='0'.
        -- Total must remain unchanged at 140.
        enable_tb    <= '0';
        selection_tb <= NICKEL;
        wait until rising_edge(clk_tb);
        wait for 1 ns;
        check_total(140, "enable gate (enable=0) should block insertion");
        enable_tb <= '1';

        -- 7) Completion gate test: attempt a Nickel insertion with
        -- complete='1'. Total must remain unchanged at 140.
        wait until rising_edge(clk_tb);
        complete_tb  <= '1';
        selection_tb <= NICKEL;
        wait until rising_edge(clk_tb);
        wait for 1 ns;
        check_total(140, "completion gate (complete=1) should block insertion");
        complete_tb <= '0';

        -- 8) Reset again -> total must clear back to zero.
        wait until rising_edge(clk_tb);
        rst_tb <= '1';
        wait for CLK_PERIOD * 2;
        check_total(0, "after second reset");
        rst_tb <= '0';
        wait until rising_edge(clk_tb);

        -- 9) Priority resolution test: assert Dollar + Dime simultaneously
        -- (non-one-hot input). The internal priority_enc must select
        -- Dollar (highest priority), so only 100 cents should accumulate,
        -- not 110.
        enable_tb    <= '1';
        complete_tb  <= '0';
        selection_tb <= DOLLAR or DIME; -- "1010"
        wait until rising_edge(clk_tb);
        wait for 1 ns;
        check_total(100, "priority resolution: Dollar+Dime simultaneous should accumulate only Dollar (100), not 110");

        report "accumulator_tb: all test scenarios applied. Check transcript above for any FAIL/error reports.";
        sim_done <= true;
        wait;
    end process;

end architecture sim;
