-----------------------------------------------------------------------------
-- Component   : dispense_fsm
-- Description : Sequential circuit that generates the LED light-show
--               output patterns required by the project specification,
--               selected via the "free" and "pass" inputs (encoding
--               scheme defined below, chosen by this hardware designer).
--
-- Encoding scheme for "free" (2 bits) - selects which light pattern to
-- run when "dispense" is pulsed:
--   "00" : Scan sequence - used for a successful Vend mode purchase,
--          a successful Program mode price write, and a successful Free
--          mode dispense (these three cases all share the same sequence
--          per the project manual). The LEDs light one at a time in a
--          single moving point, ascending from the right-most LEDG0
--          through LEDG8 then LEDR0 through LEDR17, and then descending
--          back down to LEDG0.
--   "01" : Cancel sequence - all 26 LEDs (LEDR and LEDG) are illuminated
--          together, held for a fixed duration, then turned off.
--   "10" : Free mode passcode result sequence - uses the "pass" input to
--          choose between an all-green ("pass" = '1', successful match)
--          or all-red ("pass" = '0', failed match) light pattern, held
--          for a fixed duration, then turned off.
--   "11" : unused / reserved.
--
-- "pass" is only examined when free = "10"; it is ignored for all other
-- sequence types.
--
-- "done" pulses for one clock cycle on the final cycle of whichever
-- sequence is running, signalling completion back to the higher-level
-- circuitry (this output is aliased to done_trans at the top level).
--
-- This circuit is non-preemptive: once a sequence begins, only rst or
-- hard_rst can prematurely terminate it (per the project manual).
--
-- HOLD_CYCLES is a generic controlling how many clock cycles the
-- all-green / all-red / all-on patterns remain lit before turning off,
-- analogous to the prescale_N generic used elsewhere in this project to
-- allow a short hold time during simulation and a longer, human-visible
-- hold time during FPGA emulation.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dispense_fsm is
    generic (
        HOLD_CYCLES : integer := 16  -- cycles to hold all-on/all-green/all-red patterns
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
end entity dispense_fsm;

architecture behavioral of dispense_fsm is

    constant SEQ_SCAN   : std_logic_vector(1 downto 0) := "00";
    constant SEQ_CANCEL : std_logic_vector(1 downto 0) := "01";
    constant SEQ_FREERESULT : std_logic_vector(1 downto 0) := "10";

    -- Total unique positions in one full ascending+descending scan cycle.
    -- 26 positions ascending (index 0..25), then 24 positions descending
    -- (index 24 down to 1; the two endpoints 25 and 0 are each visited
    -- only once to avoid a doubled / stalled-looking light at the peak
    -- and at the start/end), for 26 + 24 = 50 total steps.
    constant SCAN_STEPS : integer := 50;

    type fsm_state_type is (IDLE, RUN_SCAN, RUN_HOLD, FINISH);
    signal state : fsm_state_type;

    -- Scan position counter (0 to SCAN_STEPS-1).
    signal scan_count : integer range 0 to SCAN_STEPS - 1;

    -- Hold-duration counter for the all-on/all-green/all-red patterns.
    signal hold_count : integer range 0 to HOLD_CYCLES - 1;

    -- Latched copy of which sequence type and pass result are running,
    -- captured at the moment "dispense" is observed so that the running
    -- sequence is unaffected by any subsequent changes on free/pass.
    signal seq_type_reg : std_logic_vector(1 downto 0);
    signal pass_reg     : std_logic;

    signal lights_reg : std_logic_vector(25 downto 0);
    signal done_reg   : std_logic;

    -- Maps a scan position (0 to 25) to a one-hot 26-bit light pattern.
    -- Position 0 = LEDG0 (lights(0)) ... position 25 = LEDR17 (lights(25)).
    function scan_position_to_lights(pos : integer) return std_logic_vector is
        variable result : std_logic_vector(25 downto 0) := (others => '0');
    begin
        result(pos) := '1';
        return result;
    end function;

    -- Converts the linear scan_count (0 to SCAN_STEPS-1) into the actual
    -- LED position being lit: ascending for the first 26 counts (0..25),
    -- then descending for the remaining 24 counts (24..1).
    function scan_count_to_position(count : integer) return integer is
    begin
        if count <= 25 then
            return count;               -- ascending: 0,1,2,...,25
        else
            return 50 - count;          -- descending: 24,23,...,1
        end if;
    end function;

begin

    process (clk, rst, hard_rst)
    begin
        if hard_rst = '1' or rst = '1' then
            state        <= IDLE;
            scan_count   <= 0;
            hold_count   <= 0;
            seq_type_reg <= (others => '0');
            pass_reg     <= '0';
            lights_reg   <= (others => '0');
            done_reg     <= '0';
        elsif rising_edge(clk) then
            done_reg <= '0'; -- default: de-assert unless this is the final cycle below

            case state is
                when IDLE =>
                    lights_reg <= (others => '0');
                    if dispense = '1' then
                        seq_type_reg <= free;
                        pass_reg     <= pass;
                        scan_count   <= 0;
                        hold_count   <= 0;
                        if free = SEQ_SCAN then
                            state <= RUN_SCAN;
                        else
                            state <= RUN_HOLD;
                        end if;
                    end if;

                when RUN_SCAN =>
                    lights_reg <= scan_position_to_lights(scan_count_to_position(scan_count));
                    if scan_count = SCAN_STEPS - 1 then
                        state <= FINISH;
                    else
                        scan_count <= scan_count + 1;
                    end if;

                when RUN_HOLD =>
                    if seq_type_reg = SEQ_CANCEL then
                        lights_reg <= (others => '1'); -- all 26 LEDs on
                    elsif pass_reg = '1' then
                        -- LEDG8 downto LEDG0 only (bits 8 downto 0 = '1',
                        -- bits 25 downto 9 = '0', 17 zero-bits + 9 one-bits = 26)
                        lights_reg <= "00000000000000000" & "111111111";
                    else
                        -- LEDR17 downto LEDR0 only (bits 25 downto 9 = '1',
                        -- bits 8 downto 0 = '0', 17 one-bits + 9 zero-bits = 26)
                        lights_reg <= "11111111111111111" & "000000000";
                    end if;

                    if hold_count = HOLD_CYCLES - 1 then
                        state <= FINISH;
                    else
                        hold_count <= hold_count + 1;
                    end if;

                when FINISH =>
                    lights_reg <= (others => '0');
                    done_reg   <= '1';
                    state      <= IDLE;

            end case;
        end if;
    end process;

    lights <= lights_reg;
    done   <= done_reg;

end architecture behavioral;
