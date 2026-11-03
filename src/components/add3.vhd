-----------------------------------------------------------------------------
-- Component   : add3
-- Description : Combinational "add-3" circuit used as a building block for
--               the double-dabble (shift-add-3) binary to BCD converter.
--               For inputs 0-4, output = input. For inputs 5-9, output =
--               input + 3. Inputs 10-15 are unreachable in this design's
--               usage and are mapped to "0000" for determinism.
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity add3 is
    port (
        A : in  std_logic_vector(3 downto 0);
        S : out std_logic_vector(3 downto 0)
    );
end entity add3;

architecture behavioral of add3 is
begin

    process (A)
    begin
        case A is
            when "0000" => S <= "0000";  -- 0
            when "0001" => S <= "0001";  -- 1
            when "0010" => S <= "0010";  -- 2
            when "0011" => S <= "0011";  -- 3
            when "0100" => S <= "0100";  -- 4
            when "0101" => S <= "1000";  -- 5 + 3 = 8
            when "0110" => S <= "1001";  -- 6 + 3 = 9
            when "0111" => S <= "1010";  -- 7 + 3 = 10
            when "1000" => S <= "1011";  -- 8 + 3 = 11
            when "1001" => S <= "1100";  -- 9 + 3 = 12
            when others => S <= "0000";  -- unreachable / don't-care inputs
        end case;
    end process;

end architecture behavioral;
