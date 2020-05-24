-- library ieee;
-- use ieee.std_logic_1164.all;
-- use ieee.numeric_std.all;
-- use work.kernel_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
LIBRARY work;
use work.egg_box.all;


entity Kernel3x3_log2 is
	port(
    -- Clock Reset
		Clk_i : in STD_LOGIC;
    Rst_i : in STD_LOGIC;
    -- Slave control
    S_Valid_i : in STD_LOGIC;
    S_Last_i : in STD_LOGIC;
    -- Master control
    M_Valid_o : out STD_LOGIC;
    M_Last_o : out STD_LOGIC;
    M_Ready_i :in STD_LOGIC;
    -- Slave data
    S_Sign_i : in kernel_sign_array_t;
    S_Shift_i : in kernel_shift_array_t;--(SHIFT_WIDTH-1 downto 0);
    S_Bias_i : in std_logic_vector(BIAS_WIDTH-1 downto 0);    
		S_X_data_i : in kernel_input_array_t;--(DATA_WIDTH-1 downto 0);
    S_Fraction_shift_i : in std_logic_vector(KERNEL_FRACTION_SHIFT_WIDTH-1 downto 0); -- Required for Quantization
    -- Master data
		M_Y_data_o : out std_logic_vector(ACTIVATION_WIDTH-1 downto 0) -- Quantization after each Kernel 
	);
end Kernel3x3_log2;

architecture Behavioral of Kernel3x3_log2 is

constant EXTRA_BIT : integer := 3; 

signal ready_mul_vec : std_logic_vector(KERNEL_SIZE-1 downto 0);
signal valid_mul_vec : std_logic_vector(KERNEL_SIZE-1 downto 0);
signal last_mul_vec : std_logic_vector(KERNEL_SIZE-1 downto 0);
signal weighted_X : kernel_weighted_X_array_t;
signal bias_R : std_logic_vector(BIAS_WIDTH-1 downto 0);

begin

  Multipliers: for i in 0 to KERNEL_SIZE-1 generate
    Mulitplier: entity work.log2_multiplier
      Generic map ( INPUT_WIDTH  => ACTIVATION_WIDTH,
                    SHIFT_WIDTH  => WEIGHT_SHIFT_BIT_WIDTH)
      Port map (  Clk_i => Clk_i,
                  Rst_i => Rst_i,
                  S_valid_i => S_Valid_i,
                  S_last_i => S_Last_i,
                  M_valid_o => valid_mul_vec(i),
                  M_last_o => last_mul_vec(i),
                  M_ready_i => ready_add,
                  S_shift_i => Shift_i(i),
                  S_sign_i => Sign_i(i), 
                  S_X_data_i => X_i(i),
                  M_Y_data_o => weighted_X(i)
              );  
  end generate;
  
  -- Synchronization width 
  Bias_Delay: process(Clk_i,Rst_i) is
  begin
    if rising_edge(Clk_i) then 
      if Rst_i = '1' then 
        bias_R <= (others => '0'); 
      elsif M_Ready_i = '1' then   
        bias_R <= S_Bias_i;
      end if;   
    end if;  
  end process;

  Adder: entity work.kernel_adder_3x3 
    Generic map(FRACTION_SHIFT_WIDTH => KERNEL_FRACTION_SHIFT_WIDTH)
    Port map( Clk_i           => Clk_i,
              Rst_i           => Rst_i,
              S_Valid_i       => valid_mul_vec(0), -- since valid and last of all multipliers are the same, anyone can be used. Others are deleted during synthesis
              S_Last_i        => last_mul_vec(0),
              M_Valid_o       => Valid_o,
              M_Last_o        => Last_o,
              M_Ready_i       => Ready_i,
              S_Frac_shift_i  => S_Fraction_shift_i,
              S_Weighted_X_i  => weighted_X,
              S_Bias_i        => bias_R, 
              M_Sum_o         => M_Y_data_o);


end Behavioral;