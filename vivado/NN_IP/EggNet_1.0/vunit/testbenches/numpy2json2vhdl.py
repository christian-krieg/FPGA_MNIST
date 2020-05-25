"""
Numpy to json to VHDL
-------------

Provides functions for transferring 2d or 3d numpy arrays to a vhdl testbench. 
The data is transferred using the JSON interface provided by vunit. 
A JSON file contains the dimension of a numpy array and the serialized data. 
For the use in the vhdl testbench the json_numpy package is required. 
It provides jsonGetNumpy2d() and jsonGetNumpy3d() and int_vec_2d_t and 
int_vec_3d_t interger array types. 
Requirements: 
    vunit (vhdl2008 support)
    numpy
    json
    pathlib
"""

from pathlib import Path
from vunit import VUnit
from vunit.json4vhdl import read_json, encode_json
import numpy as np
import json



class NumpyEncoder(json.JSONEncoder):
    """ Special json encoder for numpy types """
    def default(self, obj):
        if isinstance(obj, (np.int_, np.intc, np.intp, np.int8,
            np.int16, np.int32, np.int64, np.uint8,
            np.uint16, np.uint32, np.uint64)):
            return int(obj)
        elif isinstance(obj, (np.float_, np.float16, np.float32, 
            np.float64)):
            return float(obj)
        elif isinstance(obj,(np.ndarray,)): #### This is the fix
            return obj.tolist()
        return json.JSONEncoder.default(self, obj)

def main():
    """
    Main Script Entry Point

    Returns
    -------
    None.

    """    
    TEST_PATH = Path(__file__).parent / "sim" / "numpy2vhdl"
    JSON_PATH = TEST_PATH / "data.json"
    
    #--- Create test array --- 
    np_array = np.array([[11,12,13],[21,22,23],[31,32,33]])
    np_array = np_array
    np_3d_array = np.append(np_array+100,np_array+200)
    np_3d_array = np.append(np_3d_array,np_array+300)
    np_3d_array = np_3d_array.reshape([3,3,3])

    #--- Setup vunit 
    VU = VUnit.from_argv()    
    LIB = VU.add_library("test")
    LIB.add_source_files(TEST_PATH / "*.vhd")
    TB = LIB.get_test_benches()[0]
    dump_json(np_3d_array,JSON_PATH)
    setup_vunit(VU,TB,TEST_PATH)
    VU.main()
    

def dump_json(array,JSON_PATH):
    """
    

    Parameters
    ----------
    array : numpy array 
        integer type numpy array with 2 or 3 dimensions.
    JSON_PATH : TYPE
        Path to json file.

    Returns
    -------
    None.

    """
    dumped = json.dumps({'dim' : list(np.shape(array)),'data' : array.ravel()}, cls=NumpyEncoder)
    with open(str(JSON_PATH), 'w+', encoding='utf-8') as f:
        f.write(dumped) 
        

def setup_vunit(VU,TB,JSON_PATH):
    """
    

    Parameters
    ----------
    VU : VUNIT class
        Public interface of vunit.
    TB : Testbench
        Testbench which uses the numpy array .
    JSON_PATH : Path
        Path to json file including file name 
    file_name : TYPE, optional
        DESCRIPTION. The default is "data.json".

    Returns
    -------
    None.

    """
    TB_CFG = read_json(JSON_PATH)
    TB_CFG["dump_debug_data"] = False
    JSON_STR = encode_json(TB_CFG)
    
    TB.get_tests("stringified*")[0].set_generic("tb_cfg", JSON_STR)
    TB.get_tests("JSON file*")[0].set_generic("tb_cfg", JSON_PATH)

