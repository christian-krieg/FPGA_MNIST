library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all ;

Library UNISIM;
use UNISIM.all;
use UNISIM.vcomponents.all;

entity quantized_adder is
    generic(
           INPUT_WIDTH : integer range 1 to 32 := 12; 
           OUTPUT_WIDTH : integer range 1 to 32 := 9;
           FRAC_SHIFT : in integer); 
    Port ( Clk_i : in STD_LOGIC;
           Ready_i : in STD_LOGIC;
           A_i : in STD_LOGIC_VECTOR (INPUT_WIDTH-1 downto 0);
           B_i : in STD_LOGIC_VECTOR (INPUT_WIDTH-1 downto 0);
           S_o : out STD_LOGIC_VECTOR (OUTPUT_WIDTH-1 downto 0));
end quantized_adder;

architecture Behavioral of quantized_adder is

  signal carry : std_logic_vector(((INPUT_WIDTH-1)/4)*4+4 downto 0) := (others => '0'); -- Divide by 4 and then multiply by 4 is used to get a multiple of 4 as result 
  signal sum : std_logic_vector(((INPUT_WIDTH-1)/4)*4+4 downto 0) := (others => '0'); 
  signal a_sig : std_logic_vector(((INPUT_WIDTH-1)/4)*4+3 downto 0) := (others => '0'); 
  signal a_xor_b : std_logic_vector(((INPUT_WIDTH-1)/4)*4+3 downto 0) := (others => '0'); 
  signal sum_R : std_logic_vector(INPUT_WIDTH-1 downto 0) := (others => '0'); 
  signal shift,sum_RR :std_logic_vector(OUTPUT_WIDTH-1 downto 0) := (others => '0'); 
  signal overflow_neg, overflow_neg_R : std_logic := '0';
  signal overflow_pos_R, overflow_pos_RR : std_logic := '0';
  signal overflow_pos : std_logic := '0';  
  
begin

a_sig(INPUT_WIDTH-1 downto 0) <= A_i;
a_xor_b(INPUT_WIDTH-1 downto 0) <= A_i xor B_i; 
carry(0) <= '0';
CARRY_chain: for i in 0 to (INPUT_WIDTH-1)/4 generate
  CARRY4_inst : entity unisim.CARRY4
  port map (
    CO => carry(4*i+3+1 downto 4*i+1), -- 4-bit carry out
    O => sum(4*i+3 downto 4*i), -- 4-bit carry chain XOR data out
    CI => carry(4*i), -- 1-bit carry cascade input
    CYINIT => '0', -- 1-bit carry initialization
    DI => a_sig(4*i+3  downto 4*i), -- 4-bit carry-MUX data in
    S => a_xor_b(4*i+3  downto 4*i) -- 4-bit carry-MUX select input
  );
end generate;

RegSum: for i in 0 to INPUT_WIDTH-1 generate
  FDRE_inst : entity unisim.FDRE
    generic map(
      INIT => '0')
    port map (
    Q => sum_R(i), -- Data output
    C => CLK_i, -- Clock input
    CE => Ready_i, -- Clock enable input
    R => '0', -- Synchronous reset input
    D => sum(i) -- Data input
  );
end generate;

-- ***** Overflow detection and Quantization ******* 
-- Overflow can occur if 
--  - Overflow in Carry chain is detected 
--  - Sum_R exeeds the maximum value define by the fraction shift. IF fraction shift is 0 only an overflow in the carry chain can be occur 
Shift_ReLU: if FRAC_SHIFT > 0 generate
ReLU: process(sum_R,carry) is 
begin
  if carry(INPUT_WIDTH downto INPUT_WIDTH-1) = "01" or (sum_R(sum_R'left) = '0' and sum_R(sum_R'left-1 downto sum_R'left-FRAC_SHIFT) /= (sum_R(sum_R'left-1 downto sum_R'left-FRAC_SHIFT)'range => '0')) then
    overflow_pos <= '1';
  end if;
  if carry(INPUT_WIDTH downto INPUT_WIDTH-1) = "10" or (sum_R(sum_R'left) = '1' and sum_R(sum_R'left-1 downto sum_R'left-FRAC_SHIFT) /= (sum_R(sum_R'left-1 downto sum_R'left-FRAC_SHIFT)'range => '1')) then
    overflow_neg <= '1';
  end if;
  shift <= sum_R(sum_R'left - FRAC_SHIFT downto sum_R'length - FRAC_SHIFT - OUTPUT_WIDTH);
end process;  
end generate;
Quant_ReLU: if FRAC_SHIFT = 0 generate
ReLU: process(sum_R,carry) is 
begin
  if carry(INPUT_WIDTH downto INPUT_WIDTH-1) = "01" then
    overflow_pos <= '1';
  end if;
  if carry(INPUT_WIDTH downto INPUT_WIDTH-1) = "10" then
    overflow_neg <= '1';
  end if;
  shift <= sum_R(sum_R'left downto sum_R'length - OUTPUT_WIDTH);
end process;  
end generate;

FDRE_ov_neg_R : entity unisim.FDRE
  generic map(
    INIT => '0')
  port map (
  Q => overflow_neg_R, -- Data output
  C => CLK_i, -- Clock input
  CE => Ready_i, -- Clock enable input
  R => '0', -- Synchronous reset input
  D => overflow_neg-- Data input
);
NegOverflow: for i in 0 to OUTPUT_WIDTH-2 generate
  FDRE_inst : entity unisim.FDRE
    generic map(
      INIT => '0')
    port map (
    Q => sum_RR(i), -- Data output
    C => CLK_i, -- Clock input
    CE => Ready_i, -- Clock enable input
    R => overflow_neg_R, -- Synchronous reset input
    D => shift(i) -- Data input
  );
end generate;

FDSE_sign : entity unisim.FDSE
  generic map(
    INIT => '0')
  port map (
  Q => sum_RR(OUTPUT_WIDTH-1), -- Data output
  C => CLK_i, -- Clock input
  CE => Ready_i, -- Clock enable input
  S => overflow_neg_R, -- Synchronous reset input
  D => shift(OUTPUT_WIDTH-1) -- Data input
);

FDRE_ov_pos_R : entity unisim.FDRE
  generic map(
    INIT => '0')
  port map (
  Q => overflow_pos_R, -- Data output
  C => CLK_i, -- Clock input
  CE => Ready_i, -- Clock enable input
  R => '0', -- Synchronous reset input
  D => overflow_pos-- Data input
);

FDRE_ov_pos_RR : entity unisim.FDRE
  generic map(
    INIT => '0')
  port map (
  Q => overflow_pos_RR, -- Data output
  C => CLK_i, -- Clock input
  CE => Ready_i, -- Clock enable input
  R => '0', -- Synchronous reset input
  D => overflow_pos_R-- Data input
);

PosOverflow: for i in 0 to OUTPUT_WIDTH-2 generate
  FDSE_inst : entity unisim.FDSE
    generic map(
      INIT => '0')  
    port map (
    Q => S_o(i), -- Data output
    C => CLK_i, -- Clock input
    CE => Ready_i, -- Clock enable input
    S => overflow_pos_RR, -- Synchronous reset input
    D => sum_RR(i) -- Data input
  );
end generate;

FDRE_sign : entity unisim.FDRE
  generic map(
    INIT => '0')
  port map (
  Q => S_o(OUTPUT_WIDTH-1), -- Data output
  C => CLK_i, -- Clock input
  CE => Ready_i, -- Clock enable input
  R => overflow_pos_RR, -- Synchronous reset input
  D => sum_RR(OUTPUT_WIDTH-1) -- Data input
);   

    
end Behavioral;
