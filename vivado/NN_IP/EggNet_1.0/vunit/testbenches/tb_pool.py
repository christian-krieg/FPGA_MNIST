# -*- coding: utf-8 -*-
"""
Created on Sun May 24 15:42:31 2020

@author: lukas
"""
import os, sys
import pathlib
from vunit import VUnit
import getpass


class Simulator:
    def __init__(self, vunit: VUnit, libname:str, root_path:pathlib.Path):
        # -- Set up Vunit --- 
        self.VU = vunit # VUNIT class 
        lib = vunit.library(libname)
        self.lib = lib
        
        # -- Set up workspace -- 
        LOCAL_ROOT = pathlib.Path(__file__).parent
        ROOT = root_path

        # -- Add testbench and all vhdl files in sim folder --
        self.lib.add_source_files(LOCAL_ROOT /"*.vhd")
        self.tb_hpool = lib.test_bench('tb_hpool')
        self.tb_hpool.set_sim_option('ghdl.sim_flags', [f'--vcd={ROOT / "tmp" / "tb_hpool.vcd"}'])
        
        self.tb_vpool = lib.test_bench('tb_vpool')
        self.tb_vpool.set_sim_option('ghdl.sim_flags', [f'--vcd={ROOT / "tmp" / "tb_vpool.vcd"}'])
        # -- Set compile options 
        self.VU.set_compile_option("ghdl.flags", ["--ieee=synopsys"])
        # TODO: Testdata generation 
        
    def generate_testdata(self):
        pass        
    
    def execute(self):
        print("Execute simulation")
        self.VU.main()
        # TODO: RUN simulation + print results 
        
#%% For direct usage 
if __name__ == "__main__":
    
    ROOT = pathlib.Path(__file__).parents[2]
    
    # Coolere lösung wäre wenn hier run.py in root mit den tb_conv_channel als argument aufgerufen wird
    #sys.path.append(ROOT)
    #import run 
    #.. 
    #..
    
    SRC_ROOT = pathlib.Path(__file__).parents[2] / 'src'
    os.makedirs(ROOT / "tmp", exist_ok=True)
    
    if getpass.getuser() == 'lukas':
        UNISIM_ROOT = "C:/msys64/mingw64/lib/ghdl/vendors/xilinx-vivado/unisim/v08"
    else:
        UNISIM_ROOT = ROOT.parents[2] / "debian" / "xilinx-vivado" / "unisim"
    
    # --- Setup VUNIT
    VU = VUnit.from_argv()
 
    # Enable location preprocessing but exclude all but check_false to make the example less bloated
    VU.enable_location_preprocessing()
    VU.enable_check_preprocessing()
    VU.add_osvvm()  # Add support for OSVVM
    VU.add_json4vhdl()
    VU.add_external_library("unisim", UNISIM_ROOT)
    
    lib = VU.add_library("EggNet", vhdl_standard="08")
    
    # -------------------------- 
    # -- Setup Libraries
    # --------------------------
    
    lib.add_source_files((SRC_ROOT / "AXI_Stream_Master" / "*.vhd"))
    lib.add_source_files((SRC_ROOT / "AXI-lite" / "*.vhd"))
    lib.add_source_files((SRC_ROOT / "bram_vhdl" / "*.vhd"))
    lib.add_source_files((SRC_ROOT / "Common" / "*.vhd"))
    # lib.add_source_files(SRC_ROOT / "ConvLayer" / "*.vhd")
    # lib.add_source_files(SRC_ROOT / "DenseLayer" / "*.vhd")
    lib.add_source_files((SRC_ROOT / "MemCtrl" / "*.vhd"))
    lib.add_source_files((SRC_ROOT / "MemCtrl_Conv_to_Dense" / "*.vhd"))
    lib.add_source_files((SRC_ROOT / "PoolingLayer" / "*.vhd"))
    lib.add_source_files((SRC_ROOT / "ReluLayer" / "*.vhd"))
    lib.add_source_files((SRC_ROOT / "ShiftRegister" / "*.vhd"))
    # lib.add_source_files(SRC_ROOT / "TopLevel" / "*.vhd")
    
    # -------------------------- 
    # -- Setup Simulator class
    # --------------------------
    Sim = Simulator(VU,"EggNet")
    Sim.execute()