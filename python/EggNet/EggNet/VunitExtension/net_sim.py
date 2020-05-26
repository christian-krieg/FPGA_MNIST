# -*- coding: utf-8 -*-
"""
Created on Sat Dec 21 14:41:54 2019

@author: lukas

Network simulation functions
-----------------------------

Provides functions for creating test data for the use in vhdl testbenches
Requirements: 
    numpy
    random
    pathlib
    c
"""
import numpy as np
import random

# %% memory controller

def get_vectors_from_data(test_data, img_width, img_hight, kernel_size=3, dtype=np.uint8):
    """
    Generates 3x1 vectors from test data

    Parameters
    ----------
    test_data : numpy array
        generated test data.
    img_width : integer
        with of test matrix.
    img_hight : integer
        hight of test matrix.
    kernel_size : integer, optional
        size of the kernel. The default is 3.
    dtype : numpy dtype, optional
        Data type of numpy array. The default is np.uint8.

    Returns
    -------
    vectors : numpy array
        Vector to compare with the output of the memory controller

    """
    vectors = np.zeros((test_data.shape[0], test_data.shape[1], kernel_size, test_data.shape[2]), dtype=dtype)
    for i in range(test_data.shape[0]):
        vector_cnt = 0
        for j in range(test_data.shape[1]):

            if j < img_width:
                vectors[i, vector_cnt, 0, :] = 0
                vectors[i, vector_cnt, 1, :] = test_data[i, j, :]
                vectors[i, vector_cnt, 2, :] = test_data[i, j + img_width, :]
                vector_cnt += 1
            elif j >= (img_width * (img_hight - 1)):
                # print(j)
                vectors[i, vector_cnt, 0, :] = test_data[i, j - img_width, :]
                vectors[i, vector_cnt, 1, :] = test_data[i, j, :]
                vectors[i, vector_cnt, 2, :] = 0
                vector_cnt += 1
            else:
                vectors[i, vector_cnt, 0, :] = test_data[i, j - img_width, :]
                vectors[i, vector_cnt, 1, :] = test_data[i, j, :]
                vectors[i, vector_cnt, 2, :] = test_data[i, j + img_width, :]
                vector_cnt += 1

    return vectors

#%% 3x3 shiftregister
def get_Kernels(test_vectors, img_width):
    """
    Creates 3x3 kernel which is operated by the conv2d

    Parameters
    ----------
    test_vectors : numpy array
        Generated test vectors 3x1.
    img_width : integer
        with of test matrix.
    Returns
    -------
    Kernel : numpy array
        Kernel to compare with the output of the shiftregister

    """
    kernels = np.zeros((test_vectors.shape[0], test_vectors.shape[1], test_vectors.shape[2], test_vectors.shape[2],
                        test_vectors.shape[3]), dtype=np.uint8)
    for i in range(test_vectors.shape[0]):
        for j in range(test_vectors.shape[1]):
            if j % img_width == 0:
                kernels[i, j, :, 0, :] = 0
                kernels[i, j, :, 1, :] = test_vectors[i, j, :, :]
                kernels[i, j, :, 2, :] = test_vectors[i, j + 1, :, :]

            elif j % img_width == img_width - 1:
                kernels[i, j, :, 0, :] = test_vectors[i, j - 1, :, :]
                kernels[i, j, :, 1, :] = test_vectors[i, j, :, :]
                kernels[i, j, :, 2, :] = 0
            else:
                kernels[i, j, :, 0, :] = test_vectors[i, j - 1, :, :]
                kernels[i, j, :, 1, :] = test_vectors[i, j, :, :]
                kernels[i, j, :, 2, :] = test_vectors[i, j + 1, :, :]

    return kernels


# %% convolutional layer

