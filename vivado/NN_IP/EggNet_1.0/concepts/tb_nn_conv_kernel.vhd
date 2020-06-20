
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use IEEE.math_real.log2;
library vunit_lib;
context vunit_lib.vunit_context;
use work.nnpkg.all;

entity tb_nn_conv_kernel is
    generic (
        runner_cfg : string;
        TB_PERIOD  : time := 10 ns
    );
end entity;

architecture tb of tb_nn_conv_kernel is

    signal clk      : std_logic                        := '0';
    signal rst      : std_logic                        := '0';
    signal sim_done : std_logic                        := '0';
    signal b_i      : std_logic_vector(16 - 1 downto 0) := (others => '0');
    signal x_i      : vec1d_t(0 to 3 - 1)(8 - 1 downto 0);
    signal w_i      : vec2d_t(0 to 3 - 1, 0 to 3 - 1)(8 - 1 downto 0);

    signal y_o : std_logic_vector(16 - 1 downto 0);

    type ivec2d_t is array (natural range <>, natural range <>) of natural;

    signal ctl_alu_type : nn_alu_type := ALU_CONV;

    constant TEST_IMG : ivec2d_t := (
    (0, 1, 4, 7, 0),
    (0, 2, 5, 8, 0),
    (0, 3, 6, 9, 0)
    );

    constant TEST_W : ivec2d_t := (
    (2, 2, 2),
    (2, 2, 2),
    (2, 2, 2)
    );

begin

    clk <= not clk after TB_PERIOD/2 when sim_done /= '1' else
        '0';

    test_runner : process
    begin
        test_runner_setup(runner, runner_cfg);
        sim_done <= '0';
        rst      <= '1';
        wait for TB_PERIOD;
        wait until rising_edge(clk);
        rst <= '0';

        -- Apply weights
        for i in 0 to 3 - 1 loop
            for j in 0 to 3 - 1 loop
                w_i(i, j) <= std_logic_vector(to_unsigned(TEST_W(i, j), 8));
            end loop; -- identifier
        end loop; -- identifier

        wait until rising_edge(clk);

        image_loop : for i in 0 to 5 - 1 loop
            
            wait until rising_edge(clk);
            x_i(0) <= std_logic_vector(to_unsigned(TEST_IMG(0, i), 8));
            x_i(1) <= std_logic_vector(to_unsigned(TEST_IMG(1, i), 8));
            x_i(2) <= std_logic_vector(to_unsigned(TEST_IMG(2, i), 8));
            
            -- Defer Output
            wait until falling_edge(clk);
            info("Output @ CLK (" & integer'image(i) & "): " & integer'image(to_integer(unsigned(y_o))));

        end loop; -- image_loop
        -- Expected output:
        -- [ 42. 90. 78.] + BIAS

        wait until rising_edge(clk);
        info("Output: " & integer'image(to_integer(unsigned(y_o))));

        wait until rising_edge(clk);
        info("Output: " & integer'image(to_integer(unsigned(y_o))));

        wait until rising_edge(clk);
        info("Output: " & integer'image(to_integer(unsigned(y_o))));
        sim_done <= '1';
        test_runner_cleanup(runner);
    end process; -- test_runner

    nn_alu_0 : entity work.nn_conv_kernel
        generic map(
            FILTER_WIDTH  => 3,
            FILTER_HEIGHT => 3,
            INPUT_BITS    => 8,
            WEIGHT_BITS   => 8
        )
        port map(
            clk          => clk,
            rst          => rst,
            ctl_alu_type => ctl_alu_type,
            x_i          => x_i,
            w_i          => w_i,
            b_i          => b_i,
            y_o          => y_o,
            ya_o         => open
        );

end architecture;