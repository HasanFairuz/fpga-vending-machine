-----------------------------------------------------------------------------
-- Component   : priority_enc
-- Description : Combinational 4:3 priority encoder for coin inputs.
--               input_coins is a 4-bit one-hot (ideally) coded value:
--                 Dollar  = "1000"
--                 Quarter = "0100"
--                 Dime    = "0010"
--                 Nickel  = "0001"
--
--               Encoding scheme (note: NOT simple binary-weighted priority
--               on the encoded output - this is per the project spec):
--                 Dollar  inserted -> value = "100"
--                 Quarter inserted -> value = "011"
--                 Dime    inserted -> value = "010"
--                 Nickel  inserted -> value = "001"
--                 Anything else    -> value = "000" (no coin / invalid input)
--
--               If multiple bits of input_coins are asserted simultaneously
--               (a non-one-hot input), priority is given in the order
--               Dollar > Quarter > Dime > Nickel, consistent with standard
--               priority encoder behaviour (MSB has highest priority).
--               The "valid" input simply gates whether the input is
--               considered live; if valid = '0', the encoder forces its
--               output to "000" regardless of input_coins.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity priority_enc is
    port (
        input_coins : in  std_logic_vector(3 downto 0);
        valid       : in  std_logic;
        value       : out std_logic_vector(2 downto 0)
    );
end entity priority_enc;

architecture behavioral of priority_enc is
begin

    process (input_coins, valid)
    begin
        if valid = '0' then
            value <= "000";
        elsif input_coins(3) = '1' then        -- Dollar, highest priority
            value <= "100";
        elsif input_coins(2) = '1' then        -- Quarter
            value <= "011";
        elsif input_coins(1) = '1' then        -- Dime
            value <= "010";
        elsif input_coins(0) = '1' then        -- Nickel, lowest priority
            value <= "001";
        else
            value <= "000";                    -- no coin inserted
        end if;
    end process;

end architecture behavioral;
