# -*- coding: utf-8 -*-
"""
Created on Sun May 24 15:42:31 2020

@author: lukas

Testbench for Simulator plugin of run.py 

Dependencies:
    vunit
    numpy
    EggNet
    
Inherits:
    Super_Simulator
"""


import os
import pathlib
from vunit import VUnit
import random
import numpy as np

import EggNet
import EggNet.Reader
import numpy2json2vhdl as np2vhdl
import simulator


class Simulator(simulator.Super_Simulator):
    def __init__(self, vunit: VUnit, libname:str, root_path:pathlib.Path, testbench_name = None, vcd = False, synopsys = False):
       super().__init__(vunit, libname, root_path,testbench_name,vcd,synopsys)
        
    def generate_testdata(self):
        raise Exception("Test data is generated in vhdl testbench")
        pass        
    
    def execute(self):
        super().execute()
        
#%% For direct usage 
if __name__ == "__main__":
    
    # -- Import run.py 
    ROOT = pathlib.Path(__file__).parents[2]
    import importlib.util
    spec = importlib.util.spec_from_file_location("run", ROOT)
    run_sim = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(run_sim)
    
    # -- use run.py with 