library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use STD.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;
LIBRARY work;
use work.csv_numpy.all;
use work.egg_box.all;

library OSVVM ; 
  use OSVVM.RandomBasePkg.all ; 
  use OSVVM.RandomPkg.all ; 

entity tb_conv_channel is
  generic (
    RUNNER_CFG : string;
    TB_PATH    : string;
    TB_CSV_DATA_FILE     : string;
    TB_CSV_RESULTS_FILE   : string;
    INPUT_CHANNEL_NUMBER  : integer := 1;
    RANDOM_READY          : std_logic := '1';
    MIF_PATH              : string := "../../mif/";
    WEIGHT_MIF_PREAMBLE   : STRING := "Weight_";
    BIAS_MIF_PREAMBLE     : STRING := "Bias_";
    CH_FRAC_MIF_PREAMBLE  : STRING := "Layer_Exponent_shift_";
    K_FRAC_MIF_PREAMBLE   : STRING := "Kernel_Exponent_shift_"
  );
end entity;

architecture tb of tb_conv_channel is

  constant TbPeriod     : time := 10 ns;
  signal TbClock        : std_logic := '0';
  signal TbSimEnded     : std_logic := '0';
  signal layer_clk	    : std_logic;
  signal layer_aresetn  : std_logic;


  
  signal s_valid    : std_logic;
  signal s_data     : channel_input_array_t(INPUT_CHANNEL_NUMBER-1 downto 0);
  signal s_last     : std_logic;
  signal s_ready    : std_logic;
  
  signal m_Y_data     :std_logic_vector(ACTIVATION_WIDTH-1 downto 0);
  signal m_Last       :std_logic;
  signal m_Ready      :std_logic;
  signal m_Valid      :std_logic;
  
  signal counter      :integer; 
  