def conv_2d(kernels, weights, msb):
    """
    Emulates the operation carried out by the conv2d module in the FPGA

    Parameters
    ----------
    kernel : numpy array [B,W*H,Kh,Kw,Ci]
        B.. Batch size
        W*H.. Image width times hight
        Kh.. Kernel hight
        Kw.. Kernel width
        Ci.. channel number
        Input kernels
    weights : numpy array [Co,Ci,Kh,Kw]
        Co.. output channel number
        Ci.. input channel number
        Kh.. Kernel hight
        Kw .. Kernel with
        Weigth matrix for each kernel
    msb : numpy array [Co,Ci]
        Co.. output channel number
        MSB values for quantization

    Returns
    -------
    features: numpy array [B,W*H,Co] dtype=np.uint8
        B.. Batch size
        W*H.. Image width times hight
        Co.. output channel number

        8 bit output Matrix
    """
    features = np.zeros((kernels.shape[0], kernels.shape[1], weights.shape[0]), dtype=np.uint8)
    for i in range(kernels.shape[0]):
        for j in range(kernels.shape[1]):
            for k in range(weights.shape[0]):
                features[i, j, k] = conv_channel(kernels[i, j, :, :, :], weights[k, :, :, :], msb[k])
    return features


def conv_channel(kernels, weights, msb):
    """
    Emulates the operation carried out by the conv_channel module in the FPGA

    Parameters
    ----------
    kernels : numpy array [B,W*H,Kh,Kw,Ci]
        B.. Batch size
        W*H.. Image width times hight
        Kh.. Kernel hight
        Kw.. Kernel width
        Ci.. channel number
        Input kernels
    weights : numpy array [Ci,Kh,Kw]
        Ci.. input channel number
        Kh.. Kernel hight
        Kw .. Kernel with
        Weigth matrix for each kernel
    msb : integer
        MSB postion for quantization

    Returns
    -------
    weighted_sum: np.uint8
        B.. Batch size
        W*H.. Image width times hight

        8 bit output Matrix
    """
    weighted_sum = np.int32(0)
    for k in range(weights.shape[0]):
        weighted_sum += kernel_3x3(kernels[:, :, k], weights[k, :, :])

    # Relu (Additional benefit np.int16(int("0x00FF",16)) & feature would not work for negative numbers because of 2's complement)
    if weighted_sum < 0:
        weighted_sum = 0
    else:  # Quantization
        weighted_sum >>= msb + 1 - 8
        if weighted_sum > 255:
            weighted_sum = 255

    return np.uint8(weighted_sum)


def kernel_3x3(kernel, weights):
    """
    Emulates the operation carried out by the 3x3_kernel module in the FPGA

    Parameters
    ----------
    kernel : numpy array [Kh,Kw]
        Kh.. Kernel hight
        Kw.. Kernel width
        Input kernels
    weights : numpy array [Kh,Kw]
        Kh.. Kernel hight
        Kw .. Kernel with
        Weigth matrix for each kernel

    Returns
    -------
    weighted_sum: np.int16
        16 bit output Matrix
    """
    weighted_sum = np.int32(np.sum(kernel * weights))
    return weighted_sum

# %% log 2 convolutional layer

def conv_2d_log2(kernels, weight_shifts, weight_signs, fraction_shift_channel, faction_shift_kernel):
    """
    Emulates the operation carried out by the conv2d module in the FPGA

    Parameters
    ----------
    kernel : numpy array [B,H,W,Kh,Kw,Ci]
        B.. Batch size
        H.. Image hight
        W.. Image width
        Kh.. Kernel hight
        Kw.. Kernel width
        Ci.. channel number
        Input kernels
    weight_shifts : numpy array [Co,Ci,Kh,Kw]
        Co.. output channel number
        Ci.. input channel number
        Kh.. Kernel hight
        Kw .. Kernel with
        Weigth shift matrix for each kernel
    weight_signs : numpy array [Co,Ci,Kh,Kw]
        Co.. output channel number
        Ci.. input channel number
        Kh.. Kernel hight
        Kw .. Kernel with
        Signs of shift weights matrix for each kernel        
    fraction_shift_channel: integer
        fraction shifts for quantization after conv_channels
    faction_shift_kernel: integer
        fraction shifts for quantization after each 3x3 kernel
        
    Returns
    -------
    features: numpy array [B,H,W,Co] dtype=np.uint8
        B.. Batch size
        H.. Image hight
        W.. Image width
        Co.. output channel number

        8 bit output Matrix
    """
    features = np.zeros((kernels.shape[0], kernels.shape[1], weights.shape[0]), dtype=np.uint8)
    for i in range(kernels.shape[0]):
        for j in range(kernels.shape[1]):
            for k in range(weights.shape[0]):
                features[i, j, k] = conv_channel(kernels[i, j, :, :, :], weights[k, :, :, :], msb[k])
    return features


