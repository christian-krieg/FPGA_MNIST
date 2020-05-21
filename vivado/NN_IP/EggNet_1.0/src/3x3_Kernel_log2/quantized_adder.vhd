library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all ;

Library UNISIM;
use UNISIM.vcomponents.all;

entity quantized_adder is
    generic(
           INPUT_WIDTH : integer range 1 to 32 := 12; 
           OUTPUT_WIDTH : integer range 1 to 32 := 9;
           FRACTION_SHIFT_WIDTH : integer := 2); 
    Port ( Clk_i : in STD_LOGIC;
           Ready_i : in STD_LOGIC;
           A_i : in STD_LOGIC_VECTOR (INPUT_WIDTH-1 downto 0);
           B_i : in STD_LOGIC_VECTOR (INPUT_WIDTH-1 downto 0);
           Frac_shift_i : in STD_LOGIC_VECTOR(FRACTION_SHIFT_WIDTH-1 downto 0);
           S_o : out STD_LOGIC_VECTOR (OUTPUT_WIDTH-1 downto 0));
end quantized_adder;

architecture Behavioral of quantized_adder is

  signal carry : std_logic_vector(((INPUT_WIDTH-1)/4)*4+4 downto 0) := (others => '0'); -- Divide by 4 and then multiply by 4 is used to get a multiple of 4 as result 
  signal sum : std_logic_vector(((INPUT_WIDTH-1)/4)*4+4 downto 0) := (others => '0'); 
  signal a_sig : std_logic_vector(((INPUT_WIDTH-1)/4)*4+3 downto 0) := (others => '0'); 
  signal a_xor_b : std_logic_vector(((INPUT_WIDTH-1)/4)*4+3 downto 0) := (others => '0'); 
  signal sum_R, sum_RR, shift : std_logic_vector(INPUT_WIDTH-1 downto 0) := (others => '0'); 
  signal overflow_neg, overflow_neg_R : std_logic := '0';
  signal overflow_pos_R, overflow_pos_RR : std_logic := '0';
  signal overflow_pos : std_logic := '0';  

  component CARRY4 is
    port (
    CO : out std_logic_vector(3 downto 0); -- 4-bit carry out
    O : out std_logic_vector(3 downto 0); -- 4-bit carry chain XOR data out
    CI : in std_ulogic; -- 1-bit carry cascade input
    CYINIT : in std_ulogic; -- 1-bit carry initialization
    DI : in std_logic_vector(3 downto 0); -- 4-bit carry-MUX data in
    S : in std_logic_vector(3 downto 0) -- 4-bit carry-MUX select input
    );
  end component;

  component FDRE is
    Generic(
    INIT : bit);
    port (
    Q  : out std_ulogic;
    C  : in std_ulogic;
    CE : in std_ulogic;
    R  : in std_ulogic;
    D  : in  std_ulogic 
  ) ;
  end component;  
  component FDSE is
    Generic(
    INIT : bit);
    port (
    Q  : out std_ulogic;
    C  : in std_ulogic;
    CE : in std_ulogic;
    S  : in std_ulogic;
    D  : in  std_ulogic 
  ) ;
  end component;
  
begin

a_sig(INPUT_WIDTH-1 downto 0) <= A_i;
a_xor_b(INPUT_WIDTH-1 downto 0) <= A_i xor B_i; 
carry(0) <= '0';
CARRY_chain: for i in 0 to (INPUT_WIDTH-1)/4 generate
  CARRY4_inst : CARRY4
  port map (
    CO => carry(4*i+3+1 downto 4*i+1), -- 4-bit carry out
    O => sum(4*i+3 downto 4*i), -- 4-bit carry chain XOR data out
    CI => carry(4*i), -- 1-bit carry cascade input
    CYINIT => '0', -- 1-bit carry initialization
    DI => a_sig(4*i+3  downto 4*i), -- 4-bit carry-MUX data in
    S => a_xor_b(4*i+3  downto 4*i) -- 4-bit carry-MUX select input
  );
end generate;

RegSum: for i in 0 to OUTPUT_WIDTH-1 generate
  FDRE_inst : FDRE
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

overflow_pos <= '1' when carry(INPUT_WIDTH downto INPUT_WIDTH-1) = "01" or (sum(INPUT_WIDTH-1) = '0' and sum(INPUT_WIDTH-2 downto OUTPUT_WIDTH-1) /= (sum(INPUT_WIDTH-1 downto OUTPUT_WIDTH)'range => '0')) else '0';
overflow_neg <= '1' when carry(INPUT_WIDTH downto INPUT_WIDTH-1) = "10" or (sum(INPUT_WIDTH-1) = '1' and sum(INPUT_WIDTH-2 downto OUTPUT_WIDTH-1) /= (sum(INPUT_WIDTH-1 downto OUTPUT_WIDTH-1)'range => '1')) else '0';

Quantization: process(sum) is
begin
  shift <= std_logic_vector(SHIFT_RIGHT(signed(sum_R), to_integer(unsigned(Frac_shift_i))));
end process; 

FDRE_ov_neg_R : FDRE
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
  FDRE_inst : FDRE
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

FDSE_sign : FDSE
  generic map(
    INIT => '0')
  port map (
  Q => sum_RR(OUTPUT_WIDTH-1), -- Data output
  C => CLK_i, -- Clock input
  CE => Ready_i, -- Clock enable input
  S => overflow_neg_R, -- Synchronous reset input
  D => shift(OUTPUT_WIDTH-1) -- Data input
);

FDRE_ov_pos_R : FDRE
  generic map(
    INIT => '0')
  port map (
  Q => overflow_pos_R, -- Data output
  C => CLK_i, -- Clock input
  CE => Ready_i, -- Clock enable input
  R => '0', -- Synchronous reset input
  D => overflow_pos-- Data input
);

FDRE_ov_pos_RR : FDRE
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
  FDSE_inst : FDSE
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

FDRE_sign : FDRE
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
