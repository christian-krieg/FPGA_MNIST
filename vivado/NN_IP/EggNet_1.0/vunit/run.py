# -*- coding: utf-8 -*-
"""
Top Level VUNIT
===============


Created on Mon Mar 23 12:20:15 2020

@author: lukas
@author: Benjamin
"""
import sys

import os
import pathlib
import vunit
from vunit import VUnit
import argparse
import importlib
import getpass


# ---------------------------
# -- Setup Constants
# ---------------------------

ROOT = pathlib.Path(__file__).parent
SRC_ROOT = pathlib.Path(__file__).parent.parent / 'src'




if sys.platform == "Windows" or "win32":
    DEFAULT_UNISIM_ROOT = pathlib.WindowsPath("C:/msys64/mingw64/lib/ghdl/vendors/xilinx-vivado/unisim/v08")
else:
    # DEFAULT_UNISIM_ROOT = pathlib.Path("/usr/local/lib/ghdl/vendors/xilinx-vivado/unisim/v08")
    DEFAULT_UNISIM_ROOT = pathlib.Path("./lib/unisim-debian-2019_2/xilinx-vivado/unisim/v08")
    # UNISIM_ROOT_BENNI = pathlib.Path("./lib/lib/unisim-debian-2019_2/xilinx-vivado/unisim/v08")

# ---------------------------
# -- Setup Argparse
# ---------------------------

# Example Usage:
# 
#   python run.py -r --testpath ./sim ./sim2 ./sim3 --unisim ./lib/unisim-debian-2019
parser = argparse.ArgumentParser(
    description="This script invokes the build of the Eggnet VHDL files using VUNIT and GHDL"
)
parser.add_argument("--testpath", default="./testbenches", nargs="+", type=str, metavar="testpath", 
                    help="Specify the path that should be scanned for testbenches")
parser.add_argument("-t", "--testbench", default="all", nargs="+" , type=str, metavar="testbench",
                    help="Speify the used testbench. Use \'all\' to use all testbenches in testpath")
parser.add_argument("-r", "--recursive", default=True, 
                    help="Enable recursive test search and execution of the provided test path")
parser.add_argument("--unisim", default=DEFAULT_UNISIM_ROOT, type=str, metavar="unisim_path", 
                    help="The path of the compiled unisim package")
parser.add_argument("-g", "--gui", action="store_true",
                    help="Launch the graphical user interface (coming soon!)")
parser.add_argument("--vcd", action="store_true", dest='vcd',
                    help="Enable vcd waveform file output")
parser.add_argument("--synopsys", action="store_true",dest='synopsys',
                    help="Use synopsys library in ghdl")
args = parser.parse_args()

if pathlib.Path(args.unisim).exists() == False:
    #raise Exception("You need to provide a path for pre-compiled `unisim` in VHDL2008 standard to compile the lib (see ghdl doc)")
    args.unisim = DEFAULT_UNISIM_ROOT

if args.gui == True:
    print("GUI is not ready yet, continuing in command line mode")

# ---------------------------
# -- Setup Workspace
# ---------------------------

# --- Create a tmp dir
os.makedirs(ROOT / "tmp", exist_ok=True)

# --- Setup VUNIT
VU = VUnit.from_argv()

# Enable location preprocessing but exclude all but check_false to make the example less bloated
VU.enable_location_preprocessing()
VU.enable_check_preprocessing()
VU.add_osvvm()  # Add support for OSVVM
VU.add_json4vhdl()
VU.add_external_library("unisim", args.unisim)
lib = VU.add_library("EggNet", vhdl_standard="08")

# -------------------------- 
# -- Setup Libraries
# --------------------------

lib.add_source_files(SRC_ROOT / "AXI_Stream_Master" / "*.vhd")
lib.add_source_files(SRC_ROOT / "AXI-lite" / "*.vhd")
lib.add_source_files(SRC_ROOT / "bram_vhdl" / "*.vhd")
lib.add_source_files(SRC_ROOT / "Common" / "*.vhd")
# lib.add_source_files(SRC_ROOT / "ConvLayer" / "*.vhd")
# lib.add_source_files(SRC_ROOT / "DenseLayer" / "*.vhd")
lib.add_source_files(SRC_ROOT / "MemCtrl" / "*.vhd")
lib.add_source_files(SRC_ROOT / "MemCtrl_Conv_to_Dense" / "*.vhd")
lib.add_source_files(SRC_ROOT / "PoolingLayer" / "*.vhd")
lib.add_source_files(SRC_ROOT / "ReluLayer" / "*.vhd")
lib.add_source_files(SRC_ROOT / "ShiftRegister" / "*.vhd")
# lib.add_source_files(SRC_ROOT / "TopLevel" / "*.vhd")


# -------------------------- 
# -- Search for Testbenches
# --------------------------

# Find all testbenches ins path or search for a specific testbench
if __name__ == "__main__":
    TEST_PATH = pathlib.Path(args.testpath)
    assert TEST_PATH.is_dir(), "Testpath must be a directory"
    if args.testbench == "all":
        testbenches = sorted(TEST_PATH.rglob('tb_*.py'))
        assert len(testbenches)>0,"No testbenches found in {}".format(TEST_PATH)
    else:    
        testbenches = sorted(TEST_PATH.rglob(args.testbench))
        assert len(testbenches)>0,"Testbenches {}".format(args.testbench) + "not found in path {}".format(args.testpath)
        
import importlib.util

# -------------------------- 
# -- Setup Testbenches
# --------------------------
def run_test(tests):
    for testbench in tests:
        spec = importlib.util.spec_from_file_location(testbench.stem,testbench)
        test_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(test_module)
        test = test_module.Testbench(VU,"EggNet",ROOT,vcd=args.vcd,synopsys=args.synopsys)
        test.load_testdata()
        test.execute()



if __name__ == "__main__":
    run_test(testbenches)

