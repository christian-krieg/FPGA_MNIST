library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use ieee.math_real.ceil;
use IEEE.math_real.log2;

-- A Package
package nnpkg is
    
    type vec1d_t is array (natural range <>) of std_logic_vector;
    type vec2d_t is array (natural range <>, natural range <>) of std_logic_vector;

    -- LOG2 for natural numbers
    function nlog2 (x : natural) return natural;


    -- function shift_mul (x : vec2d_t, w : vec2d_t, sgn : std_logic) return natural;

    end nnpkg;

    package body nnpkg is

        function nlog2 (x : natural) return natural is
        begin
            return natural(ceil(log2(real(x))));
        end function;

    end nnpkg;