# -*- coding: utf-8 -*-
"""
Created on Wed Mar 11 13:43:13 2020

@author: lukas
"""

import os
import pathlib
import numpy as np
from bitstring import Bits

#%% Bit width definition
# Check egg_box.vhd

ACTIVATION_WIDTH = 8
WEIGHT_SHIFT_BIT_WIDTH = 4
BIAS_WIDTH = 9
KERNEL_FRACTION_SHIFT_WIDTH = 2
CHANNEL_FRACTION_SHIFT_WIDTH = 3

#%%  Setup Workspace

ROOT = pathlib.Path(__file__).parent
MIF_ROOT= ROOT.parent / "vivado" / "NN_IP" / "EggNet_1.0" / "mif" 
NP_ROOT = ROOT.parent / "net" / "final_weights"/ "float"

print(str(MIF_ROOT))

DATA_WIDTH_W = 4
W_Number = 3
Weights = (6,-7,3,-1,6,-7,3,-1)
#%% Load Weights, Biases and Fractions
# shape: [H,W,Ci,Co]
weights_conv_l1 = np.load(str(NP_ROOT)+ "/cn1.k.npy")
weights_conv_l2 = np.load(str(NP_ROOT)+ "/cn2.k.npy")
bias_conv_l1 = np.load(str(NP_ROOT)+ "/cn1.b.npy")
bias_conv_l2 = np.load(str(NP_ROOT)+ "/cn2.b.npy")

check_sign = lambda x : "0" if x >= 0.0 else "1"


shift_conv_l1 = np.uint8(np.clip(np.around(np.abs(np.log2(np.abs(weights_conv_l1)))),0,7))
shift_conv_l2 = np.uint8(np.clip(np.around(np.abs(np.log2(np.abs(weights_conv_l2)))),0,7))

bias_qaunt_l1 = np.int16(np.around(256*bias_conv_l1))
bias_qaunt_l2 = np.int16(np.around(256*bias_conv_l2))

# TODO: add real fractions based on NN training 
# FIXME: NO REAL FRACTION SHIFT VALUES!!!!!!!!!!!!
fraction_shift_kernel_l1 = 1
fraction_shift_channel_l1 = 2
fraction_shift_kernel_l2 = 0
fraction_shift_channel_l2 = 3
#%% Write to MIF files 
# One MIF file for each output channel 

#-------- Conv Layer 1 -------------------
with open(str(MIF_ROOT) + "/Kernel_Fraction_shift_L1.mif", 'w+') as f:
    f.write(Bits(int=fraction_shift_kernel_l1, length=KERNEL_FRACTION_SHIFT_WIDTH).bin+"\n")  
with open(str(MIF_ROOT) + "/Channel_Fraction_shift_L1.mif", 'w+') as f:
    f.write(Bits(int=fraction_shift_channel_l1, length=CHANNEL_FRACTION_SHIFT_WIDTH).bin+"\n") 
             
for l in range(np.shape(shift_conv_l1)[3]): 
    with open(str(MIF_ROOT) + "/Bias_L1_CO_" + str(l+1) + ".mif", 'w+') as f_bias:
                f_bias.write(Bits(int=bias_qaunt_l1[l], length=BIAS_WIDTH).bin+"\n")
    with open(str(MIF_ROOT) + "/Weight_Shifts_L1_CO_" + str(l+1) + ".mif", 'w+') as f_shift:
        with open(str(MIF_ROOT) + "/Weight_Signs_L1_CO_" + str(l+1) + ".mif", 'w+') as f_sign:
            for k in range(np.shape(shift_conv_l1)[2]):
                for j in range(np.shape(shift_conv_l1)[0]):
                    for i in range(np.shape(shift_conv_l1)[1]):
                        f_shift.write(Bits(int=shift_conv_l1[j,i,k,l], length=WEIGHT_SHIFT_BIT_WIDTH).bin+"\n")
                        f_sign.write(check_sign(weights_conv_l1[j,i,k,l])+"\n")
 
#-------- Conv Layer 2 -------------------
with open(str(MIF_ROOT) + "/Kernel_Fraction_shift_L2.mif", 'w+') as f:
    f.write(Bits(int=fraction_shift_kernel_l2, length=KERNEL_FRACTION_SHIFT_WIDTH).bin+"\n")  
with open(str(MIF_ROOT) + "/Channel_Fraction_shift_L2.mif", 'w+') as f:
    f.write(Bits(int=fraction_shift_channel_l2, length=CHANNEL_FRACTION_SHIFT_WIDTH).bin+"\n") 
             
for l in range(np.shape(shift_conv_l2)[3]): 
    with open(str(MIF_ROOT) + "/Bias_L2_CO_" + str(l+1) + ".mif", 'w+') as f_bias:
                f_bias.write(Bits(int=bias_qaunt_l2[l], length=BIAS_WIDTH).bin+"\n")
    with open(str(MIF_ROOT) + "/Weight_Shifts_L2_CO_" + str(l+1) + ".mif", 'w+') as f_shift:
        with open(str(MIF_ROOT) + "/Weight_Signs_L2_CO_" + str(l+1) + ".mif", 'w+') as f_sign:
            for k in range(np.shape(shift_conv_l2)[2]):
                for j in range(np.shape(shift_conv_l2)[0]):
                    for i in range(np.shape(shift_conv_l2)[1]):
                        f_shift.write(Bits(int=shift_conv_l2[j,i,k,l], length=WEIGHT_SHIFT_BIT_WIDTH).bin+"\n")
                        f_sign.write(check_sign(weights_conv_l2[j,i,k,l])+"\n")                        