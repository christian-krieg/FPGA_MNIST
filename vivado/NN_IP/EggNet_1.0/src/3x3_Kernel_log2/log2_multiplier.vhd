library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity log2_multiplier is
  generic (
    SHIFT_WIDTH : integer := 3;
    INPUT_WIDTH : integer := 8
  );
  port (-- Clock Reset
    Clk_i : in STD_LOGIC;
    Rst_i : in STD_LOGIC;
    -- Slave control
    S_Valid_i : in STD_LOGIC;
    S_Last_i  : in STD_LOGIC;
    -- Master control
    M_Valid_o : out STD_LOGIC := '0';
    M_Last_o  : out STD_LOGIC := '0';
    M_Ready_i : in STD_LOGIC;
    -- Slave data
    S_Shift_i  : in STD_LOGIC_VECTOR (SHIFT_WIDTH - 1 downto 0);
    S_Sign_i   : in STD_LOGIC_VECTOR(0 downto 0); -- use std_logic_vector for compatibility with mif file reader 
    S_X_data_i : in STD_LOGIC_VECTOR (INPUT_WIDTH - 1 downto 0);
    -- Master data
    M_Weighted_X : out STD_LOGIC_VECTOR (INPUT_WIDTH downto 0) := (others => '0'));
end log2_multiplier;

architecture Behavioral of log2_multiplier is
  signal x_signed : std_logic_vector(INPUT_WIDTH downto 0);
  signal carry    : std_logic_vector(INPUT_WIDTH downto 0) := (others => '0');
  signal x_shift  : std_logic_vector(INPUT_WIDTH - 1 downto 0);

begin

  contr_sig : process (Clk_i, Rst_i) is
  begin
    if rising_edge(Clk_i) then
      if Rst_i = '1' then
        M_Valid_o <= '0';
        M_Last_o  <= '0';
      elsif M_Ready_i = '1' then
        M_Valid_o <= S_Valid_i;
        M_Last_o  <= S_Last_i;
      end if;
    end if;
  end process;

  -- *** Shift by variable weight 
  Shift : process (Rst_i,S_X_data_i, S_Shift_i, S_Sign_i) is
  begin
    if Rst_i = '1' then
      x_shift <= (others => '0');
    else
      if S_Sign_i = "1" then
        x_shift <= not std_logic_vector(SHIFT_RIGHT(unsigned(S_X_data_i), to_integer(unsigned(S_Shift_i))));
      else
        x_shift <= std_logic_vector(SHIFT_RIGHT(unsigned(S_X_data_i), to_integer(unsigned(S_Shift_i))));
      end if;
    end if;
  end process;

  -- *** Invertion is done by inverting the signal nad adding 1. This is done by using the sign bit as carry input. ***
  carry(0) <= S_Sign_i(0);
  CARRY_chain : for i in 0 to (INPUT_WIDTH - 1)/4 generate
    CARRY4_inst : CARRY4
      port map(
        CO     => carry(4 * i + 3 + 1 downto 4 * i + 1), -- 4-bit carry out
        O      => x_signed(4 * i + 3 downto 4 * i),      -- 4-bit carry chain XOR data out
        CI     => carry(4 * i),                          -- 1-bit carry cascade input
        CYINIT => '0',                                   -- 1-bit carry initialization
        DI     => x_shift(4 * i + 3 downto 4 * i),       -- 4-bit carry-MUX data in
        S      => x_shift(4 * i + 3 downto 4 * i)        -- 4-bit carry-MUX select input
      );
  end generate;

  x_signed(x_signed'left) <= S_Sign_i(0);
  Register_Yo : for i in 0 to INPUT_WIDTH generate
    FDRE_inst : FDRE
      generic map(
        INIT => '0')
      port map(
        Q  => M_Weighted_X(i),   -- Data output
        C  => Clk_i,             -- Clock input
        CE => M_Ready_i,         -- Clock enable input
        R  => carry(carry'left), -- Synchronous reset input
        D  => x_signed(i)        -- Data input
      );
  end generate;

end Behavioral;