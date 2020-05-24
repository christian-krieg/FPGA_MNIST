"""
Setup a local 
"""

import os
import toml
import pathlib
import vunit
import importlib


TOML_HEADER_DOCSTRING = """
# File names are either absolute or relative to the parent folder of the
# vhdl_ls.toml file and supports glob-style patterns.
#
# Taken from: https://github.com/Bochlin/rust_hdl_vscode
#
# Another good example is: https://github.com/kraigher/rust_hdl/tree/master/example_project
#

"""


root = pathlib.Path(__file__).parent


ls_config = toml.load(root / 'vhdl_ls.toml')

vunit_root = pathlib.Path(vunit.__file__).parent
vunit_src = list(vunit_root.rglob('*.vhd')) + list(vunit_root.rglob('*.vhdl'))

ls_config['libraries']['vunit_lib']['files'] = list(map(str,vunit_src))

with open(root / 'vhdl_ls_new.toml', "w") as f:
    toml.dump(ls_config, f)   