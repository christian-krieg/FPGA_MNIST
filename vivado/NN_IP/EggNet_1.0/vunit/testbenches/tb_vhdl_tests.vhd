library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use STD.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;

entity tb_vhdl_tests is
  generic (
    RUNNER_CFG : string;
    TB_PATH    : string
  );
end entity;

architecture tb of tb_vhdl_tests is

  

begin

  main: process
    
  
    procedure run_test(shift_val: integer) is
      constant wert : signed(7 downto 0) := to_signed(shift_val,8);
      variable result : signed(7 downto 0) := to_signed(0,8);
    begin
      info("Using: " & integer'image(to_integer(wert)));
      result := (SHIFT_RIGHT(wert, 1));
      info(integer'image(to_integer(wert)) & " shift by l: " & integer'image(to_integer(result)));
      result := (SHIFT_RIGHT(wert, 2));
      info(integer'image(to_integer(wert)) & " shift by 2: " & integer'image(to_integer(result)));
      result := (SHIFT_RIGHT(wert, 3));
      info(integer'image(to_integer(wert)) & " shift by 3: " & integer'image(to_integer(result)));      
      result := (SHIFT_RIGHT(wert, 4));
      info(integer'image(to_integer(wert)) & " shift by 4: " & integer'image(to_integer(result)));            
    end procedure;


  begin
    test_runner_setup(runner, RUNNER_CFG);
    run_test(-5);
    test_runner_cleanup(runner);
    wait;
  end process;
  

 
end architecture;
