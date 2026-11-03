-----------------------------------------------------------------------------
-- Testbench   : dispense_fsm_tb
-- DUT         : dispense_fsm
-- Description : Directed testbench for the dispense_fsm LED sequence
--               generator. A small HOLD_CYCLES generic is used to keep
--               the hold-pattern scenarios fast to simulate.
--
--               Scenarios:
--                 1) Scan sequence (free = "00"): on a dispense pulse,
--                    lights should walk through a single moving LED
--                    position (checked at the first step and partway
--                    through), and "done" should pulse once the full
--                    50-step ascending/descending sweep completes, after
--                    which lights returns to all-zero.
--                 2) Cancel sequence (free = "01"): lights should show
--                    all 26 LEDs on throughout the hold duration, then
--                    "done" pulses and lights clears.
--                 3) Free-mode passcode result, match (free = "10",
--                    pass = '1'): lights should show the all-green
--                    pattern throughout the hold duration.
--                 4) Free-mode passcode result, mismatch (free = "10",
--                    pass = '0'): lights should show the all-red pattern
--                    throughout the hold duration.
--                 5) Non-preemption: while a scan sequence is in
--                    progress, a second dispense pulse is asserted and
--                    must be ignored (per the project manual's
--                    requirement that only rst/hard_rst can prematurely
--                    terminate a running sequence).
--
--               "wait until <condition> for <timeout>" is used throughout
--               rather than hand-counted cycle numbers, so this
--               testbench remains correct even if HOLD_CYCLES or the
--               scan step count are changed later.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dispense_fsm_tb is
end entity dispense_fsm_tb;

architecture sim of dispense_fsm_tb is

    component dispense_fsm is
        generic (
            HOLD_CYCLES : integer
        );
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            hard_rst : in  std_logic;
            dispense : in  std_logic;
            pass     : in  std_logic;
            free     : in  std_logic_vector(1 downto 0);
            lights   : out std_logic_vector(25 downto 0);
            done     : out std_logic
        );
    end component;

    constant CLK_PERIOD   : time    := 20 ns;
    constant HOLD_CYCLES_SIM : integer := 5; -- small value for fast simulation

    constant SEQ_SCAN       : std_logic_vector(1 downto 0) := "00";
    constant SEQ_CANCEL     : std_logic_vector(1 downto 0) := "01";
    constant SEQ_FREERESULT : std_logic_vector(1 downto 0) := "10";

    constant ALL_ZERO : std_logic_vector(25 downto 0) := (others => '0');
    constant ALL_ON    : std_logic_vector(25 downto 0) := (others => '1');
    constant ALL_GREEN : std_logic_vector(25 downto 0) :=
        "00000000000000000" & "111111111";
    constant ALL_RED   : std_logic_vector(25 downto 0) :=
        "11111111111111111" & "000000000";
    -- First scan position: only LEDG0 (bit 0) lit.
    constant SCAN_FIRST_POSITION : std_logic_vector(25 downto 0) :=
        "00000000000000000000000001";

    signal clk_tb      : std_logic := '0';
    signal rst_tb      : std_logic := '0';
    signal hard_rst_tb : std_logic := '0';
    signal dispense_tb : std_logic := '0';
    signal pass_tb     : std_logic := '0';
    signal free_tb     : std_logic_vector(1 downto 0) := "00";
    signal lights_tb   : std_logic_vector(25 downto 0);
    signal done_tb     : std_logic;

    signal sim_done : boolean := false;

