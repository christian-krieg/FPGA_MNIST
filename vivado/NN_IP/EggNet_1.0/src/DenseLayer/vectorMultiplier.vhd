----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:58:14 10/18/2019 
-- Design Name: 
-- Module Name:    matrix_multiplier - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;
use STD.textio.all;

LIBRARY work;
use work.multiplier; 
use work.accumulator;
USE work.denseLayerPkg.all;
USE work.clogb2_Pkg.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity vectorMultiplier is
	Generic(   VECTOR_WIDTH : integer := 8;
	           INPUT_COUNT : integer := 4;
			   OUTPUT_COUNT : integer := 4;
			   BIAS_WIDTH : integer := 8;
			   BIAS_FILE : string  := "bias_terms.mif");
    Port ( 
			  Resetn_i : in std_logic;
			  Reset_calculation_i : in std_logic;
			  Valid_i : in std_logic;
			  Clk_i : in std_logic;
			  Rd_en_o : out std_logic;
			  Data_i : in std_logic_vector(VECTOR_WIDTH-1 downto 0);
			  Weights_address_o : out std_logic_vector(clogb2(INPUT_COUNT)-1 downto 0);
			  Weights_i : in array_type(OUTPUT_COUNT-1 downto 0)(VECTOR_WIDTH-1 downto 0);
        Output_o : out  array_type(OUTPUT_COUNT-1 downto 0)(2*VECTOR_WIDTH + clogb2(INPUT_COUNT)-1 downto 0);
			  Start_calculation_i : in std_logic;
			  Write_data_o : out std_logic);
			  
end vectorMultiplier;

architecture Behavioral of vectorMultiplier is

    signal s_multiplied : array_type(OUTPUT_COUNT-1 downto 0)(2*VECTOR_WIDTH-1 downto 0);
    
    type state_type is (
		ST_IDLE, 
		ST_CALCULATING, 
		ST_WAIT_CALCULATION, 
		ST_WRITE_DATA
	);
    signal state, state_next : state_type := ST_IDLE;
    
    signal s_counter, s_counter_next : std_logic_vector(clogb2(INPUT_COUNT)-1 downto 0) := (others=>'0');
    
    signal s_enable_accumulation : std_logic := '0';
    
    signal s_reset_accumulators : std_logic := '0';
    
    
    
-- Definition of bias terms array.
type bias_array is array (0 to OUTPUT_COUNT-1) of std_logic_vector(BIAS_WIDTH-1 downto 0);    

-- This function initializes bias terms array with the data from a .mif file.
impure function init_mem(mif_file_name : in string) return bias_array is
	file mif_file 		: text open read_mode is mif_file_name;
	variable mif_line	: line;
	variable temp_bv	: bit_vector(BIAS_WIDTH-1 downto 0);
	variable temp_mem	: bias_array;
begin

	for i in 0 to OUTPUT_COUNT-1 loop
		readline (mif_file, mif_line);
		read(mif_line, temp_bv);
		temp_mem(i) := to_stdlogicvector(temp_bv);
	end loop;

	return temp_mem;
end function;

signal s_reset_values : bias_array := init_mem(BIAS_FILE);



begin
    
    -- Generate as many multiplier-accumulator pairs as there are output neurons.
    generateMultipliers: for i in 0 to OUTPUT_COUNT-1 generate
        -- Multiplies the input pixel with appropriate weight.
        multiplierBlock : entity work.multiplier
        generic map
        (
           VECTOR_WIDTH => VECTOR_WIDTH
        )
        port map
        (
            A_in => Data_i,
            B_in => Weights_i(i),
            C_out => s_multiplied(i)
        );
        -- Accumulates multiplied values.
        accumulatorBlock : entity work.accumulator
        generic map
        (
            BIAS_WIDTH => BIAS_WIDTH,
            INPUT_WIDTH => 2*VECTOR_WIDTH,
            OUTPUT_WIDTH => 2*VECTOR_WIDTH + clogb2(INPUT_COUNT)
        )
        port map
        (
            Clk_i => Clk_i,
            Reset_i => s_reset_accumulators,
            Enable_i => s_enable_accumulation,
            Reset_value_i => s_reset_values(i),
            Data_i => s_multiplied(i),
            Data_o => Output_o(i)
        );
    end generate generateMultipliers;
    
    Weights_address_o <= s_counter_next;
    
    -- Finite state machine, that controls the calculation of all pixels.
    FSM : process(state, Start_calculation_i, s_counter, Reset_calculation_i, Valid_i)
    begin
		state_next <= state;
		s_counter_next <= s_counter;
	
		case state is

			-- FSM is in idle state until it receives a signal to start calculations.
			when ST_IDLE =>
				s_enable_accumulation <= '0';
				s_reset_accumulators <= '1';
				Rd_en_o <= '0';
				Write_data_o <= '0';
				
				s_counter_next <= (others=>'0');
				
				if(Start_calculation_i='1')then
					if Valid_i = '1' then
						s_counter_next <= s_counter + '1';
						s_enable_accumulation <= '1';
					end if;
					s_reset_accumulators <= '0';
					Rd_en_o <= '1';
					state_next <= ST_CALCULATING;
				end if;
			
			-- FSM is in this state until all of the pixels have been calculated.
			when ST_CALCULATING =>
				s_reset_accumulators <= '0';
				Rd_en_o <= '1';
				Write_data_o <= '0';
				
				if Valid_i = '1' then
					s_enable_accumulation <= '1';
					if(s_counter = INPUT_COUNT-1)then
						state_next <= ST_WAIT_CALCULATION;
					else
						s_counter_next <= s_counter + '1';
					end if;
				end if;
			
			-- This state is to wait the calculation of the last pixel.
			when ST_WAIT_CALCULATION =>
				s_enable_accumulation <= '0';
				s_reset_accumulators <= '0';
				Rd_en_o <= '0';
				Write_data_o <= '0';
				
				state_next <= ST_WRITE_DATA;
			
			-- Write_data_o is pulsed, to notify that calculation is finished
			when ST_WRITE_DATA =>
				s_enable_accumulation <= '0';
				s_reset_accumulators <= '0';
				Rd_en_o <= '0';
				Write_data_o <= '1';
				
				if Reset_calculation_i = '1' then
					state_next <= ST_IDLE;	
				end if;
				
		end case;
    end process;
	
	sync: process(Clk_i)
	begin
		if Resetn_i = '0' then
			state <= ST_IDLE;
			s_counter <= s_counter_next;
		elsif rising_edge(Clk_i) then
			state <= state_next;
			s_counter <= s_counter_next;
		end if;
	end process;

end Behavioral;

