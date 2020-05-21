library ieee;
use ieee.std_logic_1164.all;

package egg_box is
	constant KERNEL_SIZE                      : integer := 3*3;
  constant ACTIVATION_WIDTH                 : integer :=  8; -- Bit-Width of input activations 
  constant WEIGHT_WIDTH                     : integer :=  4; -- Bit-Width of the (multiplication) weights without signbit [NOT USED]
  constant WEIGHT_SHIFT_BIT_WIDTH           : integer :=  3; -- Bit-Width of the (multiplication) shift weights 
  constant BIAS_WIDTH                       : integer :=  9; -- Bit-Width of the (additive) weights (Anmerkung: Keine Resourcenersparnis bei weniger Bit als ACTIVATION_WIDTH-1) 
  constant KERNEL_FRACTION_SHIFT_WIDTH      : integer := 2; -- Bit-Width of the fraction shift used for quntization of the kernel output (Depends on the kernel size) 
  constant CHANNEL_FRACTION_SHIFT_WIDTH     : integer := 3; -- Bit-Width of the fraction shift used for quantization of the output channel in layer 2 (Depends on the input channel number)  
 
  type kernel_sign_array_t is array (0 to KERNEL_SIZE - 1) of std_logic_vector(0 downto 0);
  type kernel_shift_array_t is array (0 to KERNEL_SIZE - 1) of std_logic_vector(WEIGHT_SHIFT_BIT_WIDTH-1 downto 0);
  type kernel_input_array_t is array (0 to KERNEL_SIZE - 1) of std_logic_vector(ACTIVATION_WIDTH-1 downto 0);
  type kernel_weighted_X_array_t is array (0 to KERNEL_SIZE - 1) of std_logic_vector(ACTIVATION_WIDTH downto 0);

end package egg_box;

package body egg_box is 
end egg_box;


