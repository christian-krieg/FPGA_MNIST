# -*- coding: utf-8 -*-
"""
Top Level VUNIT
===============


Created on Mon Mar 23 12:20:15 2020

@author: lukas
@author: Benjamin
"""

import pathlib
from vunit import VUnit



# ---------------------------
# -- Setup Constants
# ---------------------------
ROOT = pathlib.Path(__file__).parent

# ---------------------------
# -- Setup VU_Run and start simulation
# ---------------------------    
VU = VUnit.from_argv()
lib = VU.add_library(library_name="EggNet",vhdl_standard="08")
lib.add_source_files(ROOT / "*.vhd")


if __name__ == "__main__":
    VU.main()