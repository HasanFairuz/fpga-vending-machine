-----------------------------------------------------------------------------
-- Testbench   : vend_periph_tb
-- DUT         : vend_periph
-- Description : Directed testbench for the vend_periph peripheral wrapper
--               (PreScale + vend_unit + dispense_fsm + mode registration +
--               passcode validation + BCD/7-segment conversion).
--
--               vend_periph internally divides its input clock via
--               PreScale before that slower clock reaches any sequential
--               logic. This testbench instantiates the DUT with a small
--               prescale_N generic (3, giving a slow_clk period of 8
--               input clock cycles) so that internal state changes are
--               observable within a practical simulation time - this
--               differs from the FPGA-emulation default of 23, and is
--               exactly the kind of generic override the project manual
--               anticipates for simulation use.
--
--               Since the internal slow_clk signal is not exposed as a
--               port, this testbench does not attempt to synchronize
--               directly to it. Instead, a SLOW_CLK_PERIOD constant is
--               derived from the known prescale_N value, and stimulus
--               changes are followed by a wait of at least two full
--               slow_clk periods before checking results - this is
--               standard-VHDL portable and does not rely on any
--               simulator-specific hierarchical signal probing.
--
--               Three scenarios are exercised:
--                 1) Mode registration: assert mode=Vend with an enter
--                    pulse, confirm mode_out reflects the registered
--                    mode.
--                 2) Vend mode purchase: select a product, insert coins
--                    sufficient to cover its price, and confirm the LED
--                    output transitions away from all-zero (indicating
--                    the dispense_fsm scan sequence has been triggered).
--                 3) Free mode passcode validation: a correct passcode
--                    ("1111", matching vend_periph's programmed
--                    FREE_PASSCODE constant) should produce an all-green
--                    LED pattern; an incorrect passcode should produce an
--                    all-red LED pattern.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vend_periph_tb is
end entity vend_periph_tb;

