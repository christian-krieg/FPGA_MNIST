"""
Numpy to csv to VHDL
=====================

Provides functions for transferring numpy arrays to a vhdl testbench. 
The data is transferred using the csv interface provided by vunit. 
A csv file contains the shape of the array dimensions followed by the 
demensions and the data of a numpy array and the serialized data. 
For the use in the vhdl testbench the csv_numpy package is required. 
It provides csvGetNumpy2d() to csvGetNumpy5d() 
Requirements: 
    vunit (ghdl with vhdl2008 support)
    numpy
    pathlib
"""

import pathlib
from vunit import VUnit
from vunit.ui.testbench import TestBench
import numpy as np


def main():
    """
    Main Script Entry Point

    Returns
    -------
    None.

    """    
    TEST_PATH = pathlib.Path(__file__).parent / "sim" / "numpy2vhdl"
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
    dump_csv(np_3d_array,JSON_PATH)
    setup_vunit_for_csv(VU,TB,TEST_PATH)
    VU.main()
    

def dump_csv(array,CSV_PATH):
    """
    

    Parameters
    ----------
    array : numpy array 
        integer type numpy array with 2 or 3 dimensions.
    CSV_PATH : TYPE
        Path to json file.

    Returns
    -------
    None.

    """
    csv = np.array([len(array.shape)])
    csv = np.append(csv,array.shape)
    csv = np.append(csv,array.ravel())
    csv.tofile(CSV_PATH,sep=',',format='%d')

def setup_vunit_for_csv(VU:VUnit,TB:TestBench,CSV_DATA_PATH:pathlib.Path,generic_name="TB_CSV_DATA_FILE"):
    """
    

    Parameters
    ----------
    VU : VUNIT class
        Public interface of vunit.
    TB : Testbench
        Testbench which uses the numpy array.
    CSV_DATA_PATH : pathlib.Path
        Path to csv data file including file name. 
    generic_name : string, optional
        Name of CSV path generic in vhdl testbench. 
        The default is "TB_CSV_DATA_FILE"

    Returns
    -------
    None.

    """
    TB_CSV_DATA_FILE = str(CSV_DATA_PATH)
    TB.set_generic(generic_name,TB_CSV_DATA_FILE)
    

