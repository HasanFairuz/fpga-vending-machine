library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debounce is
  generic (
    timeout_cycles : positive
    );
  port (
    clk : in std_logic;
    switch : in std_logic;
    switch_debounced : out std_logic
  );
end debounce;

architecture rtl of debounce is

  signal debounced : std_logic := '0';
  signal counter : integer range 0 to timeout_cycles - 1 := 0;

begin

  -- Copy internal signal to output
  switch_debounced <= debounced;

  DEBOUNCE_PROC : process(clk)
  begin
    if rising_edge(clk) then
      if counter < timeout_cycles - 1 then
        counter <= counter + 1;
      elsif switch /= debounced then
        counter <= 0;
        debounced <= switch;
      end if;
    end if;
  end process;

end architecture;
