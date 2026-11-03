-- Victor Dumitriu & Anita Tino
-- Clock divider, used to turn a 27 MHz clock into a 270 KHz one.

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
-- USE ieee.std_logic_arith.all;
-- USE ieee.std_logic_unsigned.all;

ENTITY clDivide IS
	PORT
	(
		clkIn 		: IN	STD_LOGIC;
		clkOut		: OUT	STD_LOGIC
	);
END clDivide;

ARCHITECTURE behaviour OF clDivide IS
	SIGNAL counter : UNSIGNED(9 DOWNTO 0);
	SIGNAL tmp : STD_LOGIC;
BEGIN

	clock_divider:
	PROCESS (clkIn)
	BEGIN

		IF(rising_edge(clkIn)) THEN
			counter <= counter + 1;
			IF(counter = "1111101000") THEN
				tmp <= NOT tmp;
				clkOut <= tmp;
				counter <= "0000000000";
			END IF;
		END IF;

	END PROCESS clock_divider;

END behaviour;
