library ieee;
use ieee.std_logic_1164.all;
LIBRARY work;
use work.egg_box.all;

entity ShiftRegister_3x3 is
  Port (
    -- Clk and reset
    Clk_i           : in  STD_LOGIC; -- clock
    Rst_i          : in  STD_LOGIC; -- active low reset 
    
    -- Slave interface to previous memory controller  
    S_X_data_1_i      : in  STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0); --  Input vector element 1 |Vector: trans(1,2,3)
    S_X_data_2_i      : in  STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0); --  Input vector element 2 |Vector: trans(1,2,3)
    S_X_data_3_i      : in  STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0); --  Input vector element 3 |Vector: trans(1,2,3)
    S_Valid_i	    : in  STD_LOGIC; -- indicates if input data is valid 
    S_Newrow_i     : in  STD_LOGIC; -- indicates that a new row starts 
    S_Last_i       : in  STD_LOGIC; -- indicates end of block 
    S_Ready_o      : out STD_LOGIC := '0'; -- indicates if shiftregister is ready to for new data 
   
    M_X_data_o      : out kernel_input_array_t;  
    M_Valid_o	    : out STD_LOGIC := '0'; -- indicates if output data is valid 
    M_Last_o       : out STD_LOGIC := '0'; -- indicates end of block 
    M_Ready_i      : in  STD_LOGIC  -- indicates if next slave is ready to for new data   
  );
end ShiftRegister_3x3;

architecture Behavioral of ShiftRegister_3x3 is

attribute srl_style : string;
--attribute srl_style of sr : signal is "register";
--attribute srl_style of sr : signal is "srl";
--attribute srl_style of sr : signal is "srl_reg";
--attribute srl_style of sr : signal is "reg_srl_reg";



  type STATES is (INIT,NEW_ROW,RUN);
  signal state     :STATES := INIT;
  
  signal data_buffer_1 : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0) := (others => '0');
  signal data_buffer_2 : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0) := (others => '0');
  signal data_buffer_3 : STD_LOGIC_VECTOR((ACTIVATION_WIDTH - 1) downto 0) := (others => '0');

  signal shift_reg : kernel_input_array_t := (others => (others => '0'));  
  attribute ram_style : string;
  attribute ram_style of shift_reg : signal is "distributed";
    
  signal buffer_ready : STD_LOGIC := '0';
  signal m_ready_R : STD_LOGIC := '0';
  signal m_valid : std_logic := '0';

begin


  M_X_data_o <= shift_reg;
  S_Ready_o <= m_ready_R;
  M_Valid_o <= m_valid; 
  --M_Valid_o <= '0' when m_ready_R = '0' and M_Ready_i = '1' else m_valid; 
  --S_Ready_o <= M_Ready_i or buffer_ready;

  shifting: process(Clk_i, Rst_i)
  begin
    if rising_edge(Clk_i) then
      if Rst_i = '1' then    
        state <= INIT;
        M_Last_o <= '0';
        m_valid <= '0';
        shift_reg <= (others => (others => '0')); 
        buffer_ready <= '0';
        data_buffer_1 <= (others => '0');
        data_buffer_2 <= (others => '0');
        data_buffer_3 <= (others => '0');
      else 
        m_ready_R <= M_Ready_i;
        case(state) is 
          when INIT => 
            M_Last_o <= '0';
            m_valid <= '0';
            if S_Valid_i = '1' and S_Newrow_i = '1' then
              state <= NEW_ROW;
              data_buffer_1 <= S_X_data_1_i;
              data_buffer_2 <= S_X_data_2_i;
              data_buffer_3 <= S_X_data_3_i; 
              --buffer_ready <= '0';
            else
              --buffer_ready <= '1';
            end if; 
            

          when NEW_ROW => 
            M_Last_o <= '0';
            if S_Valid_i = '1' then
              state <= RUN;
              shift_reg(0) <= (others => '0');
              shift_reg(3) <= (others => '0');
              shift_reg(6) <= (others => '0');
              shift_reg(1) <= data_buffer_1;
              shift_reg(4) <= data_buffer_2;
              shift_reg(7) <= data_buffer_3;
              shift_reg(2) <= S_X_data_1_i;
              shift_reg(5) <= S_X_data_2_i;
              shift_reg(8) <= S_X_data_3_i;
            end if;
            m_valid <= S_Valid_i;

          when RUN => 
            if M_Ready_i = '1' and S_Valid_i = '1' then
              if S_Newrow_i = '1' then 
                shift_reg(0) <= shift_reg(1);
                shift_reg(3) <= shift_reg(4);
                shift_reg(6) <= shift_reg(7);
                shift_reg(1) <= shift_reg(2);
                shift_reg(4) <= shift_reg(5);
                shift_reg(7) <= shift_reg(8);
                shift_reg(2) <= (others => '0');
                shift_reg(5) <= (others => '0');
                shift_reg(8) <= (others => '0'); 
                data_buffer_1 <= S_X_data_1_i;
                data_buffer_2 <= S_X_data_2_i;
                data_buffer_3 <= S_X_data_3_i;   
                if S_Last_i = '1' then 
                  state <= INIT;
                else 
                  state <= NEW_ROW;
                end if;
              else  
                shift_reg(0) <= shift_reg(1);
                shift_reg(3) <= shift_reg(4);
                shift_reg(6) <= shift_reg(7);
                shift_reg(1) <= shift_reg(2);
                shift_reg(4) <= shift_reg(5);
                shift_reg(7) <= shift_reg(8);
                shift_reg(2) <= S_X_data_1_i;
                shift_reg(5) <= S_X_data_2_i;
                shift_reg(8) <= S_X_data_3_i; 
              end if;
              if S_Last_i = '1' then 
                M_Last_o <= '1'; 
              end if;
            end if; 
            m_valid <= S_Valid_i;
          when others => 
            state <= INIT;  
        end case;
      end if;
    end if;
  end process;
end Behavioral;
