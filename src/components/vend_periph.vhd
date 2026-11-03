-----------------------------------------------------------------------------
-- Component   : vend_periph
-- Description : Vending machine peripheral wrapper. Interconnects
--               vend_unit and dispense_fsm, and additionally implements
--               the "higher-level" responsibilities described in the
--               project manual's Note2 (mode registration and passcode
--               validation for Free mode entry), since the project
--               manual's vend_periph port table includes the raw
--               "passcode" input directly. This component therefore owns:
--
--               1) Clock prescaling: instantiates PreScale to slow
--                  CLOCK_50 down to slow_clk, used as the clock source
--                  for every other component instantiated here.
--
--               2) Mode registration: latches the user's requested mode
--                  on the "enter" pulse.
--
--               3) Passcode validation for Free mode: per Note2, by the
--                  time vend_unit observes mode = Free, the passcode must
--                  already have been validated. vend_periph compares the
--                  "passcode" input (submitted with an "accept" pulse
--                  while "enter" is held asserted, per the project
--                  specification's Free Mode description) against a
--                  programmed constant password. A match grants Free
--                  mode (passed through to vend_unit's mode input) and
--                  triggers dispense_fsm's all-green confirmation light
--                  show; a mismatch keeps the effective mode at Vend and
--                  triggers the all-red failure light show.
--
--               4) Instantiation and interconnection of vend_unit and
--                  dispense_fsm.
--
--               5) BCD conversion (via three convert2bcd instances) of
--                  the running total, change due, and product price for
--                  use by the 7-segment displays / LCD.
--
--               6) 7-segment decoding (via SegDecoder instances) for the
--                  running total (HEX2-0) and change due (HEX6-4) digits.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vend_periph is
    generic (
        prescale_N : integer := 23
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
        SevenSegSet2  : out std_logic_vector(20 downto 0); -- running total, 3 digits
        SevenSegSet1  : out std_logic_vector(20 downto 0); -- change due, 3 digits
        price_LCD     : out std_logic_vector(11 downto 0);
        product_out   : out std_logic_vector(1 downto 0);
        mode_out      : out std_logic_vector(6 downto 0)
    );
end entity vend_periph;

architecture structural of vend_periph is

    component PreScale is
        generic (
            prescale_N : integer
        );
        port (
            clkIN  : in  std_logic;
            rst    : in  std_logic;
            clkOUT : out std_logic
        );
    end component;

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

    component convert2bcd is
        port (
            binary : in  std_logic_vector(7 downto 0);
            bcd    : out std_logic_vector(11 downto 0)
        );
    end component;

    component SegDecoder is
        port (
            bcd : in  std_logic_vector(3 downto 0);
            seg : out std_logic_vector(6 downto 0)
        );
    end component;

    -- Mode / sequence-selector constants (mirrors vend_unit and
    -- dispense_fsm's local constants, redeclared here since VHDL
    -- components do not share constants across entities).
    constant MODE_VEND    : std_logic_vector(1 downto 0) := "00";
    constant MODE_PROGRAM : std_logic_vector(1 downto 0) := "01";
    constant MODE_FREE    : std_logic_vector(1 downto 0) := "10";
    constant MODE_CANCEL  : std_logic_vector(1 downto 0) := "11";

    constant SEQ_SCAN       : std_logic_vector(1 downto 0) := "00";
    constant SEQ_CANCEL     : std_logic_vector(1 downto 0) := "01";
    constant SEQ_FREERESULT : std_logic_vector(1 downto 0) := "10";

    -- Programmed Free-mode passcode, defined here by this hardware
    -- designer. Chosen as "1111" for a simple, memorable demo-day value;
    -- change as desired.
    constant FREE_PASSCODE : std_logic_vector(3 downto 0) := "1111";

    signal slow_clk : std_logic;

    -- Mode registration
    signal mode_reg : std_logic_vector(1 downto 0);

    -- Passcode validation state
    type passcode_state_type is (WAIT_ENTER, GRANTED, DENIED);
    signal passcode_state  : passcode_state_type;
    signal free_mode_granted : std_logic;
    signal passcode_result_pulse : std_logic; -- one-cycle pulse: a pass/fail result just occurred
    signal passcode_pass : std_logic;         -- '1' = matched, '0' = failed (valid when pulse asserted)

    -- Effective mode fed to vend_unit: differs from mode_reg only when
    -- Free mode has been requested but not yet granted by a successful
    -- passcode match.
    signal effective_mode : std_logic_vector(1 downto 0);

    -- vend_unit <-> dispense_fsm interconnect
    signal vu_change     : unsigned(7 downto 0);
    signal vu_r_total    : unsigned(7 downto 0);
    signal vu_prod_price : unsigned(7 downto 0);
    signal vu_dispense   : std_logic;
    signal vu_prod_out   : std_logic_vector(1 downto 0);
    signal done_trans    : std_logic;

    -- dispense_fsm trigger arbitration: the passcode pass/fail result and
    -- vend_unit's product dispense never occur in the same cycle (the
    -- passcode result always precedes Free mode being granted, which in
    -- turn precedes vend_unit ever asserting dispense), so a simple OR
    -- combined with a selector multiplexer is safe here.
    signal fsm_dispense_trigger : std_logic;
    signal fsm_free_select      : std_logic_vector(1 downto 0);
    signal fsm_pass_select      : std_logic;

    -- BCD conversion results
    signal total_bcd  : std_logic_vector(11 downto 0);
    signal change_bcd : std_logic_vector(11 downto 0);
    signal price_bcd  : std_logic_vector(11 downto 0);

    -- 7-segment outputs for each individual digit
    signal total_seg_hundreds, total_seg_tens, total_seg_ones    : std_logic_vector(6 downto 0);
    signal change_seg_hundreds, change_seg_tens, change_seg_ones : std_logic_vector(6 downto 0);

