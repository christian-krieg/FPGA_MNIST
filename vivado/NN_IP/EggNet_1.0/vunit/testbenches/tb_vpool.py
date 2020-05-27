# -*- coding: utf-8 -*-
"""
Testbench for vertical pooling module
========================================


Created on Sun May 24 15:42:31 2020

@author: lukas

Dependencies:
    vunit
    EggNet
    
Inherits:
    Super_Simulator
"""

import pathlib
from vunit import VUnit

import EggNet.VunitExtension as EggUnit

import importlib.util


class Testbench(EggUnit.Simulator):
    def __init__(self, vunit: VUnit, libname:str, root_path:pathlib.Path, testbench_name = None, vcd = False, synopsys = False):
       super().__init__(vunit, libname, root_path,pathlib.Path(__file__),testbench_name=testbench_name,vcd=vcd,synopsys=synopsys)
        
    def load_testdata(self):
        print(pathlib.Path(__file__).name  + " INFO: Test data is generated in vhdl testbench")
        pass        
    
    def execute(self):
        super().execute()
        
#%% For direct usage 
if __name__ == "__main__":
    
    # -- Import run.py 
    ROOT = pathlib.Path(__file__).parents[1]
    RUN_PATH = ROOT / "run.py"
    SRC_ROOT = ROOT.parent / 'src'
    spec = importlib.util.spec_from_file_location(RUN_PATH.stem,RUN_PATH)
    run_py = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(run_py)
    
    # -- Setup arguments 
    args = ['-t', pathlib.Path(__file__).stem, '--testpath',str(pathlib.Path(__file__).parent.absolute())]
    # -- Initialze vunit 
    runner = run_py.VU_Run(ROOT,SRC_ROOT,args)
    runner.run_test()
    
