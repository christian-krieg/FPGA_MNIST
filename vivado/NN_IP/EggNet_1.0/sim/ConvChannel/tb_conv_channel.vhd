library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;


entity tb_conv_channel is
    generic (
        runner_cfg : string;
        TB_PERIOD  : time := 20 ns
    );
end entity;

architecture rtl of tb_conv_channel is
    signal clk      : std_logic := '0';
    signal sim_done : std_logic := '0';
begin

    clk <= not clk after TB_PERIOD/2 when sim_done /= '1' else
        '0';

    test_runner : process
    begin
        test_runner_setup(runner, runner_cfg);
        sim_done <= '0';

        -- Simulate some tests
        wait for 10 * TB_PERIOD;

        sim_done <= '1';
        test_runner_cleanup(runner);
    end process; -- test_runner
end architecture;