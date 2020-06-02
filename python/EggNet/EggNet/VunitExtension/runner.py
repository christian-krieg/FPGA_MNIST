# -*- coding: utf-8 -*-
"""
Super Class faster creation of run.py
=====================================
This class is intendend to be used as a super class in order to minimize the
effort for creating a run.py required by VUnit
Serves as the first step towards a GUI, since it defines an standard interface
for different run.py 

Created on Wed May 27 09:13:32 2020

@author: lukas
@author: Benjamin
"""

import importlib.util
import sys

import os
import pathlib
from vunit import VUnit
import argparse
import importlib


class VU_Runner():
    def __init__(self, ROOT:pathlib.Path, args:[str]=None):
        self.ROOT = ROOT
        self._default_unisim()
        self.parser = self._create_parser()
        if args == None:
            self.args = self.parser.parse_args()
        else:    
            self.args = self.parser.parse_args(args)
            
        if pathlib.Path(self.args.unisim).exists() == False:
            raise Exception(
                "You need to provide a path for pre-compiled `unisim` in \
                VHDL2008 standard to compile the lib (see ghdl doc)")
    
        if self.args.gui == True:
            print("GUI is not ready yet, continuing in command line mode")
            
        self._init_vunit()
        
    def _default_unisim(self):
        """
        Provides the default path for the unisim library

        Returns
        -------
        None.

        """
        if sys.platform in ["Windows", "win32"]:
            self.DEFAULT_UNISIM_ROOT = pathlib.WindowsPath(
                "C:/msys64/mingw64/lib/ghdl/vendors/xilinx-vivado/unisim/v08")
        else:
            # DEFAULT_UNISIM_ROOT = pathlib.Path("/usr/local/lib/ghdl/vendors/xilinx-vivado/unisim/v08")
            self.DEFAULT_UNISIM_ROOT = pathlib.Path(
                "./lib/unisim-debian-2019_2/xilinx-vivado/unisim/v08")
            # UNISIM_ROOT_BENNI = pathlib.Path("./lib/lib/unisim-debian-2019_2/xilinx-vivado/unisim/v08")
    
    def _create_parser(self):
        """
        ---------------------------
        -- Setup Argparse
        ---------------------------        
        --compile-only : Only compile the source files without running any testbenches
        --testpath : Specifies the path that should be scanned for testbenches
        --testbench : Specifies the used testbench. Use \'all\' to use all testbenches in testpath
        --unisim : The path of the compiled unisim package
        --gui : Launch the graphical user interface (coming soon!)
        --vcd : Enable vcd waveform file output
        --synopsys : Use synopsys library in ghdl
        --unisim-src : Unisim path points to source files, needs to be compiled
        --version : Returns VUnit version 
        
        Example Usage:
            python run.py -r --testpath ./sim ./sim2 ./sim3 --unisim ./lib/unisim-debian-2019
    
        Returns
        -------
        parser : argparse.ArgumentParser
            Arguments.
    
        """
        parser = argparse.ArgumentParser(
            description="This script invokes the simulation of the Eggnet VHDL files using VUNIT and GHDL"
        )
        parser.add_argument("--testpath", default="./testbenches", type=str, metavar="testpath",
                            help="Specifies the path that should be scanned for testbenches")
        parser.add_argument("-t", "--testbench", default="all", nargs="+", type=str, metavar="testbench",
                            help="Specifies the used testbench. Use \'all\' to use all testbenches in testpath")
        #parser.add_argument("-r", "--recursive", default=True,
        #                    help="Enable recursive test search and execution of the provided test path")
        parser.add_argument("--unisim", default=self.DEFAULT_UNISIM_ROOT, type=str, metavar="unisim",
                            help="The path of the compiled unisim package")
        parser.add_argument("-g", "--gui", action="store_true",
                            help="Launch the graphical user interface (coming soon!)")
        parser.add_argument("--vcd", action="store_true", dest='vcd',
                            help="Enable vcd waveform file output")
        parser.add_argument("--synopsys", action="store_true", dest='synopsys',
                            help="Use synopsys library in ghdl")
        parser.add_argument("--unisim-src", action="store_true",
                        help="Unisim path points to source files, needs to be compiled")
                        
        # Arguments used in vunit                 
        parser.add_argument("--version", action="store_true",
                        help="Returns VUnit version")          
        parser.add_argument("-f", "--files", action="store_true",
                                help="Returns all files registered in vunit")    
        parser.add_argument("-l", "--list", action="store_true",
                                        help="Only list all files in compile order") 
        parser.add_argument("-m", "--minimal", action="store_true",
                                        help="Only compile files required for the (filtered) test benches")                                         
        parser.add_argument("--compile", action="store_true",
                            help="Only compile project without running tests")                                
        parser.add_argument("--elaborate", action="store_true",
                            help="Only elaborate test benches without running")                                 
        return parser

