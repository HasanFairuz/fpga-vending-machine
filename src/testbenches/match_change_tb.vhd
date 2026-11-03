-----------------------------------------------------------------------------
-- Testbench   : match_change_tb
-- DUT         : match_change
-- Description : Directed testbench for the match_change sequential
--               component. Exercises:
--                 1) Reset behaviour (complete='0', change_due=0).
--                 2) Vend mode, insufficient coins: complete must stay
--                    de-asserted and change_due must stay zero while
--                    coins < price.
--                 3) Vend mode, sufficient coins: once coins >= price,
--                    complete must pulse for exactly one clock cycle and
--                    change_due must equal coins - price. Uses the
--                    project manual's own example values (coins=140,
--                    price=47, expected change=93).
--                 4) Single-pulse verification: complete must return to
--                    '0' on the cycle immediately following its pulse,
--                    even though the coins >= price condition remains
--                    true.
--                 5) Free mode with zero coins inserted: complete must
--                    pulse immediately (effective price is forced to
--                    zero, so 0 >= 0 is trivially true), with
--                    change_due = 0, allowing a free dispense with no
--                    payment required.
--                 6) Free mode with coins accidentally inserted:
--                    change_due must equal the full coins amount (all of
--                    it returned), since the effective price is zero.
--                 7) Program mode with done='0': complete must remain
--                    de-asserted regardless of coins/price (price
--                    matching logic does not apply in this mode).
--                 8) Program mode with a done='1' pulse: complete must
--                    pulse for exactly one cycle, with change_due forced
--                    to zero (no money returned during programming).
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity match_change_tb is
end entity match_change_tb;

architecture sim of match_change_tb is

    component match_change is
        port (
            clk        : in  std_logic;
            rst        : in  std_logic;
            coins      : in  unsigned(7 downto 0);
            mode       : in  std_logic_vector(1 downto 0);
            done       : in  std_logic;
            price      : in  unsigned(7 downto 0);
            complete   : out std_logic;
            change_due : out unsigned(7 downto 0)
        );
    end component;

    constant CLK_PERIOD : time := 20 ns;

    signal clk_tb        : std_logic := '0';
    signal rst_tb        : std_logic := '0';
    signal coins_tb       : unsigned(7 downto 0) := (others => '0');
    signal mode_tb        : std_logic_vector(1 downto 0) := "00";
    signal done_tb         : std_logic := '0';
    signal price_tb        : unsigned(7 downto 0) := (others => '0');
    signal complete_tb     : std_logic;
    signal change_due_tb   : unsigned(7 downto 0);

    constant MODE_VEND    : std_logic_vector(1 downto 0) := "00";
    constant MODE_PROGRAM : std_logic_vector(1 downto 0) := "01";
    constant MODE_FREE    : std_logic_vector(1 downto 0) := "10";

    -- Stops the free-running clock once the stimulus process has finished,
    -- so that "run -all" in ModelSim terminates cleanly.
    signal sim_done : boolean := false;