def conv_channel(kernels, weights, msb):
    """
    Emulates the operation carried out by the conv_channel module in the FPGA

    Parameters
    ----------
    kernels : numpy array [B,W*H,Kh,Kw,Ci]
        B.. Batch size
        W*H.. Image width times hight
        Kh.. Kernel hight
        Kw.. Kernel width
        Ci.. channel number
        Input kernels
    weights : numpy array [Ci,Kh,Kw]
        Ci.. input channel number
        Kh.. Kernel hight
        Kw .. Kernel with
        Weigth matrix for each kernel
    msb : integer
        MSB postion for quantization

    Returns
    -------
    weighted_sum: np.uint8
        B.. Batch size
        W*H.. Image width times hight

        8 bit output Matrix
    """
    weighted_sum = np.int32(0)
    for k in range(weights.shape[0]):
        weighted_sum += kernel_3x3(kernels[:, :, k], weights[k, :, :])

    # Relu (Additional benefit np.int16(int("0x00FF",16)) & feature would not work for negative numbers because of 2's complement)
    if weighted_sum < 0:
        weighted_sum = 0
    else:  # Quantization
        weighted_sum >>= msb + 1 - 8
        if weighted_sum > 255:
            weighted_sum = 255

    return np.uint8(weighted_sum)


def kernel_3x3(kernel, weights):
    """
    Emulates the operation carried out by the 3x3_kernel module in the FPGA

    Parameters
    ----------
    kernel : numpy array [Kh,Kw]
        Kh.. Kernel hight
        Kw.. Kernel width
        Input kernels
    weights : numpy array [Kh,Kw]
        Kh.. Kernel hight
        Kw .. Kernel with
        Weigth matrix for each kernel

    Returns
    -------
    weighted_sum: np.int16
        16 bit output Matrix
    """
    weighted_sum = np.int32(np.sum(kernel * weights))
    return weighted_sum
