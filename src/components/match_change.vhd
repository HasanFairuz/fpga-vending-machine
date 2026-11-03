-----------------------------------------------------------------------------
-- Component   : match_change
-- Description : Sequential circuit responsible for monitoring the
--               accumulated coin total ("coins") against a product's
--               price, and generating the change due once enough coins
--               have been inserted to cover the price.
--
--               Mode-dependent behaviour:
--                 Vend mode ("00")    : effective price = price input.
--                                       change_due = coins - price once
--                                       coins >= price.
--                 Program mode ("01") : price matching/change logic is not
--                                       applicable here - the accumulator
--                                       is instead being used to build up
--                                       a *new* price value, not pay for a
--                                       product. Per the manual's port
--                                       description, "done" is pulsed by
--                                       higher-level circuitry once that
--                                       new price has finished
--                                       accumulating. This circuit passes
--                                       that pulse straight through to its
--                                       own "complete" output (so vend_unit
--                                       can treat "complete" consistently
--                                       across all modes), while forcing
--                                       change_due to zero since no money
--                                       is returned in Program mode.
--                 Free mode ("10")    : effective price = $0.00 (price
--                                       input is ignored). Any coins
--                                       accidentally inserted are returned
--                                       in full as change_due. Since the
--                                       effective price is zero, complete
--                                       pulses immediately (coins is always
--                                       >= 0), allowing the product to
--                                       dispense without requiring payment.
--                 Cancel mode ("11")  : not handled here. Per the project
--                                       manual's hint, cancel behaviour
--                                       (returning whatever change has
--                                       been inserted so far) is handled by
--                                       higher-level circuitry (vend_unit),
--                                       which reads the accumulator's
--                                       running total directly and then
--                                       resets this component. This
--                                       component takes no special action
--                                       for mode = "11".
--
--               "complete" is a single-cycle pulse (not a level signal),
--               asserted for exactly one clock cycle the first time the
--               coins >= effective_price condition becomes true after a
--               reset (Vend/Free modes), or the first time "done" is
--               observed asserted (Program mode). This prevents vend_unit
--               from observing a continuously-asserted complete signal.
--
--               This circuit should be reset (rst) at the start of every
--               new transaction, consistent with the accumulator, so that
--               its internal "already completed" tracking starts fresh.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity match_change is
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
end entity match_change;

architecture behavioral of match_change is

    constant MODE_VEND    : std_logic_vector(1 downto 0) := "00";
    constant MODE_PROGRAM : std_logic_vector(1 downto 0) := "01";
    constant MODE_FREE    : std_logic_vector(1 downto 0) := "10";
    constant MODE_CANCEL  : std_logic_vector(1 downto 0) := "11";

    signal effective_price : unsigned(7 downto 0);
    signal match_condition : std_logic; -- combinational: coins >= effective_price
    signal already_fired   : std_logic; -- tracks whether complete has already pulsed this transaction
    signal change_reg      : unsigned(7 downto 0);
    signal complete_reg    : std_logic;

begin

    -----------------------------------------------------------------------
    -- Effective price depends on mode: Free mode always treats price as
    -- zero. Program mode's price input is not meaningful here since
    -- change_due is forced to zero in that mode regardless (see process
    -- below), but we still compute it harmlessly to avoid unnecessary
    -- special-casing.
    -----------------------------------------------------------------------
    effective_price <= (others => '0') when mode = MODE_FREE else price;

    match_condition <= '1' when (coins >= effective_price) else '0';

    -----------------------------------------------------------------------
    -- Sequential logic: track whether the completion condition has
    -- already fired this transaction (to keep "complete" a single-cycle
    -- pulse), and register change_due once that condition is met.
    -----------------------------------------------------------------------
    process (clk, rst)
    begin
        if rst = '1' then
            already_fired <= '0';
            change_reg    <= (others => '0');
            complete_reg  <= '0';
        elsif rising_edge(clk) then
            complete_reg <= '0'; -- default: de-assert unless freshly matched below

            if mode = MODE_PROGRAM then
                -- Program mode: no change is owed. The completion event
                -- is signalled externally via the "done" pulse rather
                -- than the coins >= price comparison.
                if done = '1' and already_fired = '0' then
                    change_reg    <= (others => '0');
                    complete_reg  <= '1';
                    already_fired <= '1';
                end if;
            else
                if match_condition = '1' and already_fired = '0' then
                    change_reg    <= coins - effective_price;
                    complete_reg  <= '1';
                    already_fired <= '1';
                end if;
            end if;
        end if;
    end process;

    complete   <= complete_reg;
    change_due <= change_reg;

end architecture behavioral;
