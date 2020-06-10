library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all ;

Library UNISIM;
use UNISIM.vcomponents.all;

entity fullp_adder_2th_comp is
    generic(
           BIT_WIDTH : integer range 1 to 32 := 10); 
    Port ( Clk_i : in STD_LOGIC;
           Rst_i : in STD_LOGIC; 
           Ready_i : in STD_LOGIC; 
           A_i : in STD_LOGIC_VECTOR (BIT_WIDTH-1 downto 0);
           B_i : in STD_LOGIC_VECTOR (BIT_WIDTH-1 downto 0);
           S_o : out STD_LOGIC_VECTOR (BIT_WIDTH downto 0));
end fullp_adder_2th_comp;

architecture Behavioral of fullp_adder_2th_comp is
  
  constant MAX : std_logic_vector(BIT_WIDTH-2 downto 0) := (others => '1');
  constant MAX1 : std_logic_vector(BIT_WIDTH-1 downto 0) := ('0' & MAX);
  constant MIN : std_logic_vector(BIT_WIDTH-2 downto 0) := (others => '0');
  constant MIN1 : std_logic_vector(BIT_WIDTH-1 downto 0) := ('1' & MIN);

  signal carry : std_logic_vector(((BIT_WIDTH-1)/4)*4+4 downto 0) := (others => '0'); 
  signal sum : std_logic_vector(((BIT_WIDTH-1)/4)*4+4 downto 0) := (others => '0'); 
  signal sum_sig : std_logic_vector(BIT_WIDTH downto 0) := (others => '0'); 
  signal a_sig : std_logic_vector(((BIT_WIDTH-1)/4)*4+3 downto 0) := (others => '0'); 
  signal a_xor_b : std_logic_vector(((BIT_WIDTH-1)/4)*4+3 downto 0) := (others => '0'); 
  signal overflow_neg : std_logic := '0';
  signal overflow_pos_R : std_logic := '0';
  signal overflow_pos : std_logic := '0';  
  
begin

a_sig(BIT_WIDTH-1 downto 0) <= A_i;
a_xor_b(BIT_WIDTH-1 downto 0) <= A_i xor B_i; 
carry(0) <= '0';
CARRY_chain: for i in 0 to (BIT_WIDTH-1)/4 generate
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
sum_sig(BIT_WIDTH-1 downto 0) <= sum(BIT_WIDTH-1 downto 0); 
sum_sig(BIT_WIDTH) <= carry(BIT_WIDTH) xor a_xor_b(BIT_WIDTH-1);
OutputFF: for i in 0 to BIT_WIDTH generate
  FDRE_inst : FDRE
    generic map(
      INIT => '0')
    port map (
    Q => S_o(i), -- Data output
    C => Clk_i, -- Clock input
    CE => Ready_i, -- Clock enable input
    R => Rst_i, -- Synchronous reset input
    D => sum_sig(i) -- Data input
  );
end generate;  
    
end Behavioral;
