-----------------------------------------------------------------------------
-- Component   : top
-- Description : Top-level entity for the DE2-115 FPGA. Instantiates the
--               provided debounce and LCD controller components together
--               with this project's vend_periph, and maps all switches,
--               keys, LEDs, and 7-segment displays to their logical
--               vending-machine functions.
--
-- The debounce, clDivide, and lcd_controller1 (plus its internal
-- sub-components: generator1, generatorUnit, pollUnit, displayUnit,
-- decoder_32bit, decoder_4bit) component interfaces below have been
-- checked directly against the actual provided VHDL source files and are
-- confirmed correct, including:
--   - The real entity name is "debounce" (singular), not "debouncer",
--     and it operates on ONE bit at a time (not a bus) - hence the
--     generate statement creating 19 instances below, one per switch/key.
--   - lcd_controller1's lcd_DATA port is OUT, not inout: the underlying
--     implementation never reads back from the LCD (lcd_RW is always
--     driven low), so LCD_DATA is declared as a plain output here too.
--   - clDivide's input clock port is named "clkIn" (note casing).
--   - lcd_controller1 displays HEX characters (0-9, A-F) per nibble, not
--     true decimal/BCD - but since this project's BCD outputs (from
--     convert2bcd) only ever produce nibble values 0-9, they display
--     correctly as the same digit characters with no further conversion
--     needed. Only inA(7 downto 0) and inB(11 downto 0) are actually
--     displayed by the provided hardware (as "PRO:XX" and "$X.YZ"
--     respectively) - the remaining upper bits of inA/inB are ignored by
--     the display, though they must still be present to satisfy the
--     32-bit port width.
--
-- Switch assignment (documented here and also belongs in the README):
--   SW(3 downto 0)   : coins      (Dollar=SW3, Quarter=SW2, Dime=SW1, Nickel=SW0)
--   SW(5 downto 4)   : mode       ("00" Vend, "01" Program, "10" Free, "11" Cancel)
--   SW(6)            : enter
--   SW(8 downto 7)   : product    (product number 0-3, using 2 of the 4 possible codes per 3 products + idle)
--   SW(9)            : product_valid
--   SW(10)           : accept
--   SW(14 downto 11) : passcode   (compared against the programmed value in vend_periph)
--   SW(15)           : soft_reset
--   SW(17 downto 16) : unused / spare
--   KEY(3)           : hard_reset (active-low key, inverted internally to active-high)
--   KEY(2 downto 0)  : unused
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    port (
        CLOCK_50 : in    std_logic;
        SW       : in    std_logic_vector(17 downto 0);
        KEY      : in    std_logic_vector(3 downto 0);
        LEDR     : out   std_logic_vector(17 downto 0);
        LEDG     : out   std_logic_vector(8 downto 0);
        HEX0, HEX1, HEX2, HEX3 : out std_logic_vector(6 downto 0);
        HEX4, HEX5, HEX6, HEX7 : out std_logic_vector(6 downto 0);
        LCD_DATA : out   std_logic_vector(7 downto 0);
        LCD_EN   : out   std_logic;
        LCD_ON   : out   std_logic;
        LCD_RS   : out   std_logic;
        LCD_RW   : out   std_logic
    );
end entity top;

