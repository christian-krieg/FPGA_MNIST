library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.kernel_pkg.all;
use work.ShiftKernel3x3;

entity tb_3x3_shift_kernel is
end tb_3x3_shift_kernel;

architecture beh of tb_3x3_shift_kernel is
	constant BIT_WIDTH_IN : INTEGER := 8;
	constant BIT_WIDTH_OUT : INTEGER := 20;

	--test kernel
	constant WEIGHT_SHIFTS : conv_kernel_3x3_weight_shift_t := (-125, -128, -128, -128, 31, 67, -128, 62, 127);
	constant WEIGHT_SIGNS : conv_kernel_3x3_weight_sign_t := (-125, -128, -128, -128, 31, 67, -128, 62, 127);
	constant INPUTS : weight_array_t := (0, 0, 0, 74, 247, 41, 69, 215, 148);

	constant CLK_PERIOD : TIME := 10 ns; -- 100MHz

	signal s_Clk_i, s_n_Res_i, s_Valid_i : std_logic;
	signal s_X_i : std_logic_vector(BIT_WIDTH_IN * KERNEL_SIZE - 1 downto 0);
	signal s_Y_o : signed(BIT_WIDTH_OUT - 1 downto 0);
begin

	uit : entity work.ShiftKernel3x3
		generic map(
			BIT_WIDTH_IN=>BIT_WIDTH_IN,
			BIT_WIDTH_OUT=>BIT_WIDTH_OUT,
			WEIGHT_SHIFTS=>WEIGHT_SHIFTS,
			WEIGHT_SIGNS=>WEIGHT_SIGNS,
			WEIGHT_WIDTH=>WEIGHT_WIDTH,
		) 
		port map (
			Clk_i => s_Clk_i,
			n_Res_i => s_n_Res_i,
			Valid_i => s_Valid_i,
			X_i => s_X_i,
			Y_o => s_Y_o
		);

	-- Generates the clock signal
	clkgen : process
	begin
		s_Clk_i <= '0';
		wait for CLK_PERIOD/2;
		s_Clk_i <= '1';
		wait for CLK_PERIOD/2;
	end process clkgen;

	-- Generates the reset signal
	reset : process
	begin -- process reset
		s_n_Res_i <= '0';
		wait for 55 ns;
		s_n_Res_i <= '1';
		wait;
	end process;

	input : process
		variable seed1 : POSITIVE;
		variable seed2 : POSITIVE;
		variable x : real;
		variable y : INTEGER;
		variable result : INTEGER := 0;
	begin
		--initialize random function
		seed1 := 1;
		seed2 := 2;

		s_X_i <= (others => '0');
		s_Valid_i <= '0';
		wait until rising_edge(s_n_Res_i);
		s_Valid_i <= '1';

		--fill input vector with random values between - 2**(BIT_WIDTH_IN - 1) and  2**(BIT_WIDTH_IN - 1) - 1
		for I in 0 to 8 loop
			uniform(seed1, seed2, x);
			--y := integer(floor(x * (2.0 ** BIT_WIDTH_IN)));
			y := INPUTS(I);
			report "X(" & INTEGER'image(I) & "): " & INTEGER'image(y);
			report "WEIGHT(" & INTEGER'image(I) & "): " & INTEGER'image(WEIGHT(I));
			s_X_i((I + 1) * BIT_WIDTH_IN - 1 downto I * BIT_WIDTH_IN) <= std_logic_vector(to_signed(y, BIT_WIDTH_IN));
			result := result + y * WEIGHT(I);
		end loop;

		--Compare expected to actual result
		report "Result: " & INTEGER'image(result);
		wait until rising_edge(s_Clk_i);
		s_Valid_i <= '0';
		wait until rising_edge(s_Clk_i);
		report "Output from uit: " & INTEGER'image(to_integer(s_Y_o));
		assert to_integer(s_Y_o) = result report "Actual and expected output does not match up!" severity error;
	end process;
end beh;