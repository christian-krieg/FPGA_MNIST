library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.nnpkg.all;
entity nn_conv_kernel is

    generic (
        FILTER_WIDTH     : natural := 3;
        FILTER_HEIGHT    : natural := 3;
        INPUT_BITS       : natural := 8;
        CONV_MODE_ENABLE : boolean := true;
        WEIGHT_BITS      : natural := 8;
        OUTPUT_BITS      : natural := INPUT_BITS + WEIGHT_BITS
        -- OUTPUT_BITS    : natural := INPUT_BITS + nlog2(PARALLEL_INPUT) -- prevent overflow
    );

    port (
        clk : in std_logic;
        rst : in std_logic;

        w_i : in vec2d_t(0 to FILTER_HEIGHT - 1, 0 to FILTER_WIDTH - 1)(WEIGHT_BITS - 1 downto 0);
        x_i : in vec1d_t(0 to FILTER_HEIGHT - 1)(INPUT_BITS - 1 downto 0);

        y_o : out std_logic_vector(OUTPUT_BITS - 1 downto 0)

    );
end entity nn_conv_kernel;

architecture rtl of nn_conv_kernel is

    -- type weight_array_t is array (0 to FILTER_WIDTH - 1) of vec1d_t(0 to FILTER_HEIGHT - 1)(WEIGHT_BITS - 1 downto 0);
    type weight_array_t is array (natural range <>) of vec1d_t;
    constant w_n_ZERO : weight_array_t(0 to FILTER_WIDTH - 1)(0 to FILTER_HEIGHT - 1)(WEIGHT_BITS - 1 downto 0) := (others => (others => (others => '0')));
    signal w_n        : weight_array_t(0 to FILTER_WIDTH - 1)(0 to FILTER_HEIGHT - 1)(WEIGHT_BITS - 1 downto 0) := w_n_ZERO;

    constant a_n_ZERO : vec1d_t(0 to FILTER_WIDTH - 1)(OUTPUT_BITS - 1 downto 0) := (others => (others => '0'));
    signal z_n        : vec1d_t(0 to FILTER_WIDTH - 1)(OUTPUT_BITS - 1 downto 0) := a_n_ZERO;
    signal a_n        : vec1d_t(0 to FILTER_WIDTH - 1)(OUTPUT_BITS - 1 downto 0) := a_n_ZERO;
begin

    update_weights : process (w_i)
    begin
        for i in 0 to FILTER_WIDTH - 1 loop
            for j in 0 to FILTER_HEIGHT - 1 loop
                w_n(i)(j) <= w_i(j, i);
            end loop;
        end loop;
    end process; -- update_weights

    --- Generate ALU's
    gen_alu : for i in 0 to FILTER_WIDTH - 1 generate
        nn_alu_0 : entity work.nn_alu
            generic map(
                PARALLEL_INPUT => FILTER_HEIGHT,
                INPUT_BITS     => INPUT_BITS,
                WEIGHT_BITS    => WEIGHT_BITS,
                OUTPUT_BITS    => OUTPUT_BITS
            )
            port map(
                clk => clk,
                rst => rst,
                x_i => x_i,
                w_i => w_n(i),
                y_o => z_n(i)
            );
    end generate;

    process (clk, rst)
    begin
        if rst = '1' then
            a_n <= a_n_ZERO;
        elsif rising_edge(clk) then

            a_n(0) <= (others => '0');
            y_o    <= std_logic_vector(unsigned(a_n(FILTER_WIDTH - 1)) + unsigned(z_n(FILTER_WIDTH - 1)));
            accum : for i in 1 to FILTER_WIDTH - 1 loop
                a_n(i) <= std_logic_vector(unsigned(a_n(i - 1)) + unsigned(z_n(i - 1)));
            end loop; -- accum
        end if;
    end process;

end architecture;