-----------------------------------------------------------------------------
-- Testbench   : vend_unit_tb
-- DUT         : vend_unit
-- Description : Directed testbench for the vend_unit top-level integration
--               component (accumulator + match_change + price RAM +
--               product register + mode sequencing). Per the project
--               manual's Note1, done_trans is not generated automatically
--               by any component within vend_unit itself - it must be
--               applied manually by this testbench to mimic the behaviour
--               of dispense_fsm, which lives one level higher in the
--               hierarchy (inside vend_periph).
--
--               Three scenarios are exercised:
--                 1) Vend mode: select Product 1 (default price 47 cents),
--                    insert Nickel/Dime/Quarter/Dollar in sequence
--                    (matching the project manual's own example waveform
--                    running totals of 5/15/40/140), confirm dispense
--                    pulses once total >= price with change = 93, then
--                    manually pulse done_trans to return to idle.
--                 2) Cancel mode: select Product 2 (default price 130
--                    cents), insert a Quarter and a Dime (35 cents total),
--                    then switch to Cancel mode and pulse enter. Confirm
--                    dispense pulses (triggering the cancel light show)
--                    and that change reflects the full accumulated total
--                    (35), not a price-adjusted difference.
--                 3) Program mode: select Product 3 for reprogramming,
--                    accumulate a new price of 60 cents (Quarter + Quarter
--                    + Dime), commit it with a second product_valid
--                    pulse, confirm dispense pulses (vend-style light
--                    show trigger), pulse done_trans, then switch back to
--                    Vend mode and re-select Product 3 to read back its
--                    price and confirm it now reads 60 instead of the
--                    original default of 75.
--
--               Throughout, "wait until <condition>" style waits are used
--               rather than hardcoded cycle counts wherever an internal
--               FSM transition's exact timing is not the property under
--               test, making this testbench robust against minor timing
--               changes elsewhere in vend_unit's implementation.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vend_unit_tb is
end entity vend_unit_tb;

architecture sim of vend_unit_tb is

    component vend_unit is
        port (
            clk           : in  std_logic;
            rst           : in  std_logic;
            hard_rst      : in  std_logic;
            enable        : in  std_logic;
            coins         : in  std_logic_vector(3 downto 0);
            mode          : in  std_logic_vector(1 downto 0);
            product_valid : in  std_logic;
            product       : in  std_logic_vector(1 downto 0);
            done_trans    : in  std_logic;
            change        : out unsigned(7 downto 0);
            r_total       : out unsigned(7 downto 0);
            prod_price    : out unsigned(7 downto 0);
            dispense      : out std_logic;
            prod_out      : out std_logic_vector(1 downto 0)
        );
    end component;

    constant CLK_PERIOD : time     := 20 ns;

    -- Coin encodings.
    constant DOLLAR  : std_logic_vector(3 downto 0) := "1000";
    constant QUARTER : std_logic_vector(3 downto 0) := "0100";
    constant DIME    : std_logic_vector(3 downto 0) := "0010";
    constant NICKEL  : std_logic_vector(3 downto 0) := "0001";
    constant NO_COIN : std_logic_vector(3 downto 0) := "0000";

    -- Mode encodings.
    constant MODE_VEND    : std_logic_vector(1 downto 0) := "00";
    constant MODE_PROGRAM : std_logic_vector(1 downto 0) := "01";
    constant MODE_FREE    : std_logic_vector(1 downto 0) := "10";
    constant MODE_CANCEL  : std_logic_vector(1 downto 0) := "11";

    signal clk_tb           : std_logic := '0';
    signal rst_tb           : std_logic;
    signal hard_rst_tb      : std_logic;
    signal enable_tb        : std_logic;
    signal coins_tb         : std_logic_vector(3 downto 0);
    signal mode_tb          : std_logic_vector(1 downto 0);
    signal product_valid_tb : std_logic;
    signal product_tb       : std_logic_vector(1 downto 0);
    signal done_trans_tb    : std_logic;
    signal change_tb        : unsigned(7 downto 0);
    signal r_total_tb       : unsigned(7 downto 0);
    signal prod_price_tb    : unsigned(7 downto 0);
    signal dispense_tb      : std_logic;
    signal prod_out_tb      : std_logic_vector(1 downto 0);

    signal sim_done : boolean := false;

    -- Pulses a single-cycle '1' onto the given signal, synchronized to the
    -- clock, then returns it to '0'.
    procedure pulse(signal target : out std_logic; signal clk : in std_logic) is
    begin
        wait until rising_edge(clk);
        target <= '1';
        wait until rising_edge(clk);
        target <= '0';
    end procedure;

