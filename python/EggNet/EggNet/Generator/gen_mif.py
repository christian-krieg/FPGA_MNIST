# -*- coding: utf-8 -*-
"""
Created on Wed Mar 11 13:43:13 2020

@author: lukas
"""

import pathlib
import numpy as np
from bitstring import Bits
import json


def geneate_mif(HyperPar_Path: pathlib.Path, WeightsBias_Path: pathlib.Path, Mif_Path: pathlib.Path):
    """
    Generates mif files including weights and biases requird by EggNet.

    Parameters
    ----------
    HyperPar_Path : pathlib.Path
        Path to json file including the hyper parameter for Eggnet.
        Json file name have to be included in path.
    WeightsBias_Path : pathlib.Path
        Path to numpy files including the weights an biases for Eggnet.
    Mif_Path : pathlib.Path
        Path to MIF files.
    Returns
    -------
    None.

    """
    with open(HyperPar_Path) as json_file:
        data = json.load(json_file)
        print("---------------------------------------------------------------")
        print("Generating MIF files for: " + data['Name'] + " Version: " +  str(data['Version']))
        print("---------------------------------------------------------------")
        
        #%% Load hyper parameter
        bit_widths = data['Bit widths']
        ACTIVATION_WIDTH = bit_widths["Activation bit width"]
        WEIGHT_SHIFT_BIT_WIDTH = bit_widths["Bit width of weight shifts"]
        BIAS_WIDTH = bit_widths["Bias bit width"]
        KERNEL_FRACTION_SHIFT_WIDTH = bit_widths["Bit width of kernel fraction shifts"]
        CHANNEL_FRACTION_SHIFT_WIDTH= bit_widths["Bit width of channel fraction shifts"]
        
        fractions = data['Fractions']
        fraction_shift_kernel_l1 = fractions["Layer 1 kernel output fraction"] - fractions["Input Fraction"]
        fraction_shift_channel_l1 = fractions["Layer 1 layer output fraction"] - fractions["Layer 1 kernel output fraction"]
        fraction_shift_kernel_l2 = fractions["Layer 2 kernel output fraction"] - fractions["Layer 1 layer output fraction"] 
        fraction_shift_channel_l2 = fractions["Layer 2 layer output fraction"] - fractions["Layer 2 kernel output fraction"]

        #%% Load Weights and Biases 
        # shape: [H,W,Ci,Co]
        weights_conv_l1 = np.load(str(WeightsBias_Path)+ "/cn1.k.npy")
        weights_conv_l2 = np.load(str(WeightsBias_Path)+ "/cn2.k.npy")
        bias_conv_l1 = np.load(str(WeightsBias_Path)+ "/cn1.b.npy")
        bias_conv_l2 = np.load(str(WeightsBias_Path)+ "/cn2.b.npy")
        
        check_sign = lambda x : "0" if x >= 0.0 else "1"
        #%% Quantize Weights and Biases
        shift_conv_l1 = np.uint8(np.clip(np.around(np.abs(np.log2(np.abs(weights_conv_l1)))),0,2**WEIGHT_SHIFT_BIT_WIDTH-1))
        shift_conv_l2 = np.uint8(np.clip(np.around(np.abs(np.log2(np.abs(weights_conv_l2)))),0,2**WEIGHT_SHIFT_BIT_WIDTH-1))
        
        bias_qaunt_l1 = np.int16(np.around(2**(BIAS_WIDTH-1)*bias_conv_l1))
        bias_qaunt_l2 = np.int16(np.around(2**(BIAS_WIDTH-1)*bias_conv_l2))
        #%% Write to MIF files 
        # One MIF file for each output channel 
        
        #-------- Conv Layer 1 -------------------
        with open(str(Mif_Path) + "/Kernel_Fraction_shift_L1.mif", 'w+') as f:
            f.write(Bits(int=fraction_shift_kernel_l1, length=KERNEL_FRACTION_SHIFT_WIDTH).bin+"\n")  
        with open(str(Mif_Path) + "/Channel_Fraction_shift_L1.mif", 'w+') as f:
            f.write(Bits(int=fraction_shift_channel_l1, length=CHANNEL_FRACTION_SHIFT_WIDTH).bin+"\n") 
                     
        for l in range(np.shape(shift_conv_l1)[3]): 
            with open(str(Mif_Path) + "/Bias_L1_CO_" + str(l+1) + ".mif", 'w+') as f_bias:
                        f_bias.write(Bits(int=bias_qaunt_l1[l], length=BIAS_WIDTH).bin+"\n")
            with open(str(Mif_Path) + "/Weight_Shifts_L1_CO_" + str(l+1) + ".mif", 'w+') as f_shift:
                with open(str(Mif_Path) + "/Weight_Signs_L1_CO_" + str(l+1) + ".mif", 'w+') as f_sign:
                    for k in range(np.shape(shift_conv_l1)[2]):
                        for j in range(np.shape(shift_conv_l1)[0]):
                            for i in range(np.shape(shift_conv_l1)[1]):
                                f_shift.write(Bits(uint=shift_conv_l1[j,i,k,l], length=WEIGHT_SHIFT_BIT_WIDTH).bin+"\n")
                                f_sign.write(check_sign(weights_conv_l1[j,i,k,l])+"\n")
         
        #-------- Conv Layer 2 -------------------
        with open(str(Mif_Path) + "/Kernel_Fraction_shift_L2.mif", 'w+') as f:
            f.write(Bits(int=fraction_shift_kernel_l2, length=KERNEL_FRACTION_SHIFT_WIDTH).bin+"\n")  
        with open(str(Mif_Path) + "/Channel_Fraction_shift_L2.mif", 'w+') as f:
            f.write(Bits(int=fraction_shift_channel_l2, length=CHANNEL_FRACTION_SHIFT_WIDTH).bin+"\n") 
                     
        for l in range(np.shape(shift_conv_l2)[3]): 
            with open(str(Mif_Path) + "/Bias_L2_CO_" + str(l+1) + ".mif", 'w+') as f_bias:
                        f_bias.write(Bits(int=bias_qaunt_l2[l], length=BIAS_WIDTH).bin+"\n")
            with open(str(Mif_Path) + "/Weight_Shifts_L2_CO_" + str(l+1) + ".mif", 'w+') as f_shift:
                with open(str(Mif_Path) + "/Weight_Signs_L2_CO_" + str(l+1) + ".mif", 'w+') as f_sign:
                    for k in range(np.shape(shift_conv_l2)[2]):
                        for j in range(np.shape(shift_conv_l2)[0]):
                            for i in range(np.shape(shift_conv_l2)[1]):
                                f_shift.write(Bits(uint=shift_conv_l2[j,i,k,l], length=WEIGHT_SHIFT_BIT_WIDTH).bin+"\n")
                                f_sign.write(check_sign(weights_conv_l2[j,i,k,l])+"\n")            
#%% For direct usage 
if __name__ == "__main__":
    ROOT = pathlib.Path(__file__).parents[4]
    Mif_ROOT= ROOT / "vivado" / "NN_IP" / "EggNet_1.0" / "mif" 
    NP_ROOT = ROOT / "net" / "final_weights"/ "float"
    geneate_mif(ROOT / "EggNet.json", NP_ROOT, Mif_ROOT)




                    