library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

package clogb2_Pkg is

	function clogb2 (bit_depth : integer) return integer;

end clogb2_Pkg;

package body clogb2_Pkg is 

	function clogb2 (bit_depth : integer) return integer is                  
		variable depth  : integer := bit_depth;                               
		variable count  : integer := 1;                                       
	begin                                                                   
		 for clogb2 in 1 to bit_depth loop  -- Works for up to 32 bit integers
	     if (bit_depth <= 2) then                                           
	       count := 1;                                                      
	     else                                                               
	       if(depth <= 1) then                                              
		       count := count;                                                
		     else                                                             
		       depth := depth / 2;                                            
	         count := count + 1;                                            
		     end if;                                                          
		   end if;                                                            
	  end loop;                                                             
	  return(count);        	                                              
	end; 

end clogb2_Pkg;
