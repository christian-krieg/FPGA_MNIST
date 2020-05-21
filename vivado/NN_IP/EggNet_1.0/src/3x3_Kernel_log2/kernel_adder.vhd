library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
LIBRARY work;
use work.egg_box.all;

-- Adder tree to sum up 9 values 
-- 8 Adder Required 

entity kernel_adder_3x3 is
    Generic(FRACTION_SHIFT_WIDTH : integer := 2);
    Port ( Clk_i : in std_logic; 
           Rst_i : in std_logic;
           
           S_Valid_i : in std_logic;
           S_Last_i : in std_logic; 
           
           M_Valid_o : out std_logic; 
           M_Last_o : out std_logic;
           M_Ready_i : in std_logic;
           
           S_Frac_shift_i : in std_logic_vector(FRACTION_SHIFT_WIDTH-1 downto 0);
           S_Weighted_X_i : in kernel_weighted_X_array_t;
           S_Bias_i : in STD_LOGIC_VECTOR(BIAS_WIDTH-1 downto 0);
           M_Sum_o : out STD_LOGIC_VECTOR(ACTIVATION_WIDTH-1 downto 0));
end kernel_adder_3x3;

architecture Behavioral of kernel_adder_3x3 is

constant FIRST_STAGE : integer := KERNEL_SIZE/2; -- 4
constant SECOND_STAGE : integer := KERNEL_SIZE/4; -- 2


type sum_array_fs_t is array (0 to FIRST_STAGE-1) of std_logic_vector(ACTIVATION_WIDTH downto 0);
type sum_array_ss_t is array (0 to SECOND_STAGE) of std_logic_vector(ACTIVATION_WIDTH+1 downto 0);

signal sum_1stg : sum_array_fs_t; 
signal sum_2stg : sum_array_ss_t; 
signal sum_3stg : std_logic_vector(ACTIVATION_WIDTH+2 downto 0);
signal bias_sum : std_logic_vector(ACTIVATION_WIDTH downto 0); 
signal b_4stg : std_logic_vector(ACTIVATION_WIDTH+2 downto 0);

signal valid_1stg, valid_2stg, valid_3stg :std_logic := '0';
signal last_1stg, last_2stg, last_3stg :std_logic := '0';

begin

Control_Sig: process (Clk_i, Rst_i) is 
  begin 
    if rising_edge(Clk_i) then 
      if Rst_i = '0' then 
        M_Valid_o <= '0';
        M_Last_o  <= '0';
        valid_1stg <= '0';
        valid_2stg <= '0';
        valid_3stg <= '0';       
        last_1stg  <= '0';
        last_2stg  <= '0';
        last_3stg  <= '0';
      else 
        if M_Ready_i = '1' then 
          
          valid_1stg <= S_Valid_i;
          valid_2stg <= valid_1stg;
          valid_3stg <= valid_2stg;
          M_Valid_o <= valid_3stg; 
          
          last_1stg <= S_Last_i;
          last_2stg <= last_1stg;
          last_3stg <= last_2stg;
          M_Last_o <= last_3stg;           
        end if;   
      end if;  
    end if;  
  end process; 

Adders_First_Stage: for i in 0 to FIRST_STAGE-1 generate
  adder_fp: entity work.fullp_adder_2th_comp 
      generic map(BIT_WIDTH => ACTIVATION_WIDTH+1) 
      port map( CLK_i => Clk_i,
                Rst_i => Rst_i,
                Ready_i => M_Ready_i,
                A_i => S_Weighted_X_i(i*2),
                B_i => S_Weighted_X_i(i*2+1),
                S_o => sum_1stg(i));   
end generate; 

Adders_Second_Stage: for i in 0 to SECOND_STAGE-1 generate
  adder_fp: entity work.fullp_adder_2th_comp 
      generic map(BIT_WIDTH => ACTIVATION_WIDTH+2) 
      port map( CLK_i => Clk_i,
                Rst_i => Rst_i,
                Ready_i => M_Ready_i,
                A_i => sum_1stg(i*2),
                B_i => sum_1stg(i*2+1),
                S_o => sum_2stg(i)); 
end generate; 
                
Adder_Third_Stage: entity work.fullp_adder_2th_comp 
    generic map(BIT_WIDTH => ACTIVATION_WIDTH+3) 
    port map( CLK_i => Clk_i,
              Rst_i => Rst_i,
              Ready_i => M_Ready_i, 
              A_i => sum_2stg(0),
              B_i => sum_2stg(1),
              S_o => sum_3stg); 
              
adder_bias: entity work.fullp_adder_2th_comp 
    generic map(BIT_WIDTH => ACTIVATION_WIDTH+1) 
    port map( CLK_i => Clk_i,
              Rst_i => Rst_i,
              Ready_i => M_Ready_i,
              A_i => S_Weighted_X_i(KERNEL_SIZE-1),
              B_i => S_Bias_i,
              S_o => bias_sum);   
              

b_4stg <= std_logic_vector(resize(signed(bias_sum),ACTIVATION_WIDTH+3));

Adder_Output_Stage: entity work.quantized_adder 
    generic map(INPUT_WIDTH => ACTIVATION_WIDTH+3,
                OUTPUT_WIDTH => ACTIVATION_WIDTH,
                FRACTION_SHIFT_WIDTH => FRACTION_SHIFT_WIDTH) 
    port map( CLK_i => Clk_i,
              Ready_i => M_Ready_i,
              A_i => sum_3stg,
              B_i => b_4stg,
              Frac_shift_i => S_Frac_shift_i, 
              S_o => M_Sum_o);               


end Behavioral;