begin

    -----------------------------------------------------------------------
    -- 1) Clock prescaler.
    -----------------------------------------------------------------------
    prescale_inst : PreScale
        generic map (
            prescale_N => prescale_N
        )
        port map (
            clkIN  => clk,
            rst    => rst,
            clkOUT => slow_clk
        );

    -----------------------------------------------------------------------
    -- 2) Mode registration: latch the user's requested mode on "enter".
    -----------------------------------------------------------------------
    process (slow_clk, rst, hard_rst)
    begin
        if hard_rst = '1' or rst = '1' then
            mode_reg <= MODE_VEND;
        elsif rising_edge(slow_clk) then
            if enter = '1' then
                mode_reg <= mode;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------
    -- 3) Passcode validation FSM for Free mode entry.
    --
    -- Per the project specification's Free Mode description:
    --   "select Mode > leave enter asserted > assert passcode > pulse
    --    accept > unassert enter"
    --
    -- WAIT_ENTER : mode_reg = Free and enter is held asserted; waiting
    --              for the user to submit a passcode via an accept pulse
    --              (checked directly here, since the user holds enter
    --              throughout passcode submission per the spec).
    -- GRANTED     : passcode matched - free_mode_granted asserted, stays
    --               asserted until enter is released or the transaction
    --               completes (done_trans).
    -- DENIED      : passcode failed - free_mode_granted remains '0';
    --               returns to WAIT_ENTER once enter is released so a
    --               retry is possible while mode_reg is still Free.
    -----------------------------------------------------------------------
    process (slow_clk, rst, hard_rst)
    begin
        if hard_rst = '1' or rst = '1' then
            passcode_state         <= WAIT_ENTER;
            free_mode_granted      <= '0';
            passcode_result_pulse  <= '0';
            passcode_pass          <= '0';
        elsif rising_edge(slow_clk) then
            passcode_result_pulse <= '0'; -- default: de-assert unless a result fires below

            if mode_reg /= MODE_FREE then
                passcode_state    <= WAIT_ENTER;
                free_mode_granted <= '0';
            else
                case passcode_state is
                    when WAIT_ENTER =>
                        if enter = '1' and accept = '1' then
                            if passcode = FREE_PASSCODE then
                                passcode_state        <= GRANTED;
                                free_mode_granted      <= '1';
                                passcode_result_pulse  <= '1';
                                passcode_pass          <= '1';
                            else
                                passcode_state        <= DENIED;
                                passcode_result_pulse  <= '1';
                                passcode_pass          <= '0';
                            end if;
                        elsif enter = '0' then
                            free_mode_granted <= '0';
                        end if;

                    when GRANTED =>
                        if enter = '0' or done_trans = '1' then
                            passcode_state    <= WAIT_ENTER;
                            free_mode_granted <= '0';
                        end if;

                    when DENIED =>
                        if enter = '0' then
                            passcode_state <= WAIT_ENTER;
                        end if;

                end case;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------
    -- Effective mode fed to vend_unit: Free mode only passes through once
    -- actually granted by a successful passcode match.
    -----------------------------------------------------------------------
    effective_mode <= MODE_FREE when (mode_reg = MODE_FREE and free_mode_granted = '1') else
                       MODE_VEND when (mode_reg = MODE_FREE and free_mode_granted = '0') else
                       mode_reg;

    -----------------------------------------------------------------------
    -- 4) vend_unit instantiation.
    -----------------------------------------------------------------------
    vend_unit_inst : vend_unit
        port map (
            clk           => slow_clk,
            rst           => rst,
            hard_rst      => hard_rst,
            enable        => accept,
            coins         => coins,
            mode          => effective_mode,
            product_valid => product_valid,
            product       => product,
            done_trans    => done_trans,
            change        => vu_change,
            r_total       => vu_r_total,
            prod_price    => vu_prod_price,
            dispense      => vu_dispense,
            prod_out      => vu_prod_out
        );

    -----------------------------------------------------------------------
    -- dispense_fsm trigger arbitration: select between vend_unit's
    -- product-dispense trigger (scan sequence, or cancel sequence when
    -- effective_mode = Cancel) and the passcode result trigger (free
    -- result sequence). These are mutually exclusive in time (see
    -- signal declaration comment above).
    -----------------------------------------------------------------------
    fsm_dispense_trigger <= vu_dispense or passcode_result_pulse;

    fsm_free_select <= SEQ_FREERESULT when passcode_result_pulse = '1' else
                        SEQ_CANCEL    when (vu_dispense = '1' and effective_mode = MODE_CANCEL) else
                        SEQ_SCAN;

    fsm_pass_select <= passcode_pass when passcode_result_pulse = '1' else '0';

    -----------------------------------------------------------------------
    -- 5) dispense_fsm instantiation.
    -----------------------------------------------------------------------
    dispense_fsm_inst : dispense_fsm
        generic map (
            HOLD_CYCLES => 16
        )
        port map (
            clk      => slow_clk,
            rst      => rst,
            hard_rst => hard_rst,
            dispense => fsm_dispense_trigger,
            pass     => fsm_pass_select,
            free     => fsm_free_select,
            lights   => leds,
            done     => done_trans
        );

    -----------------------------------------------------------------------
    -- 6) BCD conversion for display.
    -----------------------------------------------------------------------
    total_bcd_inst : convert2bcd
        port map (
            binary => std_logic_vector(vu_r_total),
            bcd    => total_bcd
        );

    change_bcd_inst : convert2bcd
        port map (
            binary => std_logic_vector(vu_change),
            bcd    => change_bcd
        );

    price_bcd_inst : convert2bcd
        port map (
            binary => std_logic_vector(vu_prod_price),
            bcd    => price_bcd
        );

    -----------------------------------------------------------------------
    -- 7-segment decoding: running total -> HEX2-0 (SevenSegSet2), change
    -- due -> HEX6-4 (SevenSegSet1). Each SevenSegSet output aggregates
    -- three 7-bit digit patterns into one 21-bit signal (hundreds, tens,
    -- ones, MSB-first).
    -----------------------------------------------------------------------
    total_hundreds_seg : SegDecoder
        port map (
            bcd => total_bcd(11 downto 8),
            seg => total_seg_hundreds
        );

    total_tens_seg : SegDecoder
        port map (
            bcd => total_bcd(7 downto 4),
            seg => total_seg_tens
        );

    total_ones_seg : SegDecoder
        port map (
            bcd => total_bcd(3 downto 0),
            seg => total_seg_ones
        );

    change_hundreds_seg : SegDecoder
        port map (
            bcd => change_bcd(11 downto 8),
            seg => change_seg_hundreds
        );

    change_tens_seg : SegDecoder
        port map (
            bcd => change_bcd(7 downto 4),
            seg => change_seg_tens
        );

    change_ones_seg : SegDecoder
        port map (
            bcd => change_bcd(3 downto 0),
            seg => change_seg_ones
        );

    SevenSegSet2 <= total_seg_hundreds & total_seg_tens & total_seg_ones;
    SevenSegSet1 <= change_seg_hundreds & change_seg_tens & change_seg_ones;

    -----------------------------------------------------------------------
    -- Remaining outputs.
    -----------------------------------------------------------------------
    price_LCD   <= price_bcd;
    product_out <= vu_prod_out;
    mode_out    <= "0" & "00" & mode_reg & effective_mode; -- debug: {mode_reg, effective_mode} packed into 7 bits

end architecture structural;
