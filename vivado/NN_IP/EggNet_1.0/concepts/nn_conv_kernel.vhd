library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- General ALU Operation of EggNet
--
--
-- 3 General Phases:
--     1) Multiply
--     2) Add
--     3) Accum
--
-- The input can be pipelined/streamed through the ALU. Depending on the number of MUL and ADD
-- operations that can be performed in a single step, the entity is generic adjustable.
--  
-- Also the result of the ADD operation can be added and stored to the accumulator on the same line
-- which is useful for general matrix multiplication. It can also be combined with the accumulator
-- on the same line and stored in the accumulator below. This then implements a convolutional 
-- operation.
--
--
--                                                       b   Bias Input
--               Mul                Add         Accum    +
--                                                       |
--                           +-+                         v
--                           |-|          +-+           +++
--                   +---->  |-| +------> + +-----+     | |
--                   |       |-|          +-+     |     +++
--     I     x       |       +-+                  |      |
--     M             |                            +----->+
--     A    +-+      |                                   |
--     G    |-|      |       +-+                         v
--     E    |-|      |       |-|          +-+           +++
--          |-| +--------->  |-| +------> +-+------+    | |
--     P    |-|      |       |-|          +-+      |    +++
--     A    +-+      |       +-+                   |     |
--     T             |                             +---->+
--     C             |                                   |
--     H             |       +-+                         v
--                   |       |-|          +-+           +++
--                   +---->  |-| +----->  +-+------+    | |
--                           |-|          +-+      |    +++
--                           +-+                   |     |
--                                                 +---->+
--                                                       |
--                                                       v
--                                        Convolution
--                                        Output         y

use work.nnpkg.all;
entity nn_conv_kernel is

    generic (
        FILTER_WIDTH  : natural := 3; -- Filter/Kernel Width
        FILTER_HEIGHT : natural := 3; -- Filter/Kernel Height
        INPUT_BITS    : natural := 8; -- Bits of the input vector x
        WEIGHT_BITS   : natural := 8; -- Bits used for the weights
        OUTPUT_BITS   : natural := INPUT_BITS + WEIGHT_BITS
        -- OUTPUT_BITS    : natural := INPUT_BITS + nlog2(PARALLEL_INPUT) -- prevent overflow
    );

    port (
        -- Control signals
        clk          : in std_logic;
        rst          : in std_logic;
        ctl_alu_type : in nn_alu_type; -- Defines if Convolution Mode or Matrix Mode should be performed

        -- Inputs
        w_i : in vec2d_t(0 to FILTER_HEIGHT - 1, 0 to FILTER_WIDTH - 1)(WEIGHT_BITS - 1 downto 0);
        x_i : in vec1d_t(0 to FILTER_HEIGHT - 1)(INPUT_BITS - 1 downto 0);
        b_i : in std_logic_vector(OUTPUT_BITS - 1 downto 0); -- Added bias (convolution only )

        -- Outputs
        y_o  : out std_logic_vector(OUTPUT_BITS - 1 downto 0);
        ya_o : out vec1d_t(0 to FILTER_WIDTH - 1)(OUTPUT_BITS - 1 downto 0)
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
        -- # TODO This is a bit ugly and maybe it's not a good idea to have an array in the sensitivity list
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

    -- ya_o directly reflects the accumulator
    ya_o <= a_n;
    op_process : process (clk, rst)
    begin
        if rst = '1' then
            a_n <= a_n_ZERO;
            z_n <= a_n_ZERO;
        elsif rising_edge(clk) then

            -- Independent of operation, simply the last output. (to avoid generating a latch)
            y_o <= std_logic_vector(unsigned(a_n(FILTER_WIDTH - 1)) + unsigned(z_n(FILTER_WIDTH - 1)));

            if ctl_alu_type = ALU_CONV then

                -- Convoltional operation
                a_n(0) <= b_i;
                accum_conv : for i in 1 to FILTER_WIDTH - 1 loop
                    a_n(i) <= std_logic_vector(unsigned(a_n(i - 1)) + unsigned(z_n(i - 1)));
                end loop; -- accum

            else
                -- Matrix Multiplication
                accum_mat : for i in 0 to FILTER_WIDTH - 1 loop
                    a_n(i) <= std_logic_vector(unsigned(a_n(i)) + unsigned(z_n(i)));
                end loop; -- accum

            end if;

        end if;
    end process;
end architecture;