begin
  
  TbClock <= not TbClock after TbPeriod/2 when TbSimEnded /= '1' else '0';
  layer_clk <= TbClock;


  main: process
    
  
    procedure run_test_stable_ready(testdata_filepath : string) is
      constant test_img_dim : integer_vector := csvGetNumpyDim(testdata_filepath);
      constant test_img_arr : int_vec_5d_t := csvGetNumpy5d(testdata_filepath);      
      variable activation_tile : kernel_input_array_t; 
      variable tile_index : integer := 0;
      variable RV : RandomPType ; 
      variable DataSigned : signed(7 downto 0) ;
    begin
      printDim(test_img_dim);
      layer_aresetn <= '0'; 
      m_Ready <= '0';
      counter <= 0;
      for i in 0 to KERNEL_SIZE-1 loop
        s_data(0)(i) <= (others =>  '0');
      end loop;
      s_valid <= '0';
      s_last <= '0'; 
      wait for TbPeriod*3; 
      layer_aresetn <= '1'; 
      m_Ready <= '1';
      wait for TbPeriod; 
      -- *** iterate through batches *** 
      for i in 0 to test_img_dim(0)-1 loop
      
        -- *** iterate through image hight and width 
        for j in 0 to test_img_dim(1)-1 loop 
          for k in 0 to test_img_dim(2)-1 loop
            
            tile_index := 0;
            -- *** New image tile ***
            for l in 0 to test_img_dim(3)-1 loop
              for m in 0 to test_img_dim(4)-1 loop
                activation_tile(tile_index) := std_logic_vector(to_unsigned(test_img_arr(i,j,k,l,m)
                                                                ,ACTIVATION_WIDTH));
                --report "s_data: [" & integer'image(tile_index) & "]=" & to_hstring(activation_tile(tile_index)) & "h";  
                tile_index := iterate(tile_index,0,KERNEL_SIZE-1);                                              
              end loop;  
            end loop;
            if RANDOM_READY = '1' then
              DataSigned := RV.RandSigned(-1,64, 8);
              if to_integer(DataSigned) < 0 then
                DataSigned := to_signed(1,8);
                while to_integer(DataSigned) > 0 loop
                  m_Ready <= '0'; 
                  DataSigned := RV.RandSigned(-1,127, 8);
                  wait until layer_clk = '1';
                end loop;
                m_Ready <= '1'; 
                wait until layer_clk = '1';
              else
                wait until layer_clk = '1'; 
              end if;
            end if;
            if s_ready /= '1' then
              wait until s_ready = '1'; 
            end if;
            --info("Channel output: " & integer'image(to_integer(unsigned(m_Y_data))));
            
            s_data(0) <= activation_tile;
            counter <= counter +1;
            s_valid <= '1';            
            s_last <= '0';
          end loop;  
        end loop; 
        s_last <= '1';
      end loop;  
      wait until layer_clk = '1';
      s_valid <= '0'; 
      wait for TbPeriod*15; 
    end procedure;

    procedure check_clock(testdata_filepath : string) is
      constant test_img_dim : integer_vector := csvGetNumpyDim(testdata_filepath);
      constant test_img_arr : int_vec_5d_t := csvGetNumpy5d(testdata_filepath);      
      variable activation_tile : kernel_input_array_t; 
      variable tile_index : integer := 0;
    begin
      printDim(test_img_dim);
      layer_aresetn <= '0'; 
      s_valid <= '0';
      s_last <= '0'; 
      wait for TbPeriod*3; 
 
      layer_aresetn <= '1'; 
      wait for TbPeriod; 
      wait until layer_clk'event and layer_clk = '1'; 
      if s_ready /= '1' then
        wait until s_ready = '1'; 
      end if;
      info("Clock observed");
    end procedure;

  begin
    test_runner_setup(runner, RUNNER_CFG);
    while test_suite loop
      info("Test data CSV file path: " & TB_CSV_DATA_FILE);
      info("Test results CSV file path: " & TB_CSV_RESULTS_FILE);
      if run("CSV test") then
        run_test_stable_ready(TB_CSV_DATA_FILE);
      end if;
    end loop;
    test_runner_cleanup(runner);
    TbSimEnded <= '1';
    wait;
  end process;
  
  Channel:  entity work.Conv_channel
    Generic map( 
      LAYER_ID => 1,
      OUTPUT_CHANNEL_ID => 1,
      INPUT_CHANNEL_NUMBER => INPUT_CHANNEL_NUMBER,
      MIF_PATH => MIF_PATH,
      WEIGHT_MIF_PREAMBLE => WEIGHT_MIF_PREAMBLE,
      BIAS_MIF_PREAMBLE => BIAS_MIF_PREAMBLE,
      CH_FRAC_MIF_PREAMBLE => CH_FRAC_MIF_PREAMBLE,
      K_FRAC_MIF_PREAMBLE => K_FRAC_MIF_PREAMBLE)
    Port map(
      Clk_i      => layer_clk,     
      Rst_i      => not layer_aresetn,     
      S_Valid_i	 => s_valid,	
      S_X_data_i => s_data,
      S_Last_i   => s_last,  
      S_Ready_o  => s_ready, 
      M_Valid_o	 => m_Valid,
      M_Y_data_o => m_Y_data,
      M_Last_o   => m_Last,
      M_Ready_i  => m_Ready 
    ); 
 
  Monitor: process(layer_clk,layer_aresetn)
    constant result_img_dim : integer_vector := csvGetNumpyDim(TB_CSV_RESULTS_FILE);
    constant result_img_arr : int_vec_3d_t := csvGetNumpy3d(TB_CSV_RESULTS_FILE);
    
    variable batch_idx : integer := 0;
    variable width_idx : integer := 0;
    variable height_idx : integer := 0;
  begin
    if layer_aresetn = '0' then
      width_idx := 0;
      height_idx := 0;
      batch_idx := 0;
    elsif rising_edge(layer_clk) and m_Ready = '1' and m_Valid = '1' then
      info("[" & integer'image(batch_idx) & "][" & integer'image(height_idx) & "][" & integer'image(width_idx) & "] Got: " & integer'image(to_integer(unsigned(m_Y_data))) & " Expect: " & integer'image(result_img_arr(batch_idx,height_idx,width_idx)));
      check_equal(to_integer(unsigned(m_Y_data)),result_img_arr(batch_idx,height_idx,width_idx),
        "[" & integer'image(batch_idx) & "][" & integer'image(height_idx) & "][" & integer'image(width_idx) & "]"); 
      if height_idx = (result_img_dim(1)-1) and width_idx = (result_img_dim(2)-1) then 
        check(m_Last = '1', "Expect Last signal to be high at [" & integer'image(batch_idx) & "][" & integer'image(height_idx) & "][" & integer'image(width_idx) & "]"); 
      end if;
      if width_idx = result_img_dim(2)-1 then 
        if height_idx = result_img_dim(1)-1 then
          batch_idx := iterate(batch_idx,0,result_img_dim(0)-1);
        end if;
        height_idx := iterate(height_idx,0,result_img_dim(1)-1);
      end if;  
      width_idx := iterate(width_idx,0,result_img_dim(2)-1);
    end if; 
  end process;

 
end architecture;
