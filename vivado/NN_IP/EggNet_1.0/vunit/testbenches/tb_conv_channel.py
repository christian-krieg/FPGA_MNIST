# -*- coding: utf-8 -*-
"""
Testbench for Simulator plugin of run.py 
========================================


Created on Sun May 24 15:42:31 2020

@author: lukas

Dependencies:
    vunit
    numpy
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
        super().load_testdata()       
    
    def execute(self):
        super().execute()
        
#%% For direct usage 
if __name__ == "__main__":
    
    # -- Import run.py 
    ROOT = pathlib.Path(__file__).parents[1]
    RUN_PATH = ROOT / "run.py"
    spec = importlib.util.spec_from_file_location(RUN_PATH.stem,RUN_PATH)
    simulation = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(simulation)
    simulation.run_test([pathlib.Path(__file__)])
    
    # -- use run.py with 
