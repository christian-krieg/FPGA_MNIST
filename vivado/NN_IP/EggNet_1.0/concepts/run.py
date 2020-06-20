# -*- coding: utf-8 -*-
"""
Top Level VUNIT
===============


Created on Mon Mar 23 12:20:15 2020

@author: lukas
@author: Benjamin
"""

import pathlib
from vunit import VUnit



# ---------------------------
# -- Setup Constants
# ---------------------------
ROOT = pathlib.Path(__file__).parent

# ---------------------------
# -- Setup VU_Run and start simulation
# ---------------------------    
VU = VUnit.from_argv()
lib = VU.add_library(library_name="EggNet",vhdl_standard="08")
lib.add_source_files(ROOT / "*.vhd")



tb_nn_alu = lib.test_bench('tb_nn_alu')
tb_nn_alu.set_sim_option('ghdl.sim_flags', [f'--vcd={ROOT / "tb_nn_alu.vcd"}'])

tb_nn_conv_kernel = lib.test_bench('tb_nn_conv_kernel')
tb_nn_conv_kernel.set_sim_option('ghdl.sim_flags', [
    f'--vcd={ROOT / "tb_nn_conv_kernel.vcd"}',
    f'--read-wave-opt={ROOT/"tb_nn_conv_kernel_vcd_conf.txt"}'])



if __name__ == "__main__":
    VU.main()