begin

    DUT : match_change
        port map (
            clk        => clk_tb,
            rst        => rst_tb,
            coins      => coins_tb,
            mode       => mode_tb,
            done       => done_tb,
            price      => price_tb,
            complete   => complete_tb,
            change_due => change_due_tb
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
    -- Stimulus and checking. Same race-free timing pattern as
    -- accumulator_tb: stimulus changes happen immediately after an
    -- observed rising edge, checks happen shortly after the following
    -- edge.
    -----------------------------------------------------------------------
    stimulus : process

        procedure check_complete(expected : std_logic; msg : string) is
        begin
            assert (complete_tb = expected)
                report "FAIL: " & msg & " - expected complete=" & std_logic'image(expected) &
                       " got=" & std_logic'image(complete_tb)
                severity error;
        end procedure;

        procedure check_change(expected : integer; msg : string) is
        begin
            assert (change_due_tb = to_unsigned(expected, 8))
                report "FAIL: " & msg & " - expected change_due=" & integer'image(expected) &
                       " got=" & integer'image(to_integer(change_due_tb))
                severity error;
        end procedure;

    begin
        -- 1) Reset: complete='0', change_due=0.
        rst_tb <= '1';
        wait for CLK_PERIOD * 2;
        check_complete('0', "after initial reset");
        check_change(0, "after initial reset");
        rst_tb <= '0';
        wait until rising_edge(clk_tb);

        -- 2) Vend mode, insufficient coins (coins=20, price=47).
        mode_tb  <= MODE_VEND;
        price_tb <= to_unsigned(47, 8);
        coins_tb <= to_unsigned(20, 8);
        wait until rising_edge(clk_tb);
        wait for 1 ns;
        check_complete('0', "Vend mode, coins(20) < price(47)");
        check_change(0, "Vend mode, coins(20) < price(47)");

        -- 3) Vend mode, sufficient coins (coins=140, price=47).
        -- Matches the project manual's own example waveform.
        coins_tb <= to_unsigned(140, 8);
        wait until rising_edge(clk_tb); -- this edge captures the match
        wait for 1 ns;
        check_complete('1', "Vend mode, coins(140) >= price(47), complete should pulse");
        check_change(93, "Vend mode, coins(140) >= price(47), change_due should be 93");

        -- 4) Single-pulse check: on the NEXT cycle, complete must have
        -- returned to '0', even though coins >= price is still true.
        wait until rising_edge(clk_tb);
        wait for 1 ns;
        check_complete('0', "complete must de-assert one cycle after its pulse (single-cycle pulse check)");

        -- 5) Reset, then Free mode with zero coins inserted.
        rst_tb <= '1';
        wait for CLK_PERIOD * 2;
        rst_tb <= '0';
        wait until rising_edge(clk_tb);

        mode_tb  <= MODE_FREE;
        price_tb <= to_unsigned(47, 8); -- irrelevant in Free mode, should be ignored
        coins_tb <= to_unsigned(0, 8);
        wait until rising_edge(clk_tb);
        wait for 1 ns;
        check_complete('1', "Free mode, zero coins inserted: complete should pulse immediately (0 >= 0)");
        check_change(0, "Free mode, zero coins inserted: change_due should be 0");

        -- 6) Reset, then Free mode with coins accidentally inserted.
        rst_tb <= '1';
        wait for CLK_PERIOD * 2;
        rst_tb <= '0';
        wait until rising_edge(clk_tb);

        mode_tb  <= MODE_FREE;
        price_tb <= to_unsigned(47, 8);
        coins_tb <= to_unsigned(25, 8); -- accidental quarter insertion
        wait until rising_edge(clk_tb);
        wait for 1 ns;
        check_complete('1', "Free mode, 25 cents accidentally inserted: complete should pulse");
        check_change(25, "Free mode, 25 cents accidentally inserted: all 25 cents should be returned");

        -- 7) Reset, then Program mode with done='0': complete must stay
        -- de-asserted regardless of coins/price.
        rst_tb <= '1';
        wait for CLK_PERIOD * 2;
        rst_tb <= '0';
        wait until rising_edge(clk_tb);

        mode_tb  <= MODE_PROGRAM;
        done_tb  <= '0';
        price_tb <= to_unsigned(47, 8);
        coins_tb <= to_unsigned(140, 8); -- would trigger Vend-mode completion, must NOT here
        wait until rising_edge(clk_tb);
        wait for 1 ns;
        check_complete('0', "Program mode, done=0: complete must stay de-asserted regardless of coins/price");

        -- 8) Program mode, done='1' pulse: complete must pulse for one
        -- cycle, change_due forced to zero.
        done_tb <= '1';
        wait until rising_edge(clk_tb);
        wait for 1 ns;
        check_complete('1', "Program mode, done=1 pulse: complete should pulse");
        check_change(0, "Program mode, done=1 pulse: change_due must be forced to zero");
        done_tb <= '0';

        -- Single-pulse check for Program mode's completion as well.
        wait until rising_edge(clk_tb);
        wait for 1 ns;
        check_complete('0', "Program mode: complete must de-assert one cycle after its pulse");

        report "match_change_tb: all test scenarios applied. Check transcript above for any FAIL/error reports.";
        sim_done <= true;
        wait;
    end process;

end architecture sim;
