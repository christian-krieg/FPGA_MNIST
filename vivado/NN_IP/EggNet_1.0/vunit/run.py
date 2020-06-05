# -*- coding: utf-8 -*-
"""
Top Level VUNIT
===============


Created on Mon Mar 23 12:20:15 2020

@author: lukas
@author: Benjamin
"""

import pathlib
import EggNet.VunitExtension as EggUnit


class VU_Run(EggUnit.VU_Runner):
    def __init__(self, ROOT:pathlib.Path,SRC_ROOT:pathlib.Path, args:[str]=None):
        self.SRC_ROOT = SRC_ROOT
        super().__init__(ROOT,args)
        
    def _init_vunit(self):
        super()._init_vunit()
        # -------------------------------
        # -- Possible future feaature 
        # -- Read source paths from
        # -- a Json file
        #--------------------------------
        
        self.lib.add_source_files(self.SRC_ROOT / "AXI_Stream_Master" / "*.vhd")
        self.lib.add_source_files(self.SRC_ROOT / "AXI-lite" / "*.vhd")
        self.lib.add_source_files(self.SRC_ROOT / "bram_vhdl" / "*.vhd")
        self.lib.add_source_files(self.SRC_ROOT / "Common" / "*.vhd")
        self.lib.add_source_files(self.SRC_ROOT / "Conv2d_log2" / "*.vhd")
        self.lib.add_source_files(self.SRC_ROOT / "3x3_Kernel_log2" / "*.vhd")
        # self.lib.add_source_files(self.SRC_ROOT / "DenseLayer" / "*.vhd")
        #self.lib.add_source_files(self.SRC_ROOT / "MemCtrl" / "*.vhd")
        #self.lib.add_source_files(self.SRC_ROOT / "MemCtrl_Conv_to_Dense" / "*.vhd")
        self.lib.add_source_files(self.SRC_ROOT / "PoolingLayer" / "*.vhd")
        self.lib.add_source_files(self.SRC_ROOT / "ReluLayer" / "*.vhd")
        #self.lib.add_source_files(self.SRC_ROOT / "ShiftRegister" / "*.vhd")
        # self.lib.add_source_files(self.SRC_ROOT / "TopLevel" / "*.vhd")
        return self.VU       
    def run_test(self):
        super().run_test()
        

if __name__ == "__main__":
    # ---------------------------
    # -- Setup Constants
    # ---------------------------
    ROOT = pathlib.Path(__file__).parent
    ROOT = ROOT.resolve()
    SRC_ROOT = ROOT.parent / 'src'
    SRC_ROOT = SRC_ROOT.resolve()
    
    # ---------------------------
    # -- Setup VU_Run and start simulation
    # ---------------------------    
    run = VU_Run(ROOT,SRC_ROOT)
    run.run_test()
