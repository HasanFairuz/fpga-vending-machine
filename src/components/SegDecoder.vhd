-----------------------------------------------------------------------------
-- Component   : SegDecoder
-- Description : Combinational circuit that decodes a single 4-bit BCD
--               digit (0-9) into its corresponding 7-segment display
--               pattern. Per the project specifications, the DE2-115's
--               HEX displays use active-low logic (a segment is lit when
--               its output bit is '0').
--
--               Segment output bit ordering: seg(6 downto 0) = g f e d c b a
--               (the standard 7-segment letter convention, MSB = segment g,
--               LSB = segment a).
--
--               Inputs outside the valid BCD range (10-15) are decoded to
--               the same active-low blank pattern (all segments off).
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity SegDecoder is
    port (
        bcd : in  std_logic_vector(3 downto 0);
        seg : out std_logic_vector(6 downto 0)
    );
end entity SegDecoder;

architecture behavioral of SegDecoder is
begin

    process (bcd)
    begin
        case bcd is
            when "0000" => seg <= "1000000"; -- 0
            when "0001" => seg <= "1111001"; -- 1
            when "0010" => seg <= "0100100"; -- 2
            when "0011" => seg <= "0110000"; -- 3
            when "0100" => seg <= "0011001"; -- 4
            when "0101" => seg <= "0010010"; -- 5
            when "0110" => seg <= "0000010"; -- 6
            when "0111" => seg <= "1111000"; -- 7
            when "1000" => seg <= "0000000"; -- 8
            when "1001" => seg <= "0010000"; -- 9
            when others => seg <= "1111111"; -- blank (invalid BCD input)
        end case;
    end process;

end architecture behavioral;
