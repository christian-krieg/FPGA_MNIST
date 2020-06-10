library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all ;

Library UNISIM;
use UNISIM.vcomponents.all;


-- library vunit_lib;
-- context vunit_lib.vunit_context;

entity quantized_adder is
    generic(
           INPUT_WIDTH : integer range 1 to 32 := 12; 
           OUTPUT_WIDTH : integer range 1 to 32 := 9;
           FRAC_SHIFT : in integer := 2); 
    Port ( Clk_i : in STD_LOGIC;
           Ready_i : in STD_ULOGIC;
           A_i : in STD_LOGIC_VECTOR (INPUT_WIDTH-1 downto 0);
           B_i : in STD_LOGIC_VECTOR (INPUT_WIDTH-1 downto 0);
           S_o : out STD_LOGIC_VECTOR (OUTPUT_WIDTH-1 downto 0));
end quantized_adder;

architecture Behavioral of quantized_adder is

  constant ZERO_BIT : bit := '0';
  constant ZERO_STD_ULOGIC : std_ulogic := '0';
  signal carry : std_logic_vector(((INPUT_WIDTH-1)/4)*4+4 downto 0) := (others => '0'); -- Divide by 4 and then multiply by 4 is used to get a multiple of 4 as result 
  signal sum : std_logic_vector(((INPUT_WIDTH-1)/4)*4+4 downto 0) := (others => '0'); 
  signal a_sig : std_logic_vector(((INPUT_WIDTH-1)/4)*4+3 downto 0) := (others => '0'); 
  signal a_xor_b : std_logic_vector(((INPUT_WIDTH-1)/4)*4+3 downto 0) := (others => '0'); 
  signal sum_R : std_logic_vector(OUTPUT_WIDTH-1 downto 0) := (others => '0'); 
  signal shift :std_logic_vector(OUTPUT_WIDTH-1 downto 0) := (others => '0'); 
  signal overflow_neg : std_ulogic := '0';
  signal underflow_neg :std_ulogic := '0'; 
  signal overflow_pos_R : std_ulogic := '0';
  signal overflow_pos : std_ulogic := '0'; 
  signal underflow :std_ulogic := '0'; 
  
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
    CYINIT => carry(0), -- 1-bit carry initialization
    DI => a_sig(4*i+3  downto 4*i), -- 4-bit carry-MUX data in
    S => a_xor_b(4*i+3  downto 4*i) -- 4-bit carry-MUX select input
  );
end generate;
sum(INPUT_WIDTH) <= carry(INPUT_WIDTH) xor a_xor_b(INPUT_WIDTH-1);