begin

    DUT : vend_unit
        port map (
            clk           => clk_tb,
            rst           => rst_tb,
            hard_rst      => hard_rst_tb,
            enable        => enable_tb,
            coins         => coins_tb,
            mode          => mode_tb,
            product_valid => product_valid_tb,
            product       => product_tb,
            done_trans    => done_trans_tb,
            change        => change_tb,
            r_total       => r_total_tb,
            prod_price    => prod_price_tb,
            dispense      => dispense_tb,
            prod_out      => prod_out_tb
        );

    -----------------------------------------------------------------------
    -- Clock generation: free-running, stops once sim_done is set.
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
    -----------------------------------------------------------------------
    stimulus : process

        procedure check_unsigned(actual : unsigned(7 downto 0); expected : integer; msg : string) is
        begin
            assert (actual = to_unsigned(expected, 8))
                report "FAIL: " & msg & " - expected " & integer'image(expected) &
                       " got " & integer'image(to_integer(actual))
                severity error;
        end procedure;

        procedure check_std_logic(actual : std_logic; expected : std_logic; msg : string) is
        begin
            assert (actual = expected)
                report "FAIL: " & msg & " - expected " & std_logic'image(expected) &
                       " got " & std_logic'image(actual)
                severity error;
        end procedure;

        procedure insert_coin(coin : std_logic_vector(3 downto 0)) is
        begin
            wait until rising_edge(clk_tb);
            coins_tb  <= coin;
            enable_tb <= '1';
            wait until rising_edge(clk_tb);
            coins_tb  <= NO_COIN;
            enable_tb <= '0';
            wait for 1 ns;
        end procedure;

    begin
        -- Global setup.
        rst_tb           <= '1';
        hard_rst_tb      <= '0';
        enable_tb        <= '0';
        coins_tb         <= NO_COIN;
        mode_tb          <= MODE_VEND;
        product_valid_tb <= '0';
        product_tb       <= "00";
        done_trans_tb    <= '0';
        wait for CLK_PERIOD * 2;
        rst_tb <= '0';
        wait until rising_edge(clk_tb);

        -----------------------------------------------------------------
        -- Scenario 1: Vend mode purchase of Product 1 (default price 47).
        -----------------------------------------------------------------
        mode_tb    <= MODE_VEND;
        product_tb <= "01";
        pulse(product_valid_tb, clk_tb);

        wait for 1 ns;
        check_unsigned(prod_price_tb, 47, "Scenario 1: Product 1 default price");
        check_std_logic(prod_out_tb(0), '1', "Scenario 1: prod_out should reflect selected product 1");

        insert_coin(NICKEL);
        check_unsigned(r_total_tb, 5, "Scenario 1: running total after Nickel");

        insert_coin(DIME);
        check_unsigned(r_total_tb, 15, "Scenario 1: running total after Dime");

        insert_coin(QUARTER);
        check_unsigned(r_total_tb, 40, "Scenario 1: running total after Quarter");

        insert_coin(DOLLAR);
        check_unsigned(r_total_tb, 140, "Scenario 1: running total after Dollar");

        -- dispense should now assert once total >= price (140 >= 47). match_change's
        -- "complete" output is itself a registered signal that observes accum_total
        -- one clock cycle after accumulator's own total_reg updates, so dispense may
        -- take one extra cycle beyond the Dollar-insertion edge to assert; wait for it
        -- explicitly rather than assuming an exact cycle count, with a timeout guard
        -- so a genuine design failure is reported instead of hanging the simulation.
        wait until dispense_tb = '1' for 5 * CLK_PERIOD;
        check_std_logic(dispense_tb, '1', "Scenario 1: dispense should assert once total >= price");
        check_unsigned(change_tb, 93, "Scenario 1: change should equal 140 - 47 = 93");

        -- Manually pulse done_trans, mimicking dispense_fsm, to return to idle.
        pulse(done_trans_tb, clk_tb);
        wait for 1 ns;
        check_std_logic(dispense_tb, '0', "Scenario 1: dispense should de-assert after done_trans");

        -----------------------------------------------------------------
        -- Scenario 2: Cancel mode mid-transaction on Product 2 (default
        -- price 130).
        -----------------------------------------------------------------
        wait until rising_edge(clk_tb);
        mode_tb    <= MODE_VEND;
        product_tb <= "10";
        pulse(product_valid_tb, clk_tb);

        wait for 1 ns;
        check_unsigned(prod_price_tb, 130, "Scenario 2: Product 2 default price");

        insert_coin(QUARTER);
        insert_coin(DIME);
        check_unsigned(r_total_tb, 35, "Scenario 2: running total after Quarter+Dime (35 cents)");

        -- Switch to Cancel mode. dispense (Cancel-mode branch) is driven
        -- combinationally from top_state = ACTIVE and is only held for a
        -- single cycle before top_state advances to DISPENSING, so we
        -- wait for the condition directly rather than a fixed number of
        -- edges, to avoid checking either too early or after the pulse
        -- has already passed.
        wait until rising_edge(clk_tb);
        mode_tb <= MODE_CANCEL;
        wait until dispense_tb = '1' for 5 * CLK_PERIOD;

        check_std_logic(dispense_tb, '1', "Scenario 2: dispense should assert in Cancel mode (light show trigger)");
        check_unsigned(change_tb, 35, "Scenario 2: change should equal the full accumulated total (35), not price-adjusted");

        pulse(done_trans_tb, clk_tb);
        wait for 1 ns;
        mode_tb <= MODE_VEND;

        -----------------------------------------------------------------
        -- Scenario 3: Program mode - reprogram Product 3's price from
        -- its default (75) to 60 cents (Quarter + Quarter + Dime).
        -----------------------------------------------------------------
        wait until rising_edge(clk_tb);
        mode_tb    <= MODE_PROGRAM;
        product_tb <= "11";
        pulse(product_valid_tb, clk_tb); -- 1st pulse: selects Product 3 for reprogramming

        insert_coin(QUARTER);
        insert_coin(QUARTER);
        insert_coin(DIME);
        check_unsigned(r_total_tb, 60, "Scenario 3: accumulated new price (60 cents)");

        pulse(product_valid_tb, clk_tb); -- 2nd pulse: commits the new price

        -- dispense (Program-mode branch) checks prog_state = PROG_DONE
        -- directly, so it should assert within one cycle of this second
        -- product_valid pulse; wait for it explicitly with a timeout
        -- guard rather than relying on an exact hand-counted cycle delay.
        wait until dispense_tb = '1' for 5 * CLK_PERIOD;

        check_std_logic(dispense_tb, '1', "Scenario 3: dispense should assert once new price is committed");

        pulse(done_trans_tb, clk_tb);
        wait for 1 ns;

        -- Switch back to Vend mode and re-select Product 3 to verify the
        -- new price was written correctly.
        wait until rising_edge(clk_tb);
        mode_tb    <= MODE_VEND;
        product_tb <= "11";
        pulse(product_valid_tb, clk_tb);

        wait for 1 ns;
        check_unsigned(prod_price_tb, 60, "Scenario 3: Product 3's price should now read 60 (reprogrammed), not 75 (default)");

        report "vend_unit_tb: all test scenarios applied. Check transcript above for any FAIL/error reports.";
        sim_done <= true;
        wait;
    end process;

end architecture sim;
