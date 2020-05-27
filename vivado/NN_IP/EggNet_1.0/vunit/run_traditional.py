# -*- coding: utf-8 -*-
"""
Top Level VUNIT
===============


Created on Mon Mar 23 12:20:15 2020

@author: lukas
@author: Benjamin
"""

import importlib.util
import sys

import os
import pathlib
import vunit
from vunit import VUnit
import argparse
import importlib


# ---------------------------
# -- Setup Constants
# ---------------------------

ROOT = pathlib.Path(__file__).parent
ROOT = ROOT.absolute()
SRC_ROOT = pathlib.Path(__file__).parents[1] / 'src'
SRC_ROOT = SRC_ROOT.absolute()
print(ROOT)
print(SRC_ROOT)
if sys.platform in ["Windows", "win32"]:
    DEFAULT_UNISIM_ROOT = pathlib.WindowsPath(
        "C:/msys64/mingw64/lib/ghdl/vendors/xilinx-vivado/unisim/v08")
else:
    # DEFAULT_UNISIM_ROOT = pathlib.Path("/usr/local/lib/ghdl/vendors/xilinx-vivado/unisim/v08")
    DEFAULT_UNISIM_ROOT = pathlib.Path(
        "./lib/unisim-debian-2019_2/xilinx-vivado/unisim/v08")
    # UNISIM_ROOT_BENNI = pathlib.Path("./lib/lib/unisim-debian-2019_2/xilinx-vivado/unisim/v08")

# ---------------------------
# -- Setup Argparse
# ---------------------------

# Example Usage:
#
#   python run.py -r --testpath ./sim ./sim2 ./sim3 --unisim ./lib/unisim-debian-2019
def create_parser():
    parser = argparse.ArgumentParser(
        description="This script invokes the simulation of the Eggnet VHDL files using VUNIT and GHDL"
    )
    parser.add_argument("--compile-only", action="store_true",
                        help="Only compile the source files without running any testbenches")
    parser.add_argument("--testpath", default="./testbenches", type=str, metavar="testpath",
                        help="Specifies the path that should be scanned for testbenches")
    parser.add_argument("-t", "--testbench", default="all", nargs="+", type=str, metavar="testbench",
                        help="Specifies the used testbench. Use \'all\' to use all testbenches in testpath")
    #parser.add_argument("-r", "--recursive", default=True,
    #                    help="Enable recursive test search and execution of the provided test path")
    parser.add_argument("--unisim", default=DEFAULT_UNISIM_ROOT, type=str, metavar="unisim",
                        help="The path of the compiled unisim package")
    parser.add_argument("-g", "--gui", action="store_true",
                        help="Launch the graphical user interface (coming soon!)")
    parser.add_argument("--vcd", action="store_true", dest='vcd',
                        help="Enable vcd waveform file output")
    parser.add_argument("--synopsys", action="store_true", dest='synopsys',
                        help="Use synopsys library in ghdl")
    parser.add_argument("--unisim-src", action="store_true",
                    help="Unisim path points to source files, needs to be compiled")
    return parser

# ---------------------------
# -- Setup Workspace
# ---------------------------
def init_vunit(args):
    # --- Create a tmp dir
    os.makedirs(ROOT / "tmp", exist_ok=True)
    vunit_args = ['--output-path','./tmp']
    
    if args.compile_only:
        vunit_args.append('--compile')
        
    # --- Setup VUNIT
    VU = VUnit.from_argv(vunit_args)
    
    # Enable location preprocessing but exclude all but check_false to make the example less bloated
    VU.enable_location_preprocessing()
    VU.enable_check_preprocessing()
    VU.add_osvvm()  # Add support for OSVVM
    VU.add_json4vhdl()
    
    # -- Add the Unisim library
    if args.unisim_src == True:
        # -- If source files are used, add them manually
        lib_unisim = VU.add_library("unisim", vhdl_standard="08")
        lib_unisim.add_source_files(pathlib.Path(args.unisim) / '*.vhd')
    else:
        # -- Used if a precompiled version is available
        VU.add_external_library("unisim", args.unisim)
    
    lib = VU.add_library("EggNet", vhdl_standard="08")
    
    # --------------------------
    # -- Setup Libraries
    # --------------------------
    print(SRC_ROOT / "AXI_Stream_Master" / "*.vhd")
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
    return VU

# ----------------------------------------
# -- Search & Setup & Run Testbenches
# ----------------------------------------

def run_test(VU,args):
    # Find all testbenches in path or search for a specific testbenches
    TEST_PATH = pathlib.Path(args.testpath)
    assert TEST_PATH.is_dir(), "Testpath must be a directory"

    if args.testbench == "all":
        testbenches = sorted(TEST_PATH.rglob('tb_*.py'))
        assert len(testbenches) > 0, "No testbenches found in {}".format(
            TEST_PATH)
    else:
        testbenches = []
        for i in range(len(args.testbench)):
            testbenches.append(sorted(TEST_PATH.rglob(args.testbench[i]+ '.py'))[0])
            print('Testbench' + str(i) + ': ' + str(testbenches[i]))

        assert len(testbenches) > 0, "Testbenches {}".format(
            args.testbench) + "not found in path {}".format(args.testpath)

    for testbench in testbenches:
        # -- Some magic applied here to dynamically important the modules
        spec = importlib.util.spec_from_file_location(
            testbench.stem, testbench)
        test_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(test_module)

        # -- Add tests to VUNIT
        test = test_module.Testbench(
            VU, "EggNet", ROOT, vcd=args.vcd, synopsys=args.synopsys)
        test.load_testdata()


if __name__ == "__main__":
    parser = create_parser()
    args = parser.parse_args()
    if pathlib.Path(args.unisim).exists() == False:
        raise Exception(
            "You need to provide a path for pre-compiled `unisim` in VHDL2008 standard to compile the lib (see ghdl doc)")
    
    if args.gui == True:
        print("GUI is not ready yet, continuing in command line mode")
    

    VU = init_vunit(args)
    run_test(VU,args)
    VU.main()