architecture structural of top is

    -----------------------------------------------------------------------
    -- vend_periph component declaration.
    -----------------------------------------------------------------------
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

    -----------------------------------------------------------------------
    -- Provided debounce component (per the actual provided source: a
    -- single-bit debouncer, instantiated once per switch/key via a
    -- generate statement below - NOT a single bus-wide instantiation).
    -----------------------------------------------------------------------
    component debounce is
        generic (
            timeout_cycles : positive
        );
        port (
            clk              : in  std_logic;
            switch           : in  std_logic;
            switch_debounced : out std_logic
        );
    end component;

    -----------------------------------------------------------------------
    -- Provided LCD clock divider (confirmed against the actual provided
    -- clDivide.vhd source). Despite the source file's own comment
    -- referencing a 27 MHz input (producing 270 KHz), the actual counter
    -- value implements roughly a /2002 division regardless of input
    -- frequency; feeding it CLOCK_50 (50 MHz) yields approximately 25 kHz,
    -- which is comfortably within typical LCD controller timing
    -- tolerances and works correctly here.
    -----------------------------------------------------------------------
    component clDivide is
        port (
            clkIn  : in  std_logic;
            clkOut : out std_logic
        );
    end component;

    -----------------------------------------------------------------------
    -- Provided LCD controller (matches the actual provided source
    -- exactly - confirmed against lcd_controller1.vhd). Note lcd_DATA is
    -- OUT, not inout: this implementation is write-only to the LCD
    -- (lcd_RW is always driven low in the underlying displayUnit/
    -- generator1 sub-components), so the top-level LCD_DATA port does
    -- not need to be inout either - see the fix to LCD_DATA's port mode
    -- in the entity declaration above.
    -----------------------------------------------------------------------
    component lcd_controller1 is
        port (
            clk       : in    std_logic;
            enable    : in    std_logic;
            lcdDataIn : in    std_logic_vector(7 downto 0);
            inA       : in    std_logic_vector(31 downto 0);
            inB       : in    std_logic_vector(31 downto 0);
            lcd_RS    : out   std_logic;
            lcd_RW    : out   std_logic;
            lcd_EN    : out   std_logic;
            lcd_ON    : out   std_logic;
            lcd_DATA  : out   std_logic_vector(7 downto 0);
            enIN      : out   std_logic;
            enDI      : out   std_logic;
            enPL      : out   std_logic;
            ready     : out   std_logic;
            start     : out   std_logic
        );
    end component;

    -----------------------------------------------------------------------
    -- SegDecoder, reused here purely for the optional HEX7 mode debug
    -- display (decodes the lower 4 bits of mode_out_sig as a hex digit).
    -----------------------------------------------------------------------
    component SegDecoder is
        port (
            bcd : in  std_logic_vector(3 downto 0);
            seg : out std_logic_vector(6 downto 0)
        );
    end component;

    -- Debouncer input/output buses: SW(17 downto 0) & KEY(3), 19 bits.
    signal switch_raw        : std_logic_vector(18 downto 0);
    signal switch_debounced  : std_logic_vector(18 downto 0);

    -- Individual debounced signals, broken out for readability.
    signal db_coins         : std_logic_vector(3 downto 0);
    signal db_mode          : std_logic_vector(1 downto 0);
    signal db_enter         : std_logic;
    signal db_product       : std_logic_vector(1 downto 0);
    signal db_product_valid : std_logic;
    signal db_accept        : std_logic;
    signal db_passcode      : std_logic_vector(3 downto 0);
    signal db_soft_reset    : std_logic;
    signal db_key3          : std_logic; -- debounced KEY(3), still active-low
    signal hard_reset_active_high : std_logic;

    -- vend_periph outputs
    signal leds_out         : std_logic_vector(25 downto 0);
    signal seven_seg_total  : std_logic_vector(20 downto 0); -- HEX2-0
    signal seven_seg_change : std_logic_vector(20 downto 0); -- HEX6-4
    signal price_lcd_bcd    : std_logic_vector(11 downto 0);
    signal product_out_sig  : std_logic_vector(1 downto 0);
    signal mode_out_sig     : std_logic_vector(6 downto 0);
    signal mode_debug_seg   : std_logic_vector(6 downto 0);

    -- LCD support signals
    signal lcd_clk     : std_logic;
    signal lcd_inA      : std_logic_vector(31 downto 0);
    signal lcd_inB      : std_logic_vector(31 downto 0);
    signal lcd_dummy_in : std_logic_vector(7 downto 0);

