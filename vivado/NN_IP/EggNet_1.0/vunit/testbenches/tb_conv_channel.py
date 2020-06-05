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
import numpy as np

import EggNet.VunitExtension as EggUnit

import importlib.util


class Testbench(EggUnit.Simulator):
    def __init__(self, vunit: VUnit, libname:str, root_path:pathlib.Path, testbench_name = None, vcd = False, synopsys = False):
       super().__init__(vunit, libname, root_path,pathlib.Path(__file__),testbench_name=testbench_name,vcd=vcd,synopsys=synopsys)
        
    def load_testdata(self):
        images = super()._use_rand_images(3,randseed=1)
        images_c = np.zeros(images.shape + (1,)) 
        images_c[:,:,:,0] = images
        vectors = EggUnit.get_vectors_from_image(images_c)
        kernels = EggUnit.get_Kernels(vectors)
        #test = np.arange(45,dtype=np.uint8)
        #test = test.reshape([5,3,3])
        #super().load_testdata(test,"testdata.csv") 
        super().load_testdata(kernels[:,:,:,:,:,0],"testdata.csv","TB_CSV_DATA_FILE")    
        super().load_testdata(images,"resultdata.csv","TB_CSV_RESULTS_FILE")    
    
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
    args = ['-t', pathlib.Path(__file__).stem, '--testpath',str(pathlib.Path(__file__).parent.absolute()), '--vcd']
    # -- Initialze vunit 
    runner = run_py.VU_Run(ROOT,SRC_ROOT,args)
    runner.run_test()
