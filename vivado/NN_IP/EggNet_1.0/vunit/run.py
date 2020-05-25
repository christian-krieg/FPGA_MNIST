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
SRC_ROOT = pathlib.Path(__file__).parent / 'src'
SIM_ROOT = pathlib.Path(__file__).parent / 'sim'




if sys.platform == "Windows":
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
parser.add_argument("--testpath", default="./sim", nargs="+", type=str, metavar="testpath", 
                    help="Specify the path that should be scanned for tests")
parser.add_argument("-r", "--recursive", default=True, 
                    help="Enable recursive test search and execution of the provided test path")
parser.add_argument("--unisim", default=DEFAULT_UNISIM_ROOT, type=str, metavar="unisim_path", 
                    help="The path of the compiled unisim package")
parser.add_argument("-g", "--gui", action="store_true",
                    help="Launch the graphical user interface")
args = parser.parse_args()

if pathlib.Path(args.unisim).exists() == False:
    raise Exception("You need to provide an path for `unisim` in VHDL2008 standard to compile the lib")

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
# -- Setup Testbenches
# --------------------------

# Find all Testbench.py files
TEST_PATH = pathlib.Path(args.testpath)
assert(TEST_PATH.is_dir(), "Testpath must be a directory")

import importlib
import importlib.util

testbench_paths = SIM_ROOT.rglob('testbench.py')
for bench_path in testbench_paths:
    print(bench_path)
    _bench_spec = importlib.util.spec_from_file_location(name="testbench.py",location=bench_path)
    _bench_module = importlib.util.module_from_spec(spec=_bench_spec)
    _bench_spec.loader.exec_module(_bench_module)

    # Append the files and tests to the VU object
    Simulator = _bench_module.Simulator(vunit=VU, libname="EggNet",root_path=ROOT)


# -- Setup Generics
# VU.set_generic("DATA_WIDTH", 3)
#lib.add_source_files(SIM_ROOT / "PoolingLayer" / "*.vhd")

#tb_hpool = lib.test_bench('tb_hpool')
#tb_hpool.set_sim_option('ghdl.sim_flags', [f'--vcd={ROOT / "tmp" / "tb_hpool.vcd"}'])

#tb_vpool = lib.test_bench('tb_vpool')
#tb_vpool.set_sim_option('ghdl.sim_flags', [f'--vcd={ROOT / "tmp" / "tb_vpool.vcd"}'])

# This create a GHDL BUG -> not sure why
# lib.add_source_files(SIM_ROOT / "ReluLayer" / "*.vhd")
# tb_relu = lib.test_bench('tb_relu')
# tb_relu.set_sim_option('ghdl.sim_flags', [f'--vcd={ROOT / "tmp" / "tb_relu.vcd"}'])

#tb_vpool.set_sim_option('ghdl.elab_flags', [f'--vcd="{ROOT / "tmp" / "tb_vpool.vcd"}"'])

# -------------------------- 
# -- Setup Compile Options
# --------------------------

VU.set_compile_option("ghdl.flags", ["--ieee=synopsys"])
# for ghdl wavefrom use ["--wave=output.ghw"]
# VU.set_sim_option("ghdl.sim_flags", ["--vcd=output.vcd"], allow_empty=True)
# VU.set_sim_option("ghdl.elab_run", ["--vcd=output.vcd", "-frelaxed", "-frelaxed-rules"], allow_empty=True)
# wave = gtkw.GTKWSave('output.vcd') # Not working yet



if __name__ == "__main__":
    VU.main()

