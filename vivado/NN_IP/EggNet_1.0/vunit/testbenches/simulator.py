# -*- coding: utf-8 -*-
"""
Super class for Simulator plugin of testbenches 
===============================================


Created on Mon May 25 11:24:45 2020

@author: lukas


Dependencies:
    vunit
    numpy
    EggNet
"""


import os
import pathlib
from vunit import VUnit
import random
import numpy as np

import EggNet
import EggNet.Reader
import numpy2json2vhdl as np2vhdl


class Simulator:
    def __init__(self, vunit: VUnit, libname:str, root_path:pathlib.Path, child:pathlib.Path, testbench_name = None, vcd = False, synopsys = False):
        # -- Set up Vunit --
        self.VU = vunit; # VUNIT class 
        self.lib = vunit.library(libname)
        
        # -- Set up workspace -- 
        self.LOCAL_ROOT = child.parent
        self.ROOT = root_path
        os.makedirs(self.ROOT / "tmp", exist_ok=True)

        if testbench_name == None:
            testbench_name = child.stem
        print("---------------------------------------------------------------")    
        print("VHDL Testbench: " + testbench_name + ".vhd")
        print("---------------------------------------------------------------")
        # -- Add vhdl testbench --
        self.lib.add_source_files(self.LOCAL_ROOT / (testbench_name + ".vhd"))
        self.TB = self.lib.test_bench(testbench_name) # 
        
        # -- Set compile options --
        if vcd == True:
            self.TB.set_sim_option('ghdl.sim_flags', [f'--vcd={self.ROOT / "tmp" / (testbench_name + ".vcd")}'])
        
        if synopsys == True:    
            self.VU.set_compile_option("ghdl.flags", ["--ieee=synopsys"])
        
        
    def load_testdata(self,np_array = None,MNIST_PATH:pathlib.Path = pathlib.Path(__file__).parents[5] / "data" / "MNIST", randseed = None):
        # if no spezial numpy array is defined use random test image
        if np_array == None:
            mnist = EggNet.Reader.MNIST(folder_path=str(MNIST_PATH))
            test_images = mnist.test_images()
            if randseed != None: # Use seeds for repeatability 
                random.seed(randseed)
            # Use random test image 
            np_array = test_images[random.randint(0, np.shape(test_images)[0]-1)]
            
        np2vhdl.dump_json(np_array, self.Root / "tmp")
        np2vhdl.setup_vunit(self.VU,self.TB, self.ROOT / "tmp")
            
    
    def execute(self):
        print("Execute simulation")
        self.VU.main()
        # TODO: RUN simulation + print results 
        
