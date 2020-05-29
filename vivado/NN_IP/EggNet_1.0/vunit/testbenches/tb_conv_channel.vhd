library vunit_lib;
context vunit_lib.vunit_context;
LIBRARY work;
use work.csv_numpy.all;
use STD.textio.all;

entity tb_conv_channel is
  generic (
    RUNNER_CFG : string;
    TB_PATH    : string;
    TB_CSV_FILE     : string;
    TB_BATCH_NUMBER : integer; 
    TB_IMG_HEIGHT : integer; 
    TB_IMG_WIDTH : integer; 
    TB_KERNEL_HEIGHT : integer; 
    TB_KERNEL_WIDTH : integer 
  );
end entity;

architecture tb of tb_conv_channel is

--signal image_data : jsonGetNumpy5d(TB_BATCH_NUMBER-1 downto 0, TB_IMG_HEIGHT-1 downto 0, TB_IMG_WIDTH-1 downto 0, TB_KERNEL_HEIGHT-1 downto 0, TB_KERNEL_WIDTH-1 downto 0);


begin
  main: process
    procedure run_test(filepath : string) is
      -- get array of integers from JSON content
      constant img_dim : integer_vector := csvGetNumpyDim(filepath);
      constant img_arr : int_vec_5d_t := csvGetNumpy5d(filepath);
      variable k_line : line;
    begin

      -- Print dimension integer array, extracted by function jsonGetIntegerArray(JSON) with data from the JSON
      for i in 0 to img_dim'length-1 loop
        info("Image dim [" & integer'image(i) & "]: " & integer'image(img_dim(i)));
      end loop;
      -- Print numpy integer array, extracted by function jsonGetNumpy3d(json_numpy) with data from the JSON
      info("Image");
      -- for k in 0 to img_dim(0)-1 loop --batch
        -- info("Batch[" & integer'image(k));
        -- for j in 0 to img_dim(1)-1 loop --kernel height
          -- write(k_line, string'("|"));
          -- for i in 0 to img_dim(2)-1 loop --kernel width
            -- --info(integer'image(img_arr(k,j,i)));
            -- write(k_line, (string'(" ") & integer'image(img_arr(k,j,i))));
          -- end loop; 
          -- write(k_line, string'(" |"));
          -- writeline(output,k_line);
        -- end loop;
      -- end loop;        
      for m in 0 to img_dim(0)-1 loop --batch
        for l in 0 to img_dim(1)-1 loop --height
          for k in 0 to img_dim(2)-1 loop --widht
            info("Batch[" & integer'image(m) & "] Height[" & integer'image(l) & "] Width[" & integer'image(k) & "]: ");
            for j in 0 to img_dim(3)-1 loop --kernel height
              write(k_line, string'("|"));
              for i in 0 to img_dim(4)-1 loop --kernel width
                write(k_line, (string'(" ") & integer'image(img_arr(m,l,k,j,i))));
              end loop; 
              write(k_line, string'(" |"));
              writeline(output,k_line);
            end loop;
          end loop;        
        end loop;
      end loop;
    end procedure;


  begin
    test_runner_setup(runner, RUNNER_CFG);
    while test_suite loop
      info("CSV file path: " & TB_CSV_FILE);
      if run("CSV test") then
        run_test(TB_CSV_FILE);
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
