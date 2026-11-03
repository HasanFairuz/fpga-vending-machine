-----------------------------------------------------------------------------
-- Component   : accumulator
-- Description : Sequential circuit that maintains a running total of coin
--               values inserted into the vending machine.
--
--               Per the project manual's port table, "selection" is the
--               raw 4-bit one-hot coin input (Dollar/Quarter/Dime/Nickel),
--               the same encoding used by priority_enc's input_coins port.
--               This component instantiates priority_enc internally to
--               interpret the raw coin switches, then decodes that
--               priority-encoded result into its actual cent value before
--               adding it to the running total.
--
--               Coin input is only accepted (added to the running total)
--               when:
--                 1) enable = '1' (a valid coin selection is present), AND
--                 2) complete = '0' (the transaction has not yet finished)
--
--               Cent values, keyed by the priority encoder's 3-bit output:
--                 "100" (Dollar)  -> 100 cents
--                 "011" (Quarter) ->  25 cents
--                 "010" (Dime)    ->  10 cents
--                 "001" (Nickel)  ->   5 cents
--                 "000" (none)    ->   0 cents (no change to total)
--
--               Design note on "mode": this component accumulates coin
--               value identically regardless of which operating mode the
--               vending machine is in (Vend, Program, or Free) - in every
--               one of those modes, the coin/selection switches are used to
--               build up a running total of some kind (actual payment in
--               Vend/Free mode, a new price being programmed in Program
--               mode). Cancel mode is handled by higher-level circuitry
--               (see vend_unit), which avoids enabling new coin input and
--               instead triggers a reset of this component. The "mode"
--               input is therefore passed through and currently unused
--               inside this component, but is retained as a port so that
--               higher-level mode-dependent behaviour can be added here
--               later without changing the component's interface.
--
--               The accumulator must be reset (rst) between transactions
--               to clear its internal total back to zero; this reset is
--               expected to be driven by higher-level circuitry once
--               "complete" has been observed (see vend_unit).
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity accumulator is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        enable    : in  std_logic;
        mode      : in  std_logic_vector(1 downto 0);
        selection : in  std_logic_vector(3 downto 0);
        complete  : in  std_logic;
        total     : out unsigned(7 downto 0)
    );
end entity accumulator;

architecture behavioral of accumulator is

    component priority_enc is
        port (
            input_coins : in  std_logic_vector(3 downto 0);
            valid       : in  std_logic;
            value       : out std_logic_vector(2 downto 0)
        );
    end component;

    signal total_reg    : unsigned(7 downto 0);
    signal encoded_coin : std_logic_vector(2 downto 0);
    signal coin_value   : unsigned(7 downto 0);

begin

    -----------------------------------------------------------------------
    -- Interpret the raw one-hot coin switches using the priority encoder.
    -- "enable" doubles as the encoder's "valid" input: a coin selection
    -- is only meaningful when the user has signalled valid input.
    -----------------------------------------------------------------------
    encoder_inst : priority_enc
        port map (
            input_coins => selection,
            valid       => enable,
            value       => encoded_coin
        );

    -----------------------------------------------------------------------
    -- Decode the priority-encoded value into its cent value.
    -----------------------------------------------------------------------
    process (encoded_coin)
    begin
        case encoded_coin is
            when "100" => coin_value <= to_unsigned(100, 8); -- Dollar
            when "011" => coin_value <= to_unsigned(25, 8);  -- Quarter
            when "010" => coin_value <= to_unsigned(10, 8);  -- Dime
            when "001" => coin_value <= to_unsigned(5, 8);   -- Nickel
            when others => coin_value <= to_unsigned(0, 8);  -- no coin
        end case;
    end process;

    -----------------------------------------------------------------------
    -- Sequential running total.
    -----------------------------------------------------------------------
    process (clk, rst)
    begin
        if rst = '1' then
            total_reg <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '1' and complete = '0' then
                total_reg <= total_reg + coin_value;
            end if;
        end if;
    end process;

    total <= total_reg;

end architecture behavioral;
