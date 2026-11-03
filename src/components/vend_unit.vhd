-----------------------------------------------------------------------------
-- Component   : vend_unit
-- Description : Sequential circuit that instantiates and coordinates the
--               accumulator and match_change components, implements the
--               price RAM and its Program-mode write sequencing, tracks
--               the currently selected product, and produces the signals
--               required to dispense a product.
--
-- Modes (per project specification):
--   "00" Vend mode    : default. Coins are inserted against the selected
--                        product's price; once enough has been inserted,
--                        change is returned and the product dispenses.
--   "01" Program mode : the coins/accept switches are instead used to
--                        accumulate a NEW price for a selected product.
--                        product_valid is pulsed twice in this mode:
--                          1st pulse - selects which product to reprogram
--                          2nd pulse - confirms the accumulated value as
--                                      the new price, writing it to RAM
--   "10" Free mode    : assumes a higher-level component has already
--                        validated the passcode and placed the system in
--                        this mode (see Note2 in the project manual).
--                        Price is treated as $0.00; any coins inserted are
--                        returned as change, and the product dispenses
--                        without requiring payment.
--   "11" Cancel mode  : per the manual's hint, the bulk of cancel
--                        behaviour (returning whatever has been inserted
--                        so far) is implemented here in vend_unit, since
--                        match_change does not handle mode = "11"
--                        internally. vend_unit reads the accumulator's
--                        running total directly, outputs it as the
--                        "change" the user is owed, and resets the
--                        transaction.
--
-- Price RAM   : a 4-entry array of 8-bit prices (cents), indexed by
--               product number 0-3. Entry 0 is always $0.00 and doubles
--               as the machine's idle/default price state. Entries 1-3
--               hold the default prices for products 1-3 on startup/hard
--               reset; one default price is set above $1.00 and one below,
--               per the manual's requirement.
--
-- Reset logic : accumulator and match_change are reset together whenever
--               a new transaction begins (i.e. whenever the top-level
--               sequencing FSM below is in the IDLE state) and immediately
--               after a transaction's dispense light show has finished
--               (done_trans observed), returning both sub-components to a
--               zeroed state ready for the next transaction.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vend_unit is
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
end entity vend_unit;

architecture behavioral of vend_unit is

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

    -- Mode constants
    constant MODE_VEND    : std_logic_vector(1 downto 0) := "00";
    constant MODE_PROGRAM : std_logic_vector(1 downto 0) := "01";
    constant MODE_FREE    : std_logic_vector(1 downto 0) := "10";
    constant MODE_CANCEL  : std_logic_vector(1 downto 0) := "11";

    -- Price RAM type: 4 entries, 8 bits each (cents). Entry 0 = $0.00.
    type price_ram_type is array (0 to 3) of unsigned(7 downto 0);

    -- Default prices: product 0 = $0.00 (idle state), product 1 = $0.47
    -- (below $1.00), product 2 = $1.30 (above $1.00), product 3 = $0.75.
    constant DEFAULT_PRICES : price_ram_type := (
        0 => to_unsigned(0, 8),
        1 => to_unsigned(47, 8),
        2 => to_unsigned(130, 8),
        3 => to_unsigned(75, 8)
    );

    signal price_ram : price_ram_type := DEFAULT_PRICES;

    -- Product register: tracks the last requested/selected product.
    signal product_reg : std_logic_vector(1 downto 0);

    -- Internal sub-component signals
    signal accum_rst      : std_logic;
    signal accum_total    : unsigned(7 downto 0);
    signal mc_rst         : std_logic;
    signal mc_done        : std_logic;
    signal mc_complete    : std_logic;
    signal mc_change_due  : unsigned(7 downto 0);
    signal selected_price : unsigned(7 downto 0);

    -- Top-level transaction sequencing FSM. Governs when accumulator and
    -- match_change are held in reset vs. actively running, and when
    -- "dispense" is asserted.
    type top_state_type is (IDLE, ACTIVE, DISPENSING);
    signal top_state : top_state_type;

    -- Program-mode sub-sequencing FSM. Governs the two-pulse
    -- product_valid protocol used to reprogram a price.
    type prog_state_type is (PROG_SELECT, PROG_ACCUM, PROG_DONE);
    signal prog_state : prog_state_type;

    -- Registered output for change, latched once available so it remains
    -- stable for display purposes even after match_change's pulse ends.
    signal change_reg : unsigned(7 downto 0);

    -- Edge detector for entry into Free mode: prevents the top-level FSM
    -- from continuously re-triggering ACTIVE/dispense every single clock
    -- cycle that mode happens to read as Free. Per Note2 in the project
    -- manual, any "hold enter to dispense multiple times" behaviour during
    -- passcode entry is the responsibility of the higher-level component
    -- that drives "mode" into vend_unit; by the time mode = Free reaches
    -- this component, a single dispense per Free-mode entry is correct.
    signal free_mode_prev : std_logic;
    signal free_mode_rising : std_logic;