-- ***** Overflow detection and Quantization ******* 
-- Overflow can occur if 
--  - Overflow in Carry chain is detected 
--  - sum exeeds the maximum value define by the fraction shift. IF fraction shift is 0 only an overflow in the carry chain can be occur 
Shift_ReLU: if FRAC_SHIFT > 0 generate
ReLU: process(CLK_i) is 
begin
  if rising_edge(CLK_i) then 
    if Ready_i = '1' then   
      if carry(INPUT_WIDTH downto INPUT_WIDTH-1) = "01" or (sum(INPUT_WIDTH) = '0' and sum(INPUT_WIDTH-1 downto INPUT_WIDTH-FRAC_SHIFT) /= (sum(INPUT_WIDTH-2 downto INPUT_WIDTH-1-FRAC_SHIFT)'range => '0')) then
        overflow_pos <= '1';
        --INFO("Overflow positive| Carry: " & to_string(carry) & " Sum: " &  to_string(sum)); 
      else 
        overflow_pos <= '0';
      end if;
      if carry(INPUT_WIDTH downto INPUT_WIDTH-1) = "10" or (sum(INPUT_WIDTH) = '1' and sum(INPUT_WIDTH-1 downto INPUT_WIDTH-FRAC_SHIFT) /= (sum(INPUT_WIDTH-2 downto INPUT_WIDTH-1-FRAC_SHIFT)'range => '1')) then
        overflow_neg <= '1';
        --INFO("Overflow negative| Carry: " & to_string(carry) & " Sum: " &  to_string(sum)); 
      else 
        overflow_neg <= '0';
      end if;
      if sum(INPUT_WIDTH) = '1' and sum(OUTPUT_WIDTH-2+FRAC_SHIFT downto FRAC_SHIFT) = (sum(OUTPUT_WIDTH-2+FRAC_SHIFT downto FRAC_SHIFT)'range => '1') then
        --INFO("Underflow | Sum(9 dowtno 2): " & to_string(sum(OUTPUT_WIDTH-2+FRAC_SHIFT downto FRAC_SHIFT)) & " Sum(1): " &  to_string(sum(FRAC_SHIFT -1))); 
        underflow_neg <= sum(FRAC_SHIFT -1);
      else
        underflow_neg <= '0';
      end if;
      shift(shift'left) <= sum(INPUT_WIDTH); -- sign bit 
      shift(shift'left-1 downto 0) <= sum(OUTPUT_WIDTH-2+FRAC_SHIFT downto FRAC_SHIFT);
    end if;
  end if;
end process;  
end generate;

Quant_ReLU: if FRAC_SHIFT = 0 generate -- boundery check would fail for underflow_neg if in FRAC_SHIFT > 0 version for FRAC_SHIFT = 0
ReLU: process(CLK_i) is 
begin
  if rising_edge(CLK_i) then 
    if Ready_i = '1' then   
      if carry(INPUT_WIDTH downto INPUT_WIDTH-1) = "01" then
        overflow_pos <= '1';
      end if;
      if carry(INPUT_WIDTH downto INPUT_WIDTH-1) = "10" then
        overflow_neg <= '1';
      end if;
      shift <= sum(INPUT_WIDTH-1 downto INPUT_WIDTH - OUTPUT_WIDTH);
    end if;
  end if;
end process;  
underflow_neg <= '0';
end generate;

NegOverflow: for i in 0 to OUTPUT_WIDTH-2 generate
  FDRE_inst : FDRE
    generic map(
      INIT => ZERO_BIT)
    port map (
    Q => sum_R(i), -- Data output
    C => CLK_i, -- Clock input
    CE => Ready_i, -- Clock enable input
    R => overflow_neg or underflow_neg, -- Synchronous reset input
    D => shift(i) -- Data input
  );
end generate;
underflow <= underflow_neg and not overflow_neg;
FDRE_underflow : FDRE
  generic map(
    INIT => ZERO_BIT)
  port map (
  Q => sum_R(OUTPUT_WIDTH-1), -- Data output
  C => CLK_i, -- Clock input
  CE => Ready_i, -- Clock enable input
  R => underflow, -- Synchronous reset input
  D => shift(OUTPUT_WIDTH-1) -- Data input
);

FDRE_ov_pos_R : FDRE
  generic map(
    INIT => ZERO_BIT)
  port map (
  Q => overflow_pos_R, -- Data output
  C => CLK_i, -- Clock input
  CE => Ready_i, -- Clock enable input
  R => ZERO_STD_ULOGIC, -- Synchronous reset input
  D => overflow_pos-- Data input
);

PosOverflow: for i in 0 to OUTPUT_WIDTH-2 generate
  FDSE_inst : FDSE
    generic map(
      INIT => ZERO_BIT)  
    port map (
    Q => S_o(i), -- Data output
    C => CLK_i, -- Clock input
    CE => Ready_i, -- Clock enable input
    S => overflow_pos_R, -- Synchronous reset input
    D => sum_R(i) -- Data input
  );
end generate;

FDRE_ov_pos_sign : FDRE
  generic map(
    INIT => ZERO_BIT)
  port map (
  Q => S_o(OUTPUT_WIDTH-1), -- Data output
  C => CLK_i, -- Clock input
  CE => Ready_i, -- Clock enable input
  R => overflow_pos_R, -- Synchronous reset input
  D => sum_R(OUTPUT_WIDTH-1) -- Data input
);   

end Behavioral;
