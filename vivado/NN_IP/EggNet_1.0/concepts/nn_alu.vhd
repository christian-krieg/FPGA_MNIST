------------------------------------
-- NN ALU 
------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.nnpkg.all;

-- NN ALU Component
entity nn_alu is
    generic (
        PARALLEL_INPUT : natural := 3;
        INPUT_BITS     : natural := 8;
        WEIGHT_BITS    : natural := 8;
        OUTPUT_BITS    : natural := INPUT_BITS + WEIGHT_BITS
        -- OUTPUT_BITS    : natural := INPUT_BITS + nlog2(PARALLEL_INPUT) -- prevent overflow
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        -- SWITCH
        -- mode : in std_logic;

        -- x_i   : in std_logic_vector(0 to PARALLEL_INPUT - 1, INPUT_BITS - 1 downto 0);
        x_i : in vec1d_t(0 to PARALLEL_INPUT - 1)(INPUT_BITS - 1 downto 0);
        w_i : in vec1d_t(0 to PARALLEL_INPUT - 1)(WEIGHT_BITS - 1 downto 0);
        y_o : out std_logic_vector(OUTPUT_BITS - 1 downto 0)
    );
end nn_alu;

architecture arch of nn_alu is
    constant z1_ZERO : vec1d_t(0 to PARALLEL_INPUT - 1)(OUTPUT_BITS - 1 downto 0) := (others => (others => ('0')));
    constant z2_ZERO : std_logic_vector(OUTPUT_BITS - 1 downto 0)                 := (others => '0');

    signal z1 : vec1d_t(0 to PARALLEL_INPUT - 1)(OUTPUT_BITS - 1 downto 0) := z1_ZERO;
    signal z2 : std_logic_vector(OUTPUT_BITS - 1 downto 0)                 := z2_ZERO;
begin

    process (clk, rst)

        variable temp : unsigned(INPUT_BITS - 1 downto 0);

    begin
        if rst = '1' then
            z1 <= z1_ZERO;
            z2 <= z2_ZERO;

        elsif rising_edge(clk) then

            -- MUL
            MUL : for i in 0 to PARALLEL_INPUT - 1 loop
                --z1(i) (OUTPUT_BITS -1 downto INPUT_BITS) <= (others => '0');

                z1(i) <= std_logic_vector(unsigned(x_i(i)) * unsigned(w_i(i)));

                --z1(i) (INPUT_BITS-1 downto 0) <= x_i(i);
            end loop; -- MUL

            -- ADD
            -- # TODO This needs to be generic in one step
            y_o <= std_logic_vector(unsigned(z1(0)) + unsigned(z1(1)) + unsigned(z1(2)));
        end if;
    end process;
end architecture; -- arch