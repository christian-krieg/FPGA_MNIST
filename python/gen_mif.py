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
MIF_ROOT= ROOT.parent / "vivado" / "NN_IP " / "EggNet_1.0" / "mif" 
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

sign_conv_l1 = np.uint8(np.sign(weights_conv_l1))
sign_conv_l2 = np.uint8(np.sign(weights_conv_l2))

shift_conv_l1 = np.uint8(np.around(np.abs(np.log2(np.abs(weights_conv_l1)))))
shift_conv_l2 = np.uint8(np.around(np.abs(np.log2(np.abs(weights_conv_l2)))))

bias_qaunt_l1 = np.int16(np.around(256*bias_conv_l1))
bias_qaunt_l2 = np.int16(np.around(256*bias_conv_l2))

#Bitwidth_str = "0{}b".format(ACTIVATION_WIDTH*+WEIGHT_SHIFT_BIT_WIDTH)
#%% Write to MIF files 
# One MIF file for each output channel 

#-------- Conv Layer 1 -------------------
for l in range(np.shape(sign_conv_l1)[3]): 
    with open(str(MIF_ROOT) + "/Weight_Shifts_L1_CO_" + str(l+1) + ".mif", 'w+') as f_shift:
        with open(str(MIF_ROOT) + "/Weight_Signs_L1_CO_" + str(l+1) + ".mif", 'w+') as f_sign:
            for k in range(np.shape(sign_conv_l1)[2]):
                for j in range(np.shape(sign_conv_l1)[1]):
                    for i in range(np.shape(sign_conv_l1)[1]):
                        f_shift.write(Bits(int=shift_conv_l1[i,j,k,l], length=WEIGHT_SHIFT_BIT_WIDTH).bin+"\n")