# %% Result checks
def check_bram(test_data, layernumber):
    """
    checks the 

    Parameters
    ----------
    test_data : numpy array [B,W*H,Ci]
        Data to check. Content of BRAM
    layernumber : integer
        Number of layer

    Returns
    -------
    error_count : interger
        Number of errors.

    """
    BLOCK_SIZE = test_data.shape[1]
    error_count = 0
    for i in range(test_data.shape[0]):
        with open("tmp/l{}".format(layernumber) + "_bram{}.txt".format(i), "r") as f:
            for j in range(test_data.shape[0] * 2):
                block_select = 1 - (i + 1) % 2
                read_data = f.readline().rstrip()
                result_data = [int(g) for g in read_data.split(' ')]
                for k in range(test_data.shape[2]):
                    if block_select == 0 and j < BLOCK_SIZE:
                        if result_data[k] != test_data[i, j, k]:
                            print("Error in block {}".format(i) + " channel {}".format(k) + " in line {} ,".format(
                                j + block_select * BLOCK_SIZE) \
                                  + "{}".format(result_data[k]) + " != {}".format(test_data[i, j, k]))
                            error_count += 1
                    elif block_select == 0 and j >= BLOCK_SIZE and i == 0:
                        if result_data[k] != 0:
                            print("Error in block {}".format(i) + " channel {}".format(k) + " in line {} ,".format(
                                j + block_select * BLOCK_SIZE) \
                                  + "{}".format(result_data[k]) + " != {}".format(0))
                            error_count += 1
                    elif block_select == 0 and j >= BLOCK_SIZE:
                        if result_data[k] != test_data[i - 1, j - BLOCK_SIZE, k]:
                            print("Error in block {}".format(i) + " channel {}".format(k) + " in line {} ,".format(
                                j + block_select * BLOCK_SIZE) \
                                  + "{}".format(result_data[k]) + " != {}".format(test_data[i - 1, j - BLOCK_SIZE, k]))
                            error_count += 1
                    elif block_select == 1 and j < BLOCK_SIZE:
                        if result_data[k] != test_data[i - 1, j, k]:
                            print("Error in block {}".format(i) + " channel {}".format(k) + " in line {} ,".format(
                                j + block_select * BLOCK_SIZE) \
                                  + "{}".format(result_data[k]) + " != {}".format(test_data[i - 1, j, k]))
                            error_count += 1
                    elif block_select == 1 and j >= BLOCK_SIZE:
                        if result_data[k] != test_data[i, j - BLOCK_SIZE, k]:
                            print("Error in block {}".format(i) + " channel {}".format(k) + " in line {} ,".format(
                                j + block_select * BLOCK_SIZE) \
                                  + "{}".format(result_data[k]) + " != {}".format(test_data[i, j - BLOCK_SIZE, k]))
                            error_count += 1
                    else:
                        print("Error in porgram")

    if error_count == 0:
        print("No errors in BRAM")
    else:
        print("{} errors occurred checking BRAM".format(error_count))

    return error_count


def check_vectors(test_vectors, layernumber):
    """
    

    Parameters
    ----------
    test_vectors : numpy array [B,W*H,3,Ci]
        Data to check. Output data of MemCtrl
    layernumber : integer
        Number of layer.

    Returns
    -------
    error_count_vectors : integer
        Number of errors.

    """
    error_count_vectors = 0
    result_vectors = np.zeros(
        (test_vectors.shape[0], test_vectors.shape[1], test_vectors.shape[2], test_vectors.shape[3]), dtype=np.uint8)
    for i in range(test_vectors.shape[0]):
        with open("tmp/l{}".format(layernumber) + "_inVector_1_b{}.txt".format(i), "r") as f:
            for j in range(test_vectors.shape[1]):
                read_data = f.readline().rstrip()
                result_vectors[i, j, 0, :] = [int(g) for g in read_data.split(' ')]
                if any(result_vectors[i, j, 0, :] != test_vectors[i, j, 0, :]):
                    print("Error in tmp/l{}".format(layernumber) + "_inVector_1_b{}.txt" + " in line {} ,".format(j) \
                          + "{}".format(result_vectors[i, j, 0, :]) + " != {}".format(test_vectors[i, j, 0, :]))
                    error_count_vectors += 1
        with open("tmp/l{}".format(layernumber) + "_inVector_2_b{}.txt".format(i), "r") as f:
            for j in range(test_vectors.shape[1]):
                read_data = f.readline().rstrip()
                result_vectors[i, j, 1, :] = [int(g) for g in read_data.split(' ')]
                if any(result_vectors[i, j, 1, :] != test_vectors[i, j, 1, :]):
                    print("Error in tmp/l{}".format(layernumber) + "_inVector_1_b{}.txt" + " in line {} ,".format(j) \
                          + "{}".format(result_vectors[i, j, 1, :]) + " != {}".format(test_vectors[i, j, 1, :]))
                    error_count_vectors += 1
        with open("tmp/l{}".format(layernumber) + "_inVector_3_b{}.txt".format(i), "r") as f:
            for j in range(test_vectors.shape[1]):
                read_data = f.readline().rstrip()
                result_vectors[i, j, 2, :] = [int(g) for g in read_data.split(' ')]
                if any(result_vectors[i, j, 2, :] != test_vectors[i, j, 2, :]):
                    print("Error in tmp/l{}".format(layernumber) + "_inVector_1_b{}.txt".format(i) + " in line {} ,".format(j) \
                          + "{}".format(result_vectors[i, j, 2, :]) + " != {}".format(test_vectors[i, j, 2, :]))
                    error_count_vectors += 1
    if error_count_vectors == 0:
        print("Received Kernel vectors successfully!")
    else:
        print("{} errors occured receiving image".format(error_count_vectors))

    return error_count_vectors