# ---------------------------
# -- Setup Workspace
# ---------------------------
    def _init_vunit(self):
        """
        Initializes VUnit dependend of given arguments. 
        The Setup of the library have to be added in child class using: 
            lib.add_source_files(PATH_TO_SOURCE)
    
        Returns
        -------
        VU : TYPE
            DESCRIPTION.
    
        """
        # --- Return only Version number of VUnit
        if self.args.version == True:
            VU = VUnit.from_argv(['--version'])
            return 
        # --- Create a tmp dir
        os.makedirs(self.ROOT / "tmp", exist_ok=True)
        vunit_args = ['--output-path','./tmp','--verbose']
        
        if self.args.compile:
            vunit_args.append('--compile')        
        if self.args.elaborate:
            vunit_args.append('--elaborate')
        if self.args.files:
            vunit_args.append('--files')         
        if self.args.list:
            vunit_args.append('--list')        
        if self.args.list:
            vunit_args.append('--minimal')    
        # --- Setup VUNIT
        self.VU = VUnit.from_argv(vunit_args)
        
        # Enable location preprocessing but exclude all but check_false to make the example less bloated
        self.VU.enable_location_preprocessing()
        self.VU.enable_check_preprocessing()
        self.VU.add_osvvm()  # Add support for OSVVM
        self.VU.add_json4vhdl()
        
        # -- Add the Unisim library
        if self.args.unisim_src == True:
            # -- If source files are used, add them manually
            lib_unisim = self.VU.add_library("unisim", vhdl_standard="08")
            lib_unisim.add_source_files(pathlib.Path(self.args.unisim) / '*.vhd')
        else:
            # -- Used if a precompiled version is available
            self.VU.add_external_library("unisim", self.args.unisim)
        
        self.lib = self.VU.add_library("EggNet", vhdl_standard="08")
        

    def run_test(self):
        """
        ----------------------------------------
        -- Search & Setup & Run Testbenches
        ----------------------------------------        
        Searches for all specified testbenches in testpath, loads the testbenches,
        and the testdata and runs VUnit to compile the files and execute the 
        simulation. 

        Returns
        -------
        None.

        """
        TEST_PATH = pathlib.Path(self.args.testpath)
        assert TEST_PATH.is_dir(), "Testpath must be a directory"
    
        if self.args.testbench == "all":
            testbenches = sorted(TEST_PATH.rglob('tb_*.py'))
            assert len(testbenches) > 0, "No testbenches found in {}".format(
                TEST_PATH)
        else:
            testbenches = []
            for i in range(len(self.args.testbench)):
                testbenches.append(sorted(TEST_PATH.rglob(self.args.testbench[i]+ '.py'))[0])
                print('Testbench' + str(i) + ': ' + str(testbenches[i]))
    
            assert len(testbenches) > 0, "Testbenches {}".format(
                self.args.testbench) + "not found in path {}".format(self.args.testpath)
    
        for testbench in testbenches:
            # -- Some magic applied here to dynamically important the modules
            spec = importlib.util.spec_from_file_location(
                testbench.stem, testbench)
            test_module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(test_module)
    
            # -- Add tests to VUNIT
            test = test_module.Testbench(
                self.VU, "EggNet", self.ROOT, vcd=self.args.vcd, synopsys=self.args.synopsys)
            test.load_testdata()
          
        self.VU.main()

    