architecture sim of vend_periph_tb is

    component vend_periph is
        generic (
            prescale_N : integer
        );
        port (
            clk           : in  std_logic;
            rst           : in  std_logic;
            hard_rst      : in  std_logic;
            accept        : in  std_logic;
            coins         : in  std_logic_vector(3 downto 0);
            mode          : in  std_logic_vector(1 downto 0);
            enter         : in  std_logic;
            product_valid : in  std_logic;
            product       : in  std_logic_vector(1 downto 0);
            passcode      : in  std_logic_vector(3 downto 0);
            leds          : out std_logic_vector(25 downto 0);
            SevenSegSet2  : out std_logic_vector(20 downto 0);
            SevenSegSet1  : out std_logic_vector(20 downto 0);
            price_LCD     : out std_logic_vector(11 downto 0);
            product_out   : out std_logic_vector(1 downto 0);
            mode_out      : out std_logic_vector(6 downto 0)
        );
    end component;

    constant PRESCALE_N_SIM   : integer := 3;
    constant CLK_PERIOD       : time    := 20 ns;
    -- Full slow_clk period = 2^PRESCALE_N_SIM input clock cycles.
    constant SLOW_CLK_PERIOD  : time    := (2 ** PRESCALE_N_SIM) * CLK_PERIOD;
    -- Generous settle wait: two full slow_clk periods, safely covering any
    -- phase alignment between the input clock and the internal divided
    -- clock without relying on direct internal signal probing.
    constant SETTLE_WAIT      : time    := 2 * SLOW_CLK_PERIOD;

    -- Coin encodings.
    constant DOLLAR  : std_logic_vector(3 downto 0) := "1000";
    constant QUARTER : std_logic_vector(3 downto 0) := "0100";
    constant DIME    : std_logic_vector(3 downto 0) := "0010";
    constant NICKEL  : std_logic_vector(3 downto 0) := "0001";
    constant NO_COIN : std_logic_vector(3 downto 0) := "0000";

    -- Mode encodings.
    constant MODE_VEND   : std_logic_vector(1 downto 0) := "00";
    constant MODE_FREE    : std_logic_vector(1 downto 0) := "10";

    -- Programmed passcode (must match vend_periph's FREE_PASSCODE constant).
    constant CORRECT_PASSCODE : std_logic_vector(3 downto 0) := "1111";
    constant WRONG_PASSCODE   : std_logic_vector(3 downto 0) := "0000";

    signal clk_tb           : std_logic := '0';
    signal rst_tb           : std_logic;
    signal hard_rst_tb      : std_logic;
    signal accept_tb        : std_logic;
    signal coins_tb         : std_logic_vector(3 downto 0);
    signal mode_tb          : std_logic_vector(1 downto 0);
    signal enter_tb         : std_logic;
    signal product_valid_tb : std_logic;
    signal product_tb       : std_logic_vector(1 downto 0);
    signal passcode_tb      : std_logic_vector(3 downto 0);
    signal leds_tb          : std_logic_vector(25 downto 0);
    signal seven_seg2_tb    : std_logic_vector(20 downto 0);
    signal seven_seg1_tb    : std_logic_vector(20 downto 0);
    signal price_lcd_tb     : std_logic_vector(11 downto 0);
    signal product_out_tb   : std_logic_vector(1 downto 0);
    signal mode_out_tb      : std_logic_vector(6 downto 0);

    signal sim_done : boolean := false;

    -- All-green pattern: lights(8 downto 0) = '1', lights(25 downto 9) = '0'.
    constant ALL_GREEN : std_logic_vector(25 downto 0) :=
        "0000000000000000" & "0" & "111111111";
    -- All-red pattern: lights(25 downto 9) = '1', lights(8 downto 0) = '0'.
    constant ALL_RED : std_logic_vector(25 downto 0) :=
        "1111111111111111" & "1" & "000000000";

begin

    DUT : vend_periph
        generic map (
            prescale_N => PRESCALE_N_SIM
        )
        port map (
            clk           => clk_tb,
            rst           => rst_tb,
            hard_rst      => hard_rst_tb,
            accept        => accept_tb,
            coins         => coins_tb,
            mode          => mode_tb,
            enter         => enter_tb,
            product_valid => product_valid_tb,
            product       => product_tb,
            passcode      => passcode_tb,
            leds          => leds_tb,
            SevenSegSet2  => seven_seg2_tb,
            SevenSegSet1  => seven_seg1_tb,
            price_LCD     => price_lcd_tb,
            product_out   => product_out_tb,
            mode_out      => mode_out_tb
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

        procedure check_std_logic_vec(actual, expected : std_logic_vector; msg : string) is
        begin
            assert (actual = expected)
                report "FAIL: " & msg
                severity error;
        end procedure;

        -- Pulses enter for one settle-wait window, synchronized loosely to
        -- the slow_clk period rather than the fast input clock, since
        -- enter is sampled by internal logic running on slow_clk.
        procedure pulse_enter is
        begin
            enter_tb <= '1';
            wait for SETTLE_WAIT;
            enter_tb <= '0';
            wait for SETTLE_WAIT;
        end procedure;

    begin
        -- Global setup / reset.
        rst_tb           <= '1';
        hard_rst_tb       <= '0';
        accept_tb         <= '0';
        coins_tb          <= NO_COIN;
        mode_tb           <= MODE_VEND;
        enter_tb          <= '0';
        product_valid_tb  <= '0';
        product_tb        <= "00";
        passcode_tb       <= NO_COIN;
        wait for SETTLE_WAIT;
        rst_tb <= '0';
        wait for SETTLE_WAIT;

        -----------------------------------------------------------------
        -- Scenario 1: Mode registration.
        -----------------------------------------------------------------
        mode_tb <= MODE_VEND;
        pulse_enter;

        assert (mode_out_tb(3 downto 2) = MODE_VEND)
            report "FAIL: Scenario 1 - mode_out should reflect registered Vend mode"
            severity error;

        -----------------------------------------------------------------
        -- Scenario 2: Vend mode purchase. Select product 1 (default price
        -- 47 cents per vend_unit's defaults), insert coins to cover it,
        -- confirm leds transitions away from all-zero (dispense_fsm scan
        -- sequence triggered).
        -----------------------------------------------------------------
        product_tb <= "01";
        product_valid_tb <= '1';
        wait for SETTLE_WAIT;
        product_valid_tb <= '0';
        wait for SETTLE_WAIT;

        -- Insert Dollar (100) - comfortably covers the 47 cent price.
        -- Note: accept is held for a full SETTLE_WAIT window (2 slow_clk
        -- periods) rather than a single precisely-timed slow_clk edge,
        -- since slow_clk itself is not exposed as a port for direct
        -- synchronization (see file header). This means more than one
        -- slow_clk edge may sample accept = '1' with the same coin still
        -- presented, potentially accumulating the Dollar more than once.
        -- This is harmless for this scenario's assertion (leds_tb is only
        -- checked for being non-zero, not an exact value, and any total
        -- at or above 100 cents still exceeds the 47 cent price either
        -- way) - but if a future edit checks an exact r_total or change
        -- value following a coin insertion like this, the stimulus here
        -- would need tightening to guarantee single-edge timing.
        coins_tb  <= DOLLAR;
        accept_tb <= '1';
        wait for SETTLE_WAIT;
        coins_tb  <= NO_COIN;
        accept_tb <= '0';
        wait for SETTLE_WAIT * 2; -- allow dispense_fsm's scan sequence to begin

        assert (leds_tb /= (leds_tb'range => '0'))
            report "FAIL: Scenario 2 - leds should be non-zero once dispense_fsm's scan sequence begins"
            severity error;

        -- Allow the full light show (50 scan steps, per dispense_fsm) plus
        -- margin to complete and the machine to return to idle before the
        -- next scenario begins.
        wait for SLOW_CLK_PERIOD * 60;

        -----------------------------------------------------------------
        -- Scenario 3: Free mode, correct passcode -> all-green LEDs.
        -----------------------------------------------------------------
        mode_tb <= MODE_FREE;
        enter_tb <= '1';
        wait for SETTLE_WAIT;

        passcode_tb <= CORRECT_PASSCODE;
        accept_tb   <= '1';
        wait for SETTLE_WAIT;
        accept_tb   <= '0';
        wait for SETTLE_WAIT;

        check_std_logic_vec(leds_tb, ALL_GREEN,
            "Scenario 3 - correct passcode should produce an all-green LED pattern");

        enter_tb <= '0';
        wait for SLOW_CLK_PERIOD * 20; -- allow hold duration + return to idle
        -- Note: mode_tb is set back to MODE_VEND here, but since this is
        -- not accompanied by an enter pulse, vend_periph's mode_reg
        -- (which only updates when enter = '1') does not actually change
        -- away from MODE_FREE at this point - it stays MODE_FREE going
        -- into Scenario 4 below, which sets mode_tb to MODE_FREE again
        -- anyway. This does not affect Scenario 4's correctness: the
        -- passcode FSM's own GRANTED-state exit condition (enter = '0',
        -- checked independently of mode_reg) already returned
        -- passcode_state to WAIT_ENTER above, so Scenario 4 still begins
        -- from a clean state.
        mode_tb  <= MODE_VEND;
        wait for SETTLE_WAIT;

        -----------------------------------------------------------------
        -- Scenario 4: Free mode, incorrect passcode -> all-red LEDs.
        -----------------------------------------------------------------
        mode_tb  <= MODE_FREE;
        enter_tb <= '1';
        wait for SETTLE_WAIT;

        passcode_tb <= WRONG_PASSCODE;
        accept_tb   <= '1';
        wait for SETTLE_WAIT;
        accept_tb   <= '0';
        wait for SETTLE_WAIT;

        check_std_logic_vec(leds_tb, ALL_RED,
            "Scenario 4 - incorrect passcode should produce an all-red LED pattern");

        enter_tb <= '0';
        wait for SLOW_CLK_PERIOD * 20;
        mode_tb  <= MODE_VEND;

        report "vend_periph_tb: all test scenarios applied. Check transcript above for any FAIL/error reports.";
        sim_done <= true;
        wait;
    end process;

end architecture sim;
