library ieee;
use ieee.std_logic_1164.all;

library JSON;
context JSON.json_ctx;

-- Based on JSON-for-VHDL: https://github.com/Paebbels/JSON-for-VHDL.git

package json_numpy is
  type int_vec_2d_t is array (NATURAL range <>, NATURAL range <>) of integer; 
  type int_vec_3d_t is array (NATURAL range <>, NATURAL range <>, NATURAL range <>) of integer; 

  function jsonGetNumpy2d(JSONContext : T_JSON) return int_vec_2d_t;
  function jsonGetNumpy3d(JSONContext : T_JSON) return int_vec_3d_t;
  
end package json_numpy;

package body json_numpy is 

  ------------------------
  --  Private functions --
  ------------------------
  function to_natural_dec(str : STRING) return INTEGER is
		variable Result			: NATURAL;
		variable Digit			: INTEGER;
	begin
		for i in str'range loop
			Result	:= Result * 10 + (character'pos(str(i)) - character'pos('0'));
		end loop;
		return Result;
--		return INTEGER'value(str);			-- 'value(...) is not supported by Vivado Synth 2014.1
	end function;
  
  function jsonGetNumpy2d_data(JSONContext : T_JSON; Path : string; dim : integer_vector) return int_vec_2d_t is 
    variable arr_data : int_vec_2d_t(dim(0)-1 downto 0,dim(1)-1 downto 0); 
  begin   
    for j in 0 to dim(0)-1 loop 
      for i in 0 to dim(1)-1 loop
        arr_data(j,i) := to_natural_dec(jsonGetString(JSONContext, Path & "/" & to_string(i+(j*dim(1)))));
      end loop; 
    end loop;
    return arr_data;
  end function;

  function jsonGetNumpy3d_data(JSONContext : T_JSON; Path : string; dim : integer_vector) return int_vec_3d_t is 
    variable arr_data : int_vec_3d_t(dim(0)-1 downto 0,dim(1)-1 downto 0,dim(2)-1 downto 0); 
    variable index : integer := 0;
  begin   
    index := 0;
    for k in 0 to dim(0)-1 loop 
      for j in 0 to dim(1)-1 loop 
        for i in 0 to dim(2)-1 loop
          arr_data(k,j,i) := to_natural_dec(jsonGetString(JSONContext, Path & "/" & to_string(index)));
          index := index +1; 
       end loop; 
      end loop;
    end loop;
    return arr_data;
  end function;
  ------------------------
  --  Public functions --
  ------------------------
  function jsonGetNumpy2d(JSONContext : T_JSON) return int_vec_2d_t is 
    constant arr_dim : integer_vector := jsonGetIntegerArray(JSONContext, "dim"); 
  begin
    return jsonGetNumpy2d_data(JSONContext,"data",arr_dim);
  end function;
  
  function jsonGetNumpy3d(JSONContext : T_JSON) return int_vec_3d_t is 
    constant arr_dim : integer_vector := jsonGetIntegerArray(JSONContext, "dim"); 
  begin
    return jsonGetNumpy3d_data(JSONContext,"data",arr_dim);
  end function;
  
end json_numpy;