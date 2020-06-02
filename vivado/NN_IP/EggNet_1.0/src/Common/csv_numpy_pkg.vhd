library ieee;
use ieee.std_logic_1164.all;
library vunit_lib;
context vunit_lib.vunit_context;
use STD.textio.all;

-- Based on JSON-for-VHDL: https://github.com/Paebbels/JSON-for-VHDL.git

package csv_numpy is
  type int_vec_2d_t is array (NATURAL range <>, NATURAL range <>) of integer; 
  type int_vec_3d_t is array (NATURAL range <>, NATURAL range <>, NATURAL range <>) of integer; 
  type int_vec_4d_t is array (NATURAL range <>, NATURAL range <>, NATURAL range <>, NATURAL range <>) of integer; 
  type int_vec_5d_t is array (NATURAL range <>, NATURAL range <>, NATURAL range <>, NATURAL range <>, NATURAL range <>) of integer; 

  impure function csvGetNumpy2d(filepath : string) return int_vec_2d_t;
  impure function csvGetNumpy3d(filepath : string) return int_vec_3d_t;
  impure function csvGetNumpy4d(filepath : string) return int_vec_4d_t;
  impure function csvGetNumpy5d(filepath : string) return int_vec_5d_t;
  impure function csvGetNumpyDim(filepath : string) return integer_vector;
  
  procedure  print2d(arr: int_vec_2d_t); 
  procedure  print3d(arr: int_vec_3d_t); 
  procedure  print4d(arr: int_vec_4d_t); 
  procedure  print5d(arr: int_vec_5d_t); 
  
end package csv_numpy;

