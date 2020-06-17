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
from EggNet.Layer import Conv2d_shift_Layer
from EggNet.Generator import Egg_Generator

import importlib.util


class Testbench(EggUnit.Simulator):
    def __init__(self, vunit: VUnit, libname:str, root_path:pathlib.Path, testbench_name = None, vcd = False, synopsys = False):
        hyper_par_path = root_path.parents[3] / "EggNet.json"
        self.param_path = root_path.parents[3] / 'net' / 'final_weights' / 'float'
        self.generator = Egg_Generator(hyper_par_path)
        self.generator.generate_mif(self.param_path,root_path.parent / 'mif')
        
        super().__init__(vunit, libname, root_path,pathlib.Path(__file__),testbench_name=testbench_name,vcd=vcd,synopsys=synopsys,ghdl_stack_size=512)
        mif_path = str(root_path.resolve().parent / 'mif')
        self.TB.set_generic('MIF_PATH',mif_path)
        
    def load_testdata(self):
        #images = super()._use_rand_images(6,randseed=1)
        images = images = np.uint8(np.random.normal(0, 0.9, size=(6,28,28))*255)
        images_c = np.zeros(images.shape + (1,)) 
        images_c[:,:,:,0] = images
        vectors = EggUnit.get_vectors_from_image(images_c)
        #kernels = EggUnit.get_Kernels(vectors)
        results = self._gen_Result_data(images_c)
        super().load_testdata(vectors,"testdata.csv","TB_CSV_DATA_FILE")    
        super().load_testdata(results,"resultdata.csv","TB_CSV_RESULTS_FILE")   
        
    def _gen_Result_data(self, images):
        conv_layer = Conv2d_shift_Layer(1,16,1,self.param_path, self.generator.exponents["Input Exponent"],
                                        self.generator.exponents["Layer 1"]["Kernel output exponent"],
                                        self.generator.exponents["Layer 1"]["Layer output exponent"])
        result = conv_layer(images.astype(np.uint8))
        return result
    
   
    def execute(self):
        super().execute()
        
#%% For direct usage 
if __name__ == "__main__":
    
    # -- Import run.py 
    ROOT = pathlib.Path(__file__).resolve().parents[1]
    print(ROOT)
    RUN_PATH = ROOT / "run.py"
    print(RUN_PATH)
    SRC_ROOT = ROOT.parent / 'src'
    print(SRC_ROOT)
    spec = importlib.util.spec_from_file_location(RUN_PATH.stem,RUN_PATH)
    run_py = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(run_py)
    
    # -- Setup arguments 
    args = ['-t', pathlib.Path(__file__).stem, '--testpath',str(pathlib.Path(__file__).parent.resolve()), '--vcd', '--gtkwave']
    # -- Initialze vunit 
    runner = run_py.VU_Run(ROOT,SRC_ROOT,args)
    runner.run_test()
