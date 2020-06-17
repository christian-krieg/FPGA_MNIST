library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use STD.textio.all;
LIBRARY work;
use work.egg_box.all;
use work.clogb2_Pkg.all;

entity conv2d is
  Generic ( 
    LAYER_ID : integer := 1; -- ID of the Layer. Reuired for reading correct MIF files
    INPUT_CHANNEL_NUMBER : integer range 1 to 512 := 1; -- Number of input channels 
    OUTPUT_CHANNEL_NUMBER : integer range 1 to 512 := 1; -- Number of input channels 
    MIF_PATH : STRING  := "C:/Users/lukas/Documents/SoC_Lab/FPGA_MNIST/vivado/NN_IP/EggNet_1.0/mif"; --try if relative path is working 
    WEIGHT_MIF_PREAMBLE : STRING := "Weight_";
    BIAS_MIF_PREAMBLE : STRING := "Bias_";
    CH_FRAC_MIF_PREAMBLE : STRING := "Layer_Exponent_shift_";
    K_FRAC_MIF_PREAMBLE : STRING := "Kernel_Exponent_shift_"
  );
  Port (
    -- Clk and reset
    Clk_i         : in std_logic;
    Rst_i         : in std_logic;

    -- Slave interface --> connect to memory controller master
    S_Valid_i	    : in std_logic;
    S_X_data_1_i  : in std_logic_vector((ACTIVATION_WIDTH*INPUT_CHANNEL_NUMBER) - 1 downto 0); --  Input vector element 1 |Vector: trans(1,2,3)
    S_X_data_2_i  : in std_logic_vector((ACTIVATION_WIDTH*INPUT_CHANNEL_NUMBER) - 1 downto 0); --  Input vector element 2 |Vector: trans(1,2,3)
    S_X_data_3_i  : in std_logic_vector((ACTIVATION_WIDTH*INPUT_CHANNEL_NUMBER) - 1 downto 0); --  Input vector element 3 |Vector: trans(1,2,3)
    S_Last_i      : in std_logic;
    S_Newrow_i    : in std_logic;
    S_Ready_o     : out std_logic;

    -- Master interface --> connect to memory controller slave
    M_Valid_o	    : out std_logic;
    M_Y_data_o    : out std_logic_vector((ACTIVATION_WIDTH*OUTPUT_CHANNEL_NUMBER)-1 downto 0);
    M_Last_o      : out std_logic;
    M_Ready_i     : in std_logic
  );
end conv2d;

architecture Behavioral of conv2d is 
  
  signal input_kernels : channel_input_array_t(INPUT_CHANNEL_NUMBER-1 downto 0);
  signal shiftreg_valid_out : std_logic_vector(INPUT_CHANNEL_NUMBER-1 downto 0);
  signal shiftreg_last_out : std_logic_vector(INPUT_CHANNEL_NUMBER-1 downto 0);
  signal shiftreg_is_ready_out : std_logic_vector(INPUT_CHANNEL_NUMBER-1 downto 0);
  
  signal channels_ready : std_logic_vector(OUTPUT_CHANNEL_NUMBER-1 downto 0); 

begin

  Shiftregisters: for i in 0 to INPUT_CHANNEL_NUMBER-1 generate
    Shiftregister: entity work.ShiftRegister_3x3
      port map(
        Clk_i       => Clk_i, 
        Rst_i      => Rst_i, 
        S_X_data_1_i => S_X_data_1_i((i+1)*ACTIVATION_WIDTH-1 downto i*ACTIVATION_WIDTH), 
        S_X_data_2_i => S_X_data_2_i((i+1)*ACTIVATION_WIDTH-1 downto i*ACTIVATION_WIDTH), 
        S_X_data_3_i => S_X_data_3_i((i+1)*ACTIVATION_WIDTH-1 downto i*ACTIVATION_WIDTH), 
        S_Valid_i  => S_Valid_i,
        S_Newrow_i => S_Newrow_i,
        S_Last_i   => S_Last_i, 
        S_Ready_o  => shiftreg_is_ready_out(i), 
        M_X_data_o => input_kernels(i),
        M_Valid_o  => shiftreg_valid_out(i),
        M_Last_o   => shiftreg_last_out(i), 
        M_Ready_i  => channels_ready(0)
      );    
  end generate;
  S_Ready_o <= shiftreg_is_ready_out(0);
  
  Output_channels: for i in 0 to OUTPUT_CHANNEL_NUMBER-1 generate
      Channel:  entity work.Conv_channel
        Generic map( 
          LAYER_ID => LAYER_ID,
          OUTPUT_CHANNEL_ID => i+1,
          INPUT_CHANNEL_NUMBER => INPUT_CHANNEL_NUMBER,
          MIF_PATH => MIF_PATH,
          WEIGHT_MIF_PREAMBLE => WEIGHT_MIF_PREAMBLE,
          BIAS_MIF_PREAMBLE => BIAS_MIF_PREAMBLE,
          CH_FRAC_MIF_PREAMBLE => CH_FRAC_MIF_PREAMBLE,
          K_FRAC_MIF_PREAMBLE => K_FRAC_MIF_PREAMBLE)
        Port map(
          Clk_i      => Clk_i,     
          Rst_i      => Rst_i,     
          S_Valid_i	 => shiftreg_valid_out(0),	
          S_X_data_i => input_kernels,
          S_Last_i   => shiftreg_last_out(0),  
          S_Ready_o  => channels_ready(i), 
          M_Valid_o	 => M_Valid_o,
          M_Y_data_o => M_Y_data_o((i+1)*ACTIVATION_WIDTH-1 downto i*ACTIVATION_WIDTH),
          M_Last_o   => M_Last_o,
          M_Ready_i  => M_Ready_i 
        );
  end generate;
end Behavioral;