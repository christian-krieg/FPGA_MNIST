library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library vunit_lib;
context vunit_lib.vunit_context;
LIBRARY work;
use work.csv_numpy.all;
use STD.textio.all;

entity tb_conv_channel is
  generic (
    RUNNER_CFG : string;
    TB_PATH    : string;
    TB_CSV_DATA_FILE     : string;
    TB_CSV_RESULTS_FILE     : string
  );
end entity;

architecture tb of tb_conv_channel is

--signal image_data : jsonGetNumpy5d(TB_BATCH_NUMBER-1 downto 0, TB_IMG_HEIGHT-1 downto 0, TB_IMG_WIDTH-1 downto 0, TB_KERNEL_HEIGHT-1 downto 0, TB_KERNEL_WIDTH-1 downto 0);


begin
  main: process
    procedure run_test(testdata_filepath : string; resultdata_filepath : string) is
      -- get array of integers from JSON content
      constant test_img_dim : integer_vector := csvGetNumpyDim(testdata_filepath);
      constant test_img_arr : int_vec_5d_t := csvGetNumpy5d(testdata_filepath);      
      constant result_img_dim : integer_vector := csvGetNumpyDim(resultdata_filepath);
      constant result_img_arr : int_vec_3d_t := csvGetNumpy3d(resultdata_filepath);
    begin

      -- Print dimension integer array, extracted by function jsonGetIntegerArray(JSON) with data from the JSON
      for i in 0 to test_img_dim'length-1 loop
        info("Image dim [" & integer'image(i) & "]: " & integer'image(test_img_dim(i)));
      end loop;
      -- Print numpy integer array, extracted by function jsonGetNumpy3d(json_numpy) with data from the JSON
      info("Image");
      --print5d(test_img_arr);

      for i in 0 to result_img_dim'length-1 loop
        info("Image dim [" & integer'image(i) & "]: " & integer'image(result_img_dim(i)));
      end loop;
      -- Print numpy integer array, extracted by function jsonGetNumpy3d(json_numpy) with data from the JSON
      info("Image");
      print3d(result_img_arr);
      
    end procedure;


  begin
    test_runner_setup(runner, RUNNER_CFG);
    while test_suite loop
      info("Test data CSV file path: " & TB_CSV_DATA_FILE);
      info("Test results CSV file path: " & TB_CSV_RESULTS_FILE);
      if run("CSV test") then
        run_test(TB_CSV_DATA_FILE,TB_CSV_RESULTS_FILE);
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
