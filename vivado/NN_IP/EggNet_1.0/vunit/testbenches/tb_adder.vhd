library IEEE ;
  use ieee.std_logic_1164.all ;
  use ieee.numeric_std.all ;
  use std.textio.all ;
  use ieee.std_logic_textio.all ;
  
library vunit_lib;
context vunit_lib.vunit_context;



library OSVVM ; 
  use OSVVM.RandomBasePkg.all ; 
  use OSVVM.RandomPkg.all ; 


entity tb_adder is
  generic (runner_cfg : string := runner_cfg_default;
          TB_PERIOD : time := 10 ns;
          DATA_WIDTH : integer := 12;
          OUTPUT_WIDTH : integer := 9;
          FRAC_SHIFT : integer := 2);
end entity;

architecture tb of tb_adder is
  signal sim_done : std_logic := '0';
  signal nRst,Rst, clk : std_logic := '0';
  signal A, B, A_R, A_RR, B_R, B_RR, A_RRR, B_RRR : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal Sum_UUT, S:  std_logic_vector(OUTPUT_WIDTH-1 downto 0);
  signal Sum_Tb : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
  signal Sum_UUT_fp, Sum_Tb_fp : std_logic_vector(DATA_WIDTH downto 0);
  signal shifted : signed(DATA_WIDTH downto 0);
  signal quantized : signed(OUTPUT_WIDTH-1 downto 0);
  
begin


  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);
    sim_done <= '0';
    nRst <= '0';
    wait for 5 ns; 
    nRst <= '1'; 
    wait for 100 us; 
    sim_done <= '1'; 
    test_runner_cleanup(runner);
  end process;



  Monitor: process(nRst,clk)
    variable sum : signed(DATA_WIDTH downto 0);
  begin
    if nRst = '0' then
      sum := (others => '0');
      Sum_Tb <= (others => '0');
      quantized <= (others => '0');
      shifted <= (others => '0');
      Sum_Tb_fp <= (others => '0');
    elsif rising_edge(clk) then 
      sum := resize(signed(A),DATA_WIDTH+1) + resize(signed(B),DATA_WIDTH+1);
      Sum_Tb_fp <= std_logic_vector(sum);
      if sum(sum'left) = '1' and ((-1)*sum)+1 < (2**FRAC_SHIFT) then 
        --info(integer'image(to_integer(sum)) & " shift by " & integer'image(FRAC_SHIFT) & " results in Underflow");
        shifted <= (others => '0');
      else
        shifted <= shift_right(sum,FRAC_SHIFT); 
      end if;
      if shifted > to_signed(2**(OUTPUT_WIDTH-1)-1,OUTPUT_WIDTH) then 
        quantized(OUTPUT_WIDTH-2 downto 0) <= (others => '1');
        quantized(quantized'left) <= '0';
      elsif shifted < to_signed(2**(OUTPUT_WIDTH-1)*(-1),OUTPUT_WIDTH) then 
        quantized(OUTPUT_WIDTH-2 downto 0) <= (others => '0');
        quantized(quantized'left) <= '1';    
      else
        quantized <= shifted(OUTPUT_WIDTH-1 downto 0);
      end if;
      Sum_Tb <= std_logic_vector(quantized);
      
      
      check_equal(to_string(Sum_UUT), to_string(Sum_Tb), integer'image(to_integer(signed(A_RRR))) & 
                " + " & integer'image(to_integer(signed(B_RRR))) & 
                " != " & integer'image(to_integer(signed(Sum_UUT))) & 
                " expected: " & integer'image(to_integer(signed(Sum_Tb))));
      check_equal(to_string(Sum_UUT_fp), to_string(Sum_Tb_fp), integer'image(to_integer(signed(A))) & 
                " + " & integer'image(to_integer(signed(B))) & 
                " != " & integer'image(to_integer(signed(Sum_UUT))) & 
                " expected: " & integer'image(to_integer(signed(Sum_Tb_fp))));     
    end if;    
  end process;
  
  clk <= not clk after TB_PERIOD/2 when sim_done /= '1' else '0';
  Rst <= not nRst; 

  Stimuli_gen: process(nRst,clk)
    variable RV : RandomPType ; 
    variable DataSigned : signed(DATA_WIDTH-1 downto 0) ;
  begin
    --RV.InitSeed (RV'instance_name)  ;              -- Generate initial seeds
    if nRst = '0' then
      A <= (others => '0'); 
      B <= (others => '0');
      A_R <= (others => '0'); 
      B_R <= (others => '0');
      A_RR <= (others => '0'); 
      B_RR <= (others => '0');      
    elsif rising_edge(clk) then 
      -- Generate a value in range -128 to 127
      DataSigned := RV.RandSigned((-1)*2**(DATA_WIDTH-1), 2**(DATA_WIDTH-1)-1, DATA_WIDTH);
      A <= std_logic_vector(DataSigned);
      DataSigned := RV.RandSigned((-1)*2**(DATA_WIDTH-1), 2**(DATA_WIDTH-1)-1, DATA_WIDTH);
      B <= std_logic_vector(DataSigned);
      A_R <= A; 
      A_RR <= A_R;
      B_R <= B;
      B_RR <= B_R; 
      A_RRR <= A_RR;
      B_RRR <= B_RR;      
    end if;
  end process;  
    
  adder_q: entity work.quantized_adder 
      generic map(INPUT_WIDTH => DATA_WIDTH,
                OUTPUT_WIDTH => OUTPUT_WIDTH, 
                FRAC_SHIFT => FRAC_SHIFT) 
      port map( Clk_i => clk,
                Ready_i => '1',
                A_i => A,
                B_i => B,
                S_o => Sum_UUT);
                
  adder_fp: entity work.fullp_adder_2th_comp 
      generic map(BIT_WIDTH => DATA_WIDTH) 
      port map( Clk_i => clk,
                Rst_i => Rst,
                Ready_i => '1',
                A_i => A,
                B_i => B,
                S_o => Sum_UUT_fp); 
end tb;