package body csv_numpy is 

  ------------------------
  --  Private functions --
  ------------------------
  
  impure function getDimension(arr : integer_array_t; dims : integer) return integer_vector is 
    variable dim : integer_vector(dims-1 downto 0); 
  begin   
    for i in 0 to dims-1 loop 
      dim(i) := get(arr, i+1);
      info("Dimension: ["& integer'image(i) &"] " & integer'image(dim(i)));
    end loop;
    return dim;
  end;
  
  impure function csvGetNumpy2d_data(arr : integer_array_t; dim : integer_vector) return int_vec_2d_t is 
    variable arr_data : int_vec_2d_t(dim(0)-1 downto 0,dim(1)-1 downto 0); 
    variable index : integer := 0;
  begin   
    index := dim'length+1;
    for j in 0 to dim(0)-1 loop 
      for i in 0 to dim(1)-1 loop
        arr_data(j,i) := get(arr, index);
        index := index +1; 
      end loop; 
    end loop;
    return arr_data;
  end;

  impure function csvGetNumpy3d_data(arr : integer_array_t; dim : integer_vector) return int_vec_3d_t is 
    variable arr_data : int_vec_3d_t(dim(0)-1 downto 0,dim(1)-1 downto 0,dim(2)-1 downto 0); 
    variable index : integer := 0;
  begin   
    index := dim'length+1;
    for k in 0 to dim(0)-1 loop 
      for j in 0 to dim(1)-1 loop 
        for i in 0 to dim(2)-1 loop
          arr_data(k,j,i) := get(arr, index);
          index := index +1; 
        end loop; 
      end loop;
    end loop;
    return arr_data;
  end;
  
  impure function csvGetNumpy4d_data(arr : integer_array_t; dim : integer_vector) return int_vec_4d_t is 
    variable arr_data : int_vec_4d_t(dim(0)-1 downto 0,dim(1)-1 downto 0,dim(2)-1 downto 0,dim(3)-1 downto 0); 
    variable index : integer := 0; 
  begin   
    index := dim'length+1;
    for l in 0 to dim(0)-1 loop 
      for k in 0 to dim(1)-1 loop 
        for j in 0 to dim(2)-1 loop
          for i in 0 to dim(3)-1 loop
            arr_data(l,k,j,i) := get(arr, index);
            index := index +1; 
          end loop; 
        end loop; 
      end loop;
    end loop;
    return arr_data;
  end;
  
  impure function csvGetNumpy5d_data(arr : integer_array_t; dim : integer_vector) return int_vec_5d_t is 
    variable arr_data : int_vec_5d_t(dim(0)-1 downto 0,dim(1)-1 downto 0,dim(2)-1 downto 0,dim(3)-1 downto 0,dim(4)-1 downto 0); 
    variable index : integer := 0;
  begin   
    index := dim'length+1;
    for m in 0 to dim(0)-1 loop 
      for l in 0 to dim(1)-1 loop 
        for k in 0 to dim(2)-1 loop 
          for j in 0 to dim(3)-1 loop
            for i in 0 to dim(4)-1 loop
              arr_data(m,l,k,j,i) := get(arr, index);
              index := index +1; 
            end loop; 
          end loop; 
        end loop;
      end loop;
    end loop;
    return arr_data;
  end;
  ------------------------
  --  Public functions --
  ------------------------
  impure function csvGetNumpyDim(filepath : string) return integer_vector is
    constant arr : integer_array_t := load_csv(filepath);
  begin 
    return getDimension(arr,get(arr, 0));
  end; 
  
  impure function csvGetNumpy2d(filepath : string) return int_vec_2d_t is 
    constant arr : integer_array_t := load_csv(filepath); 
    constant dim : integer_vector := getDimension(arr,get(arr, 0));
  begin
    info("Dimensions: " & integer'image(get(arr, 0)));
    return csvGetNumpy2d_data(arr,dim);
  end;
  
  impure function csvGetNumpy3d(filepath : string) return int_vec_3d_t is 
    constant arr : integer_array_t := load_csv(filepath);
    constant dim : integer_vector := getDimension(arr,get(arr, 0));
  begin
    info("Dimensions: " & integer'image(get(arr, 0)));
    return csvGetNumpy3d_data(arr,dim);
  end;

  impure function csvGetNumpy4d(filepath : string) return int_vec_4d_t is 
    constant arr : integer_array_t := load_csv(filepath);
    constant dim : integer_vector := getDimension(arr,get(arr, 0));
  begin
    info("Dimensions: " & integer'image(get(arr, 0)));
    return csvGetNumpy4d_data(arr,dim);
  end;
  
  impure function csvGetNumpy5d(filepath : string) return int_vec_5d_t is 
    constant arr : integer_array_t := load_csv(filepath);
    constant dim : integer_vector := getDimension(arr,get(arr, 0));
  begin
    info("Dimensions: " & integer'image(get(arr, 0)));
    return csvGetNumpy5d_data(arr,dim);
  end;

  procedure  print2d(arr: int_vec_2d_t) is 
    variable k_line : line;
  begin
    for j in 0 to arr'length(1)-1 loop --height
      write(k_line, string'("|"));
      for i in 0 to arr'length(2)-1 loop --width
        write(k_line, (string'(" ") & integer'image(arr(j,i))));
      end loop; 
      write(k_line, string'(" |"));
      writeline(output,k_line);
    end loop;
  end; 

  procedure  print3d(arr: int_vec_3d_t) is 
    variable k_line : line;
  begin
    for k in 0 to arr'length(1)-1 loop --depth
      info("Depth[" & integer'image(k));
      for j in 0 to arr'length(2)-1 loop --height
        write(k_line, string'("|"));
        for i in 0 to arr'length(3)-1 loop --width
          write(k_line, (string'(" ") & integer'image(arr(k,j,i))));
        end loop; 
        write(k_line, string'(" |"));
        writeline(output,k_line);
      end loop;
    end loop;   
  end; 

  procedure  print4d(arr: int_vec_4d_t) is 
    variable k_line : line;
  begin
    for l in 0 to arr'length(1)-1 loop --batch
      for k in 0 to arr'length(2)-1 loop --depth
        info("Batch[" & integer'image(l) & "] Depth[" & integer'image(k) & "]: ");
        for j in 0 to arr'length(3)-1 loop --kernel height
          write(k_line, string'("|"));
          for i in 0 to arr'length(4)-1 loop --kernel width
            write(k_line, (string'(" ") & integer'image(arr(l,k,j,i))));
          end loop; 
          write(k_line, string'(" |"));
          writeline(output,k_line);
        end loop;     
      end loop;
    end loop;
  end; 
  
  procedure  print5d(arr: int_vec_5d_t) is 
    variable k_line : line;
  begin
    for m in 0 to arr'length(1)-1 loop --batch
      for l in 0 to arr'length(2)-1 loop --height
        for k in 0 to arr'length(3)-1 loop --widht
          info("Batch[" & integer'image(m) & "] Height[" & integer'image(l) & "] Width[" & integer'image(k) & "]: ");
          for j in 0 to arr'length(4)-1 loop --kernel height
            write(k_line, string'("|"));
            for i in 0 to arr'length(5)-1 loop --kernel width
              write(k_line, (string'(" ") & integer'image(arr(m,l,k,j,i))));
            end loop; 
            write(k_line, string'(" |"));
            writeline(output,k_line);
          end loop;
        end loop;        
      end loop;
    end loop;
  end; 
end csv_numpy;