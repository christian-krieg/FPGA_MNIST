library vunit_lib;
context vunit_lib.vunit_context;
library JSON;
context JSON.json_ctx;
LIBRARY work;
use work.json_numpy.all;

entity tb_json_gens is
  generic (
    RUNNER_CFG : string;
    TB_PATH    : string;
    TB_CFG     : string;
    TB_CHANNEL_NUMBER : integer; 
  );
end entity;

architecture tb of tb_json_gens is

signal kernel : int_vec_2d_t(,2 downto 0, 2 downto 0); 


begin
  main: process

    procedure run_example(JSONContent : T_JSON) is
      -- get array of integers from JSON content
      constant img_dim : integer_vector := jsonGetIntegerArray(JSONContent, "dim");
      constant img_arr : int_vec_3d_t := jsonGetNumpy3d(JSONContent);
    begin
      -- Content extracted from the JSON
      info("JSONContent: " & lf & JSONContent.Content);

      -- Print dimension integer array, extracted by function jsonGetIntegerArray(JSON) with data from the JSON
      for i in 0 to img_dim'length-1 loop
        info("Image dim [" & integer'image(i) & "]: " & integer'image(img_dim(i)));
      end loop;
      -- Print numpy integer array, extracted by function jsonGetNumpy3d(json_numpy) with data from the JSON
      for k in 0 to img_dim(0)-1 loop 
        for j in 0 to img_dim(1)-1 loop 
          for i in 0 to img_dim(2)-1 loop
            info("Array data [" & integer'image(k) & "][" & integer'image(j) & "][" & integer'image(i) & "]: "& integer'image(img_arr(k,j,i)));
          end loop; 
        end loop;
      end loop;
    end procedure;


    variable JSONContent : T_JSON;

  begin
    test_runner_setup(runner, RUNNER_CFG);
    while test_suite loop
      info("RAW generic: " & TB_CFG);
      if run("Conv channel test") then
        JSONContent := jsonLoad(TB_CFG);
        run_example(JSONContent);
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