begin

    -----------------------------------------------------------------------
    -- Debounce instantiation: the actual provided "debounce" component
    -- (confirmed from the real source file) operates on a single bit at
    -- a time, so all 19 switch/key inputs (SW17-0 plus KEY3) are
    -- debounced via 19 individual instances using a generate statement,
    -- rather than one bus-wide instantiation.
    -----------------------------------------------------------------------
    switch_raw <= KEY(3) & SW;

    debounce_gen : for i in 0 to 18 generate
        debounce_inst : debounce
            generic map (
                timeout_cycles => 150
            )
            port map (
                clk              => CLOCK_50,
                switch           => switch_raw(i),
                switch_debounced => switch_debounced(i)
            );
    end generate debounce_gen;

    -----------------------------------------------------------------------
    -- Break out the debounced bus into named signals.
    -----------------------------------------------------------------------
    db_coins         <= switch_debounced(3 downto 0);
    db_mode          <= switch_debounced(5 downto 4);
    db_enter         <= switch_debounced(6);
    db_product       <= switch_debounced(8 downto 7);
    db_product_valid <= switch_debounced(9);
    db_accept        <= switch_debounced(10);
    db_passcode      <= switch_debounced(14 downto 11);
    db_soft_reset    <= switch_debounced(15);
    -- switch_debounced(17 downto 16) intentionally unused (spare switches)
    db_key3          <= switch_debounced(18);

    -- KEY(3) is active-low; invert to produce an active-high hard_reset.
    hard_reset_active_high <= not db_key3;

    -----------------------------------------------------------------------
    -- vend_periph instantiation.
    -----------------------------------------------------------------------
    vend_periph_inst : vend_periph
        generic map (
            prescale_N => 23
        )
        port map (
            clk           => CLOCK_50,
            rst           => db_soft_reset,
            hard_rst      => hard_reset_active_high,
            accept        => db_accept,
            coins         => db_coins,
            mode          => db_mode,
            enter         => db_enter,
            product_valid => db_product_valid,
            product       => db_product,
            passcode      => db_passcode,
            leds          => leds_out,
            SevenSegSet2  => seven_seg_total,
            SevenSegSet1  => seven_seg_change,
            price_LCD     => price_lcd_bcd,
            product_out   => product_out_sig,
            mode_out      => mode_out_sig
        );

    -----------------------------------------------------------------------
    -- LED mapping: leds_out(25 downto 0) splits into LEDG(8 downto 0)
    -- (the first 9 bits, per dispense_fsm's documented bit ordering where
    -- position 0 = LEDG0) and LEDR(17 downto 0) (the remaining 18 bits).
    -----------------------------------------------------------------------
    LEDG <= leds_out(8 downto 0);
    LEDR <= leds_out(25 downto 9);

    -----------------------------------------------------------------------
    -- 7-segment display mapping:
    --   HEX2-0 : running total  (seven_seg_total, hundreds/tens/ones)
    --   HEX6-4 : change due     (seven_seg_change, hundreds/tens/ones)
    --   HEX7   : mode debug display (optional, per the manual)
    --   HEX3   : unused, blanked (active-low blank = all-1s)
    -----------------------------------------------------------------------
    HEX0 <= seven_seg_total(6 downto 0);
    HEX1 <= seven_seg_total(13 downto 7);
    HEX2 <= seven_seg_total(20 downto 14);

    HEX4 <= seven_seg_change(6 downto 0);
    HEX5 <= seven_seg_change(13 downto 7);
    HEX6 <= seven_seg_change(20 downto 14);

    mode_debug_seg_inst : SegDecoder
        port map (
            bcd => mode_out_sig(3 downto 0),
            seg => mode_debug_seg
        );

    HEX3 <= (others => '1'); -- blank, unused
    -- HEX7 debug display: pack {mode_reg, effective_mode} (the lower 4
    -- bits of mode_out_sig) into a BCD-like nibble value (0-15) for
    -- direct visual debugging on the HEX7 display via a local SegDecoder
    -- instance, rather than driving raw bits onto 7-segment outputs.
    HEX7 <= mode_debug_seg;

    -----------------------------------------------------------------------
    -- LCD instantiation, per the manual's explicit template.
    -----------------------------------------------------------------------
    lcd_divide_inst : clDivide
        port map (
            clkIn  => CLOCK_50,
            clkOut => lcd_clk
        );

    lcd_dummy_in <= (others => '0');

    -- Zero-pad product_out (2b) and price_LCD (12b BCD) up to the LCD
    -- controller's 32-bit inA/inB inputs.
    lcd_inA <= std_logic_vector(to_unsigned(0, 30)) & product_out_sig;
    lcd_inB <= std_logic_vector(to_unsigned(0, 20)) & price_lcd_bcd;

    lcd : lcd_controller1
        port map (
            clk       => lcd_clk,
            enable    => '1',
            lcdDataIn => lcd_dummy_in,
            inA       => lcd_inA,
            inB       => lcd_inB,
            lcd_RS    => LCD_RS,
            lcd_RW    => LCD_RW,
            lcd_EN    => LCD_EN,
            lcd_ON    => LCD_ON,
            lcd_DATA  => LCD_DATA,
            enIN      => open,
            enDI      => open,
            enPL      => open,
            ready     => open,
            start     => open
        );

end architecture structural;