def check_kernels(test_kernels, layernumber):
    """
    

    Parameters
    ----------
    test_kernels : numpy array [B,W*H,3,3,Ci]
        Data to check. Output data of shiftreg
    layernumber : TYPE
        DESCRIPTION.

    Returns
    -------
    error_count_kernels : TYPE
        DESCRIPTION.

    """
    error_count_kernels = 0
    result_kernels = np.zeros((test_kernels.shape[0], test_kernels.shape[1], test_kernels.shape[2],
                               test_kernels.shape[3], test_kernels.shape[4]), dtype=np.uint8)
    for i in range(result_kernels.shape[0]):
        file_cnt = 0
        for k in range(test_kernels.shape[2]):
            for h in range(test_kernels.shape[3]):
                file_cnt += 1
                with open("tmp/l{}".format(layernumber) + "_inKernel_{}".format(file_cnt) + "_b{}.txt".format(i),
                          "r") as f:
                    for j in range(result_kernels.shape[1]):
                        read_data = f.readline().rstrip()
                        result_kernels[i, j, h, k, :] = [int(g) for g in read_data.split(' ')]
                        if any(result_kernels[i, j, h, k, :] != test_kernels[i, j, h, k, :]):
                            print("Error in l{}".format(layernumber) + "_inKernel_{}".format(file_cnt) + "_b{}".format(
                                i) + " in line {} ,".format(j) \
                                  + "{}".format(result_kernels[i, j, h, k, :]) + " != {}".format(
                                test_kernels[i, j, h, k, :]))
                            error_count_kernels += 1

    if error_count_kernels == 0:
        print("Received Kernel from shiftregister successfully!")
    else:
        print("{} errors occured receiving image".format(error_count_kernels))

    return error_count_kernels

def check_dense_in(test_vectors, layernumber):
    """
    

    Parameters
    ----------
    test_vectors : numpy array [B,W*H,Ci]
        Data to check. Output data of MemCtrl
    layernumber : integer
        Number of layer.

    Returns
    -------
    error_count_vectors : integer
        Number of errors.

    """
    error_count_vectors = 0
    result_vectors = np.zeros(
        (test_vectors.shape[0], test_vectors.shape[1], test_vectors.shape[2]), dtype=np.uint8)
    for i in range(test_vectors.shape[0]):
        with open("tmp/l{}".format(layernumber) + "_inData_b{}.txt".format(i), "r") as f:
            for j in range(test_vectors.shape[1]):
                read_data = f.readline().rstrip()
                result_vectors[i, j, :] = [int(g) for g in read_data.split(' ')]   
                if any(result_vectors[i, j, :] != test_vectors[i, j, :]):
                    print("Error in tmp/l{}".format(layernumber) + "_inData_b{}.txt".format(i) + " in line {} ,".format(j) \
                          + "{}".format(result_vectors[i, j, :]) + " != {}".format(test_vectors[i, j, :]))
                    error_count_vectors += 1
    if error_count_vectors == 0:
        print("Received Kernel vectors successfully!")
    else:
        print("{} errors occured receiving image".format(error_count_vectors))

    return error_count_vectors

