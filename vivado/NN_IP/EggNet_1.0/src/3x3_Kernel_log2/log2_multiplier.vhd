----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.03.2020 17:20:05
-- Design Name: 
-- Module Name: log2_multiplier - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

entity log2_multiplier is
  Generic(  SHIFT_WIDTH : integer := 3;
            INPUT_WIDTH : integer := 8
  );
  Port (  -- Clock Reset
          Clk_i : in STD_LOGIC;
          Rst_i : in STD_LOGIC;
          -- Slave control
          S_Valid_i : in STD_LOGIC;
          S_Last_i : in STD_LOGIC;
          -- Master control
          M_Valid_o : out STD_LOGIC := '0';
          M_Last_o : out STD_LOGIC := '0';
          M_Ready_i :in STD_LOGIC;
          -- Slave data
          S_Shift_i : in STD_LOGIC_VECTOR (SHIFT_WIDTH-1 downto 0);
          S_Sign_i : in STD_LOGIC_VECTOR(0 downto 0);
          S_X_data_i : in STD_LOGIC_VECTOR (INPUT_WIDTH-1 downto 0);
          -- Master data
          M_Weighted_X : out STD_LOGIC_VECTOR (INPUT_WIDTH downto 0) := (others => '0'));
end log2_multiplier;

architecture Behavioral of log2_multiplier is
 
begin

contr_sig: process(Clk_i,Rst_i) is
begin
  if rising_edge(Clk_i) then
    if Rst_i = '1' then 
      M_Valid_o <= '0';
      M_Last_o  <= '0';
    elsif M_ready_i = '1' then    
      M_Valid_o <= S_Valid_i;
      M_Last_o <= S_Last_i;      
    end if;  
  end if; 
end process;

-- *** Shift by variable weight 
-- If next element is not ready wait
Shift: process(Clk_i,Rst_i) is
begin
  if rising_edge(Clk_i) then 
    if Rst_i = '1' then 
      M_Weighted_X <= (others => '0'); 
    elsif M_ready_i = '1' then   
      if S_sign_i = "1" then 
        M_Weighted_X <= not std_logic_vector(-signed(resize(SHIFT_RIGHT(unsigned(S_X_data_i), to_integer(unsigned(S_Shift_i))),M_Weighted_X'length)));
      else 
        M_Weighted_X <= std_logic_vector(resize(SHIFT_RIGHT(unsigned(S_X_data_i), to_integer(unsigned(S_Shift_i))),M_Weighted_X'length));
      end if; 
    end if;  
  end if;
end process;


end Behavioral;