begin

    free_mode_rising <= '1' when (mode = MODE_FREE and free_mode_prev = '0') else '0';

    process (clk, rst, hard_rst)
    begin
        if hard_rst = '1' or rst = '1' then
            free_mode_prev <= '0';
        elsif rising_edge(clk) then
            free_mode_prev <= '1' when (mode = MODE_FREE) else '0';
        end if;
    end process;

    -----------------------------------------------------------------------
    -- Selected price lookup (combinational read from price RAM, indexed
    -- by the currently latched product register).
    -----------------------------------------------------------------------
    selected_price <= price_ram(to_integer(unsigned(product_reg)));

    -----------------------------------------------------------------------
    -- Product register: latches the user's product selection on a
    -- product_valid pulse. In Program mode, this also doubles as the
    -- product being reprogrammed (latched during PROG_SELECT).
    -----------------------------------------------------------------------
    process (clk, rst, hard_rst)
    begin
        if hard_rst = '1' or rst = '1' then
            product_reg <= (others => '0');
        elsif rising_edge(clk) then
            if mode /= MODE_PROGRAM then
                if product_valid = '1' then
                    product_reg <= product;
                end if;
            else
                -- Program mode: only the FIRST product_valid pulse
                -- (handled by prog_state = PROG_SELECT) updates the
                -- product register; the second pulse commits the price
                -- instead of reselecting a product.
                if prog_state = PROG_SELECT and product_valid = '1' then
                    product_reg <= product;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------
    -- Top-level transaction sequencing FSM.
    -----------------------------------------------------------------------
    process (clk, rst, hard_rst)
    begin
        if hard_rst = '1' or rst = '1' then
            top_state <= IDLE;
        elsif rising_edge(clk) then
            case top_state is
                when IDLE =>
                    -- Move to ACTIVE on a product selection in Vend/Program
                    -- mode, or on entry into Free mode (rising edge only -
                    -- see free_mode_rising comment above - to avoid
                    -- re-triggering every cycle that mode remains Free).
                    if product_valid = '1' or free_mode_rising = '1' then
                        top_state <= ACTIVE;
                    end if;

                when ACTIVE =>
                    if mode = MODE_CANCEL then
                        top_state <= DISPENSING; -- cancel triggers its own light show
                    elsif mode = MODE_PROGRAM then
                        if prog_state = PROG_DONE then
                            top_state <= DISPENSING;
                        end if;
                    else
                        if mc_complete = '1' then
                            top_state <= DISPENSING;
                        end if;
                    end if;

                when DISPENSING =>
                    if done_trans = '1' then
                        top_state <= IDLE;
                    end if;

            end case;
        end if;
    end process;

    -----------------------------------------------------------------------
    -- accumulator / match_change reset control: both are held in reset
    -- whenever idle (no active transaction) or immediately after a
    -- transaction's light show has completed, ensuring a clean zero
    -- starting point for the next transaction.
    -----------------------------------------------------------------------
    accum_rst <= '1' when (rst = '1' or hard_rst = '1' or top_state = IDLE) else '0';
    mc_rst    <= accum_rst;

    -----------------------------------------------------------------------
    -- Program-mode sub-sequencing FSM: handles the two-pulse
    -- product_valid protocol (select product, then commit new price).
    -----------------------------------------------------------------------
    process (clk, rst, hard_rst)
    begin
        if hard_rst = '1' or rst = '1' then
            prog_state <= PROG_SELECT;
        elsif rising_edge(clk) then
            if mode /= MODE_PROGRAM then
                prog_state <= PROG_SELECT;
            else
                case prog_state is
                    when PROG_SELECT =>
                        if product_valid = '1' then
                            prog_state <= PROG_ACCUM;
                        end if;

                    when PROG_ACCUM =>
                        if product_valid = '1' then
                            prog_state <= PROG_DONE;
                        end if;

                    when PROG_DONE =>
                        if done_trans = '1' then
                            prog_state <= PROG_SELECT;
                        end if;

                end case;
            end if;
        end if;
    end process;

    -- mc_done: pulses match_change's "done" input for exactly one cycle,
    -- the cycle on which PROG_ACCUM transitions to PROG_DONE (i.e. the
    -- second product_valid pulse, confirming the new price).
    mc_done <= '1' when (mode = MODE_PROGRAM and prog_state = PROG_ACCUM and product_valid = '1') else '0';

    -----------------------------------------------------------------------
    -- Price RAM write: on the same cycle that mc_done pulses, commit the
    -- accumulator's running total as the new price for the product
    -- latched at the start of this Program-mode transaction.
    -----------------------------------------------------------------------
    process (clk, hard_rst)
    begin
        if hard_rst = '1' then
            price_ram <= DEFAULT_PRICES;
        elsif rising_edge(clk) then
            if mc_done = '1' then
                price_ram(to_integer(unsigned(product_reg))) <= accum_total;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------
    -- Sub-component instantiation.
    -----------------------------------------------------------------------
    accumulator_inst : accumulator
        port map (
            clk       => clk,
            rst       => accum_rst,
            enable    => enable,
            mode      => mode,
            selection => coins,
            complete  => mc_complete,
            total     => accum_total
        );

    match_change_inst : match_change
        port map (
            clk        => clk,
            rst        => mc_rst,
            coins      => accum_total,
            mode       => mode,
            done       => mc_done,
            price      => selected_price,
            complete   => mc_complete,
            change_due => mc_change_due
        );

    -----------------------------------------------------------------------
    -- Change output: in Cancel mode, the change owed is simply whatever
    -- has accumulated so far (read directly from accumulator), since the
    -- transaction is being abandoned rather than completed against a
    -- price. In all other modes, change comes from match_change's
    -- computed change_due. The result is registered so the value remains
    -- stable for display after the underlying pulse has ended.
    -----------------------------------------------------------------------
    process (clk, rst, hard_rst)
    begin
        if hard_rst = '1' or rst = '1' then
            change_reg <= (others => '0');
        elsif rising_edge(clk) then
            if top_state = IDLE then
                change_reg <= (others => '0');
            elsif mode = MODE_CANCEL and top_state = ACTIVE then
                change_reg <= accum_total;
            elsif mc_complete = '1' then
                change_reg <= mc_change_due;
            end if;
        end if;
    end process;

    change <= change_reg;

    -----------------------------------------------------------------------
    -- Remaining outputs.
    -----------------------------------------------------------------------
    r_total    <= accum_total;
    prod_price <= selected_price;
    prod_out   <= product_reg;

    dispense <= '1' when (top_state = ACTIVE and
                           ((mode = MODE_CANCEL) or
                            (mode = MODE_PROGRAM and prog_state = PROG_DONE) or
                            (mode /= MODE_CANCEL and mode /= MODE_PROGRAM and mc_complete = '1')))
                else '0';

end architecture behavioral;