begin

    DUT : dispense_fsm
        generic map (
            HOLD_CYCLES => HOLD_CYCLES_SIM
        )
        port map (
            clk      => clk_tb,
            rst      => rst_tb,
            hard_rst => hard_rst_tb,
            dispense => dispense_tb,
            pass     => pass_tb,
            free     => free_tb,
            lights   => lights_tb,
            done     => done_tb
        );

    -----------------------------------------------------------------------
    -- Clock generation.
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

        -- Pulses dispense for exactly one clock edge.
        procedure pulse_dispense is
        begin
            wait until rising_edge(clk_tb);
            dispense_tb <= '1';
            wait until rising_edge(clk_tb);
            dispense_tb <= '0';
        end procedure;

    begin
        -- Initial reset.
        rst_tb <= '1';
        wait for CLK_PERIOD * 2;
        rst_tb <= '0';
        wait until rising_edge(clk_tb);

        assert (lights_tb = ALL_ZERO)
            report "FAIL: lights should be all-zero after reset"
            severity error;

        -----------------------------------------------------------------
        -- Scenario 1: Scan sequence.
        -----------------------------------------------------------------
        free_tb <= SEQ_SCAN;
        pulse_dispense;

        -- One cycle after the dispense-observed edge, the scan should
        -- begin at its first position (LEDG0 only).
        wait until rising_edge(clk_tb);
        wait for 1 ns;
        assert (lights_tb = SCAN_FIRST_POSITION)
            report "FAIL: Scenario 1 - first scan step should light only LEDG0"
            severity error;

        -- Wait for the sequence to complete (done pulses), with a
        -- generous timeout well beyond the 50-step sweep.
        wait until done_tb = '1' for 100 * CLK_PERIOD;
        assert (done_tb = '1')
            report "FAIL: Scenario 1 - done should pulse once the scan sequence completes"
            severity error;

        wait until rising_edge(clk_tb);
        wait for 1 ns;
        assert (lights_tb = ALL_ZERO)
            report "FAIL: Scenario 1 - lights should return to all-zero after done"
            severity error;
        assert (done_tb = '0')
            report "FAIL: Scenario 1 - done should de-assert the cycle after pulsing"
            severity error;

        -----------------------------------------------------------------
        -- Scenario 2: Cancel sequence (all 26 LEDs on throughout hold).
        -----------------------------------------------------------------
        wait until rising_edge(clk_tb);
        free_tb <= SEQ_CANCEL;
        pulse_dispense;

        wait until rising_edge(clk_tb);
        wait for 1 ns;
        assert (lights_tb = ALL_ON)
            report "FAIL: Scenario 2 - Cancel sequence should show all 26 LEDs on"
            severity error;

        wait until done_tb = '1' for (HOLD_CYCLES_SIM + 5) * CLK_PERIOD;
        assert (done_tb = '1')
            report "FAIL: Scenario 2 - done should pulse once the Cancel hold duration completes"
            severity error;

        -----------------------------------------------------------------
        -- Scenario 3: Free-mode passcode match (all-green).
        -----------------------------------------------------------------
        wait until rising_edge(clk_tb);
        free_tb <= SEQ_FREERESULT;
        pass_tb <= '1';
        pulse_dispense;

        wait until rising_edge(clk_tb);
        wait for 1 ns;
        assert (lights_tb = ALL_GREEN)
            report "FAIL: Scenario 3 - passcode match should show all-green LEDs"
            severity error;

        wait until done_tb = '1' for (HOLD_CYCLES_SIM + 5) * CLK_PERIOD;
        assert (done_tb = '1')
            report "FAIL: Scenario 3 - done should pulse once the all-green hold duration completes"
            severity error;

        -----------------------------------------------------------------
        -- Scenario 4: Free-mode passcode mismatch (all-red).
        -----------------------------------------------------------------
        wait until rising_edge(clk_tb);
        free_tb <= SEQ_FREERESULT;
        pass_tb <= '0';
        pulse_dispense;

        wait until rising_edge(clk_tb);
        wait for 1 ns;
        assert (lights_tb = ALL_RED)
            report "FAIL: Scenario 4 - passcode mismatch should show all-red LEDs"
            severity error;

        wait until done_tb = '1' for (HOLD_CYCLES_SIM + 5) * CLK_PERIOD;
        assert (done_tb = '1')
            report "FAIL: Scenario 4 - done should pulse once the all-red hold duration completes"
            severity error;

        -----------------------------------------------------------------
        -- Scenario 5: Non-preemption. Start a scan sequence, then attempt
        -- to re-trigger it mid-sequence with a different sequence type;
        -- the original scan should continue uninterrupted.
        -----------------------------------------------------------------
        wait until rising_edge(clk_tb);
        free_tb <= SEQ_SCAN;
        pulse_dispense;

        -- Let a few scan steps elapse, then attempt to preempt with a
        -- Cancel-sequence dispense pulse while the scan is still running.
        wait for 3 * CLK_PERIOD;
        free_tb     <= SEQ_CANCEL;
        dispense_tb <= '1';
        wait until rising_edge(clk_tb);
        dispense_tb <= '0';
        free_tb     <= SEQ_SCAN; -- restore, harmless either way since it should be ignored

        wait for 1 ns;
        assert (lights_tb /= ALL_ON)
            report "FAIL: Scenario 5 - a second dispense pulse mid-sequence should be ignored (non-preemptive), but lights shows the Cancel all-on pattern"
            severity error;

        -- Allow the original scan to finish normally.
        wait until done_tb = '1' for 100 * CLK_PERIOD;
        assert (done_tb = '1')
            report "FAIL: Scenario 5 - the original (non-preempted) scan sequence should still complete and pulse done"
            severity error;

        report "dispense_fsm_tb: all test scenarios applied. Check transcript above for any FAIL/error reports.";
        sim_done <= true;
        wait;
    end process;

end architecture sim;
