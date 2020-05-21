library ieee;
use ieee.std_logic_1164.all;
LIBRARY work;
use work.egg_box.all;

entity ShiftRegister_3x3 is
  Port (
    -- Clk and reset
    Clk_i           : in  STD_LOGIC; -- clock
    nRst_i          : in  STD_LOGIC; -- active low reset 
    
    -- Slave interface to previous memory controller  
    S_X_data_1_i      : in  STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0); --  Input vector element 1 |Vector: trans(1,2,3)
    S_X_data_2_i      : in  STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0); --  Input vector element 2 |Vector: trans(1,2,3)
    S_X_data_3_i      : in  STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0); --  Input vector element 3 |Vector: trans(1,2,3)
    S_Valid_i	    : in  STD_LOGIC; -- indicates if input data is valid 
    S_Newrow_i     : in  STD_LOGIC; -- indicates that a new row starts 
    S_Last_i       : in  STD_LOGIC; -- indicates end of block 
    S_Ready_o      : out STD_LOGIC; -- indicates if shiftregister is ready to for new data 
   
    M_X_data_o      : out kernel_input_array_t;  
    M_Valid_o	    : out STD_LOGIC; -- indicates if output data is valid 
    M_Last_o       : out STD_LOGIC; -- indicates end of block 
    M_Ready_i      : in  STD_LOGIC  -- indicates if next slave is ready to for new data   
  );
end ShiftRegister_3x3;

architecture Behavioral of ShiftRegister_3x3 is

attribute srl_style : string;
--attribute srl_style of sr : signal is "register";
--attribute srl_style of sr : signal is "srl";
--attribute srl_style of sr : signal is "srl_reg";
--attribute srl_style of sr : signal is "reg_srl_reg";



  type STATES is (INIT,NEW_LINE,RUN);
  signal state     :STATES;
  
  signal data_buffer_1 : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0);
  signal data_buffer_2 : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0);
  signal data_buffer_3 : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0);
  
  signal data_1    : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0);
  signal data_2    : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0);
  signal data_3    : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0);
  signal data_4    : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0);
  signal data_5    : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0);
  signal data_6    : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0);
  signal data_7    : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0);
  signal data_8    : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0);
  signal data_9    : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0);
  
  attribute ram_style : string;
  attribute ram_style of data_1 : signal is "distributed";
  attribute ram_style of data_2 : signal is "distributed";
  attribute ram_style of data_3 : signal is "distributed";
  attribute ram_style of data_4 : signal is "distributed";
  attribute ram_style of data_5 : signal is "distributed";
  attribute ram_style of data_6 : signal is "distributed";
  attribute ram_style of data_7 : signal is "distributed";
  attribute ram_style of data_8 : signal is "distributed";
  attribute ram_style of data_9 : signal is "distributed";  
  attribute ram_style of data_buffer_1 : signal is "distributed";
  attribute ram_style of data_buffer_2 : signal is "distributed";
  attribute ram_style of data_buffer_3 : signal is "distributed";  
    
  

begin

  M_X_data_o(0) <= data_1;
  M_X_data_o(1) <= data_2;
  M_X_data_o(2) <= data_3;
  M_X_data_o(3) <= data_4;
  M_X_data_o(4) <= data_5;
  M_X_data_o(5) <= data_6;
  M_X_data_o(6) <= data_7;
  M_X_data_o(7) <= data_8;
  M_X_data_o(8) <= data_9;

  shifting: process(Clk_i, nRst_i)
  begin
    if nRst_i = '0' then    
      state <= INIT;
      M_Last_o <= '0';
      M_Valid_o <= '0';
      S_Ready_o <= '1';
    elsif rising_edge(Clk_i) then
      
      case(state) is 
        when INIT => 
          S_Ready_o <= '1';
          M_Last_o <= '0';
          M_Valid_o <= '0';
          if S_Valid_i = '1' and S_Newrow_i = '1' then
            state <= NEW_LINE;
            data_buffer_1 <= S_X_data_1_i;
            data_buffer_2 <= S_X_data_2_i;
            data_buffer_3 <= S_X_data_3_i; 
          end if; 
          

        when NEW_LINE => 
          S_Ready_o <= '1';
          M_Last_o <= '0';
          if S_Valid_i = '1' then
            state <= RUN;
            data_1 <= (others => '0');
            data_2 <= (others => '0');
            data_3 <= (others => '0');
            data_4 <= data_buffer_1;
            data_5 <= data_buffer_2;
            data_6 <= data_buffer_3;
            data_7 <= S_X_data_1_i;
            data_8 <= S_X_data_2_i;
            data_9 <= S_X_data_3_i;
            M_Valid_o <= '1';
          else 
            M_Valid_o <= '0';
          end if;
        
        when RUN => 
          S_Ready_o <= M_Ready_i;
          if S_Valid_i = '1' then
            M_Valid_o <= '1';
            if M_Ready_i = '1' then 
              if S_Newrow_i = '1' then 
                data_1 <= data_4;
                data_2 <= data_5;
                data_3 <= data_6;
                data_4 <= data_7;
                data_5 <= data_8;
                data_6 <= data_9;
                data_7 <= (others => '0');
                data_8 <= (others => '0');
                data_9 <= (others => '0'); 
                data_buffer_1 <= S_X_data_1_i;
                data_buffer_2 <= S_X_data_2_i;
                data_buffer_3 <= S_X_data_3_i;   
                if S_Last_i = '1' then 
                  state <= INIT;
                else 
                  state <= NEW_LINE;
                end if;
              else  
                data_1 <= data_4;
                data_2 <= data_5;
                data_3 <= data_6;
                data_4 <= data_7;
                data_5 <= data_8;
                data_6 <= data_9;
                data_7 <= S_X_data_1_i;
                data_8 <= S_X_data_2_i;
                data_9 <= S_X_data_3_i;
              end if;
              if S_Last_i = '1' then 
                M_Last_o <= S_Last_i; 
              end if;
            end if; 
          end if; 
        when others => 
          state <= INIT;  
      end case;
    end if;
  end process;
end Behavioral;
