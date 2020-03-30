# -*- coding: utf-8 -*-
# %% public imports
import os
import shutil
import numpy as np
import subprocess
import platform
import matplotlib.pyplot as plt
from sys import exit

# %% import custom modules
import vhdl_testbench as tb

# %% parameter
KEEP_TEMPORARY_FILES = True
IMG_WIDTH = 28
IMG_HIGTH = 28
KERNEL_SIZE = 3
BLOCK_SIZE = IMG_WIDTH * IMG_HIGTH
NUMBER_OF_TEST_BLOCKS = 3
CI_L1 = 1
CO_L1 = 16
CI_L2 = 16
CO_L2 = 24
NI_DL1 = 1176
NO_DL1 = 32
NI_DL2 = 32
NO_DL2 = 10 

def main():
    # %% create tmp folder, delete folder if not tmp exists and create new one
    if os.path.isdir('tmp'):
        shutil.rmtree('tmp')

    try:
        os.mkdir('tmp')
    except:
        print("Error creating tmp folder!")

    # %% create test data file
    image_data = np.uint8(np.random.normal(0, 0.3, size=(NUMBER_OF_TEST_BLOCKS, BLOCK_SIZE, CI_L1)) * 256)
    tb.write_features_to_file(image_data, layernumber=1)
    # image_data = tb.gen_testdata(BLOCK_SIZE,NUMBER_OF_TEST_BLOCKS)

    # %% generate test vectors layer 1
    test_vectors_l1 = tb.get_vectors_from_data(image_data, IMG_WIDTH, IMG_HIGTH)

    # %% generate test kernels layer 1
    test_kernels_l1 = tb.get_Kernels(test_vectors_l1, IMG_WIDTH)
    # %% calculate Layer output as new memory controller input
    weights_L1 = np.int8(np.random.normal(0, 0.3, size=(CO_L1, CI_L1, KERNEL_SIZE, KERNEL_SIZE)) * 128)
    msb = np.ones(CO_L1, dtype=np.int32) * 15
    features_l2 = tb.conv_2d(test_kernels_l1, weights_L1, msb)

    tb.write_features_to_file(features_l2, layernumber=2)
    # %% generate test vectors layer 2
    test_vectors_l2 = tb.get_vectors_from_data(features_l2, IMG_WIDTH, IMG_HIGTH)

    # %% generate test kernels layer 2
    test_kernels_l2 = tb.get_Kernels(test_vectors_l2, IMG_WIDTH)

    # %% run ghdl
    # Saving console ouput in log file is not working on windows

    filenames = ["tb_toplevel.vhd", 
                 "../../src/bram_vhdl/bram.vhd", 
                 "../../src/MemCtrl/MemCtrl.vhd",
                 "../../src/MemCtrl/Shiftregister_3x3.vhd", 
                 "../../src/Fifo_vhdl/fifo_dist_ram.vhd",
                 "../../src/MemCtrl/MemCtrl_AXIS.vhd",
                 "../../src/clogb2/clogb2_Pkg.vhd",
                 "../../src/DenseLayer/serializer.vhd",
                 "../../src/DenseLayer/denseLayerPkg.vhd",
                 "../../src/DenseLayer/romModule.vhd",
                 "../../src/DenseLayer/accumulator.vhd",
                 "../../src/DenseLayer/multiplier.vhd",
                 "../../src/DenseLayer/vectorMultiplier.vhd",
                 "../../src/DenseLayer/dense_layer.vhd",
                 "../../src/DenseLayer/NN.vhd",
                 "../../src/Pooling/MaxPooling.vhd",
                 "../../src/Conv_Channel/kernel_pkg.vhd",
                 "../../src/Conv_Channel/3x3_kernel.vhd",
                 "../../src/Conv_Channel/convchannel0.vhd",
                 "../../src/Conv_Channel/convchannel1.vhd",
                 "../../src/Conv_Channel/convchannel2.vhd",
                 "../../src/Conv_Channel/convchannel3.vhd",
                 "../../src/Conv_Channel/convchannel4.vhd",
                 "../../src/Conv_Channel/convchannel5.vhd",
                 "../../src/Conv_Channel/convchannel6.vhd",
                 "../../src/Conv_Channel/convchannel7.vhd",
                 "../../src/Conv_Channel/convchannel8.vhd",
                 "../../src/Conv_Channel/convchannel9.vhd",
                 "../../src/Conv_Channel/convchannel10.vhd",
                 "../../src/Conv_Channel/convchannel11.vhd",
                 "../../src/Conv_Channel/convchannel12.vhd",
                 "../../src/Conv_Channel/convchannel13.vhd",
                 "../../src/Conv_Channel/convchannel14.vhd",
                 "../../src/Conv_Channel/convchannel15.vhd",
                 "../../src/Conv_Channel/convchannel16.vhd",
                 "../../src/Conv_Channel/convchannel17.vhd",
                 "../../src/Conv_Channel/convchannel18.vhd",
                 "../../src/Conv_Channel/convchannel19.vhd",
                 "../../src/Conv_Channel/convchannel20.vhd",
                 "../../src/Conv_Channel/convchannel21.vhd",
                 "../../src/Conv_Channel/convchannel22.vhd",
                 "../../src/Conv_Channel/convchannel23.vhd",
                 "../../src/Conv_Channel/convchannel24.vhd",
                 "../../src/Conv_Channel/convchannel25.vhd",
                 "../../src/Conv_Channel/convchannel26.vhd",
                 "../../src/Conv_Channel/convchannel27.vhd",
                 "../../src/Conv_Channel/convchannel28.vhd",
                 "../../src/Conv_Channel/convchannel29.vhd",
                 "../../src/Conv_Channel/convchannel30.vhd",
                 "../../src/Conv_Channel/convchannel31.vhd",
                 "../../src/Conv_Channel/convchannel32.vhd",
                 "../../src/Conv_Channel/convchannel33.vhd",
                 "../../src/Conv_Channel/convchannel34.vhd",
                 "../../src/Conv_Channel/convchannel35.vhd",
                 "../../src/Conv_Channel/convchannel36.vhd",
                 "../../src/Conv_Channel/convchannel37.vhd",
                 "../../src/Conv_Channel/convchannel38.vhd",
                 "../../src/Conv_Channel/convchannel39.vhd",
                 "../../src/Conv_Channel/conv2d_0.vhd",
                 "../../src/Conv_Channel/conv2d_1.vhd"]

    tb_entity = "tb_toplevel"
    exit()

    if has_ghdl():
        tb.run_ghdl(filenames, tb_entity)

    if has_vivado():
        tb.run_vivado_sim_win()

    # %% check bram layer 1
    error_count_bram_l1 = tb.check_bram(image_data, 1)

    # %% check memory controller output layer 1
    error_count_vectors_l1 = tb.check_vectors(test_vectors_l1, 1)

    # %% check memory shiftregister output
    error_count_kernels_l1 = tb.check_kernels(test_kernels_l1, 1)

    error_count_l1 = error_count_bram_l1 + error_count_vectors_l1 + error_count_kernels_l1
    # %% check bram layer 2
    error_count_bram_l2 = tb.check_bram(features_l2, 2)

    # %% check memory controller output layer 1
    error_count_vectors_l2 = tb.check_vectors(test_vectors_l2, 2)

    # %% check memory shiftregister output
    error_count_kernels_l2 = tb.check_kernels(test_kernels_l2, 2)

    error_count_l2 = error_count_bram_l2 + error_count_vectors_l2 + error_count_kernels_l2
    # %% delete tmp folder
    error_count = error_count_l1 + error_count_l2

    if not KEEP_TEMPORARY_FILES and error_count == 0:
        shutil.rmtree('tmp')

    msg = f"""
Simulation finished

Layer 1
----------------------------------
Error BRAM L1:          {error_count_bram_l1}
Error Vectors L1:       {error_count_vectors_l1}
Error Kernels L1:       {error_count_kernels_l1}
Error BRAM L1:          {error_count_bram_l1}
------------------------------------
Total:                  {error_count_l1}

Layer 2
----------------------------------
Error BRAM L2:          {error_count_bram_l2}
Error Vectors L2:       {error_count_vectors_l2}
Error Kernels L2:       {error_count_kernels_l2}
Error BRAM L2:          {error_count_bram_l2}
------------------------------------
Total:                  {error_count_l2}


        """
    print(msg)
    if error_count != 0:
        raise Exception("Some Checks failed! \n\n" + msg)

def has_vivado():
    # Unfortunately only windows is supported for vivado.
    if platform.platform() == 'Windows':
        return True
    else:
        return False


def has_ghdl():
    # subprocess.check_output("ghdl --version")
    return 0 == subprocess.call(["ghdl", "--version"])


if __name__ == '__main__':
    main()
