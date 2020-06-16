# -*- coding: utf-8 -*-
"""
Created on Wed Mar 11 13:43:13 2020

@author: lukas
"""

import pathlib
import numpy as np
from bitstring import Bits
import json
from EggNet.quant import quant_log2

class Egg_Generator():
    def __init__(self,HyperPar_Path: pathlib.Path):
        with open(HyperPar_Path) as json_file:
            self.data = json.load(json_file)
            print("---------------------------------------------------------------")
            print("Use: " + self.data['Name'] + " Version: " +  str(self.data['Version']))
            print("---------------------------------------------------------------")
            
            #%% Load hyper parameter
            bit_widths = self.data['Bit widths']
            self.ACTIVATION_WIDTH = bit_widths["Activation bit width"]
            self.WEIGHT_SHIFT_BIT_WIDTH = bit_widths["Bit width of weight shifts"]
            self.BIAS_WIDTH = bit_widths["Bias bit width"]
            self.KERNEL_EXPONENT_SHIFT_WIDTH = bit_widths["Bit width of kernel exponent shifts"]
            self.CHANNEL_EXPONENT_SHIFT_WIDTH= bit_widths["Bit width of channel exponent shifts"]
            
            self.exponents = self.data['Exponents']
            self.input_exponent = self.exponents['Input Exponent']
                
    def generate_mif(self,WeightsBias_Path: pathlib.Path, Mif_Path: pathlib.Path):
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
        self.WeightsBias_Path = WeightsBias_Path
        self.Mif_Path = Mif_Path
        self._gen_conv_layer_mif(1)
        self._gen_conv_layer_mif(2)
        
       
    def _gen_conv_layer_mif(self,layer_nbr): 
        """
        Creates mif files for a convolutional layer

        Parameters
        ----------
        layer_nbr : integer
            Layer number.

        Returns
        -------
        None.

        """
        #%% Load Weights and Biases 
        # shape: [H,W,Ci,Co]
        weight_name = "cn"+str(layer_nbr)+".k.npy"
        bias_name = "cn"+str(layer_nbr)+".b.npy" 
        weights_conv = np.load(self.WeightsBias_Path / weight_name)
        bias_conv = np.load(self.WeightsBias_Path / bias_name)
        
        #%% Quantize Weights and Biases
        weight_shifts,weight_signs,bias = quant_log2(weights_conv,bias_conv,self.WEIGHT_SHIFT_BIT_WIDTH,self.BIAS_WIDTH)
        layer_key = "Layer " + str(layer_nbr)
        layer_key_prev = "Layer " + str(layer_nbr-1)
        #%% Write to MIF files 
        # One MIF file for each output channel 
        
        # Write exponent shift values 
        with open(str(self.Mif_Path) + "/Kernel_Exponent_shift_L"+str(layer_nbr)+".mif", 'w+') as f:
            if layer_nbr == 1:
                fraction_shift_kernel = self.input_exponent \
                                        - self.exponents[layer_key]["Kernel output exponent"]
                            
            else:
                fraction_shift_kernel = self.exponents[layer_key]["Kernel output exponent"] \
                                        - self.exponents[layer_key_prev]["Layer output exponent"] 
                                        
            f.write(Bits(int=fraction_shift_kernel, length=self.KERNEL_EXPONENT_SHIFT_WIDTH).bin+"\n")  
            
        with open(str(self.Mif_Path) + "/Layer_Exponent_shift_L"+str(layer_nbr)+".mif", 'w+') as f:
            fraction_shift_channel = self.exponents[layer_key]["Kernel output exponent"] \
                                        - self.exponents[layer_key]["Layer output exponent"]
            f.write(Bits(int=fraction_shift_channel, length=self.CHANNEL_EXPONENT_SHIFT_WIDTH).bin+"\n") 
                     
        for l in range(np.shape(weight_shifts)[3]): 
            with open(str(self.Mif_Path) + "/Bias_L"+str(layer_nbr)+"_CO_" + str(l+1) + ".mif", 'w+') as f_bias:
                        f_bias.write(Bits(int=bias[l], length=self.BIAS_WIDTH).bin+"\n")
            with open(str(self.Mif_Path) + "/Weight_Shifts_L"+str(layer_nbr)+"_CO_" + str(l+1) + ".mif", 'w+') as f_shift:
                with open(str(self.Mif_Path) + "/Weight_Signs_L"+str(layer_nbr)+"_CO_" + str(l+1) + ".mif", 'w+') as f_sign:
                    for k in range(np.shape(weight_shifts)[2]):
                        for j in range(np.shape(weight_shifts)[0]):
                            for i in range(np.shape(weight_shifts)[1]):
                                f_shift.write(Bits(uint=weight_shifts[j,i,k,l], length=self.WEIGHT_SHIFT_BIT_WIDTH).bin+"\n")
                                f_sign.write(Bits(uint=weight_signs[j,i,k,l], length=1).bin+"\n")
         
    def _gen_dense_layer_mif(self,layer_nbr): 
        raise Exception("Not implemented yet")
        
#%% For direct usage 
if __name__ == "__main__":
    ROOT = pathlib.Path(__file__).parents[4]
    Mif_ROOT= ROOT / "vivado" / "NN_IP" / "EggNet_1.0" / "mif" 
    NP_ROOT = ROOT / "net" / "final_weights"/ "float"
    generator = Egg_Generator(ROOT / "EggNet.json" )
    generator.geneate_mif(NP_ROOT, Mif_ROOT)                   
    
#%% Old code 
"""
 #% Load Weights and Biases 
        # shape: [H,W,Ci,Co]
        weights_conv_l1 = np.load(str(WeightsBias_Path)+ "/cn1.k.npy")
        weights_conv_l2 = np.load(str(WeightsBias_Path)+ "/cn2.k.npy")
        bias_conv_l1 = np.load(str(WeightsBias_Path)+ "/cn1.b.npy")
        bias_conv_l2 = np.load(str(WeightsBias_Path)+ "/cn2.b.npy")
        
        check_sign = lambda x : "0" if x >= 0.0 else "1"
        #%% Quantize Weights and Biases
        shift_conv_l1 = np.uint8(np.clip(np.around(np.abs(np.log2(np.abs(weights_conv_l1)))),0,2**self.WEIGHT_SHIFT_BIT_WIDTH-1))
        shift_conv_l2 = np.uint8(np.clip(np.around(np.abs(np.log2(np.abs(weights_conv_l2)))),0,2**self.WEIGHT_SHIFT_BIT_WIDTH-1))
        
        bias_qaunt_l1 = np.int16(np.around(2**(self.BIAS_WIDTH-1)*bias_conv_l1))
        bias_qaunt_l2 = np.int16(np.around(2**(self.BIAS_WIDTH-1)*bias_conv_l2))
        #%% Write to MIF files 
        # One MIF file for each output channel 
        
        #-------- Conv Layer 1 -------------------
        i = 0
        with open(str(Mif_Path) + "/Kernel_Fraction_shift_L"+str(i)+".mif", 'w+') as f:
            fraction_shift_kernel = self.layers[i]["Kernel output exponent"] - self.input_exponent
            f.write(Bits(int=fraction_shift_kernel, length=self.KERNEL_EXPONENT_SHIFT_WIDTH).bin+"\n")  
        with open(str(Mif_Path) + "/Channel_Fraction_shift_L"+str(i)+".mif", 'w+') as f:
            fraction_shift_channel = self.layers[i]["Layer output exponent"] - self.input_exponent
            f.write(Bits(int=fraction_shift_channel, length=self.CHANNEL_EXPONENT_SHIFT_WIDTH).bin+"\n") 
                     
        for l in range(np.shape(shift_conv_l1)[3]): 
            with open(str(Mif_Path) + "/Bias_L1_CO_" + str(l+1) + ".mif", 'w+') as f_bias:
                        f_bias.write(Bits(int=bias_qaunt_l1[l], length=self.BIAS_WIDTH).bin+"\n")
            with open(str(Mif_Path) + "/Weight_Shifts_L1_CO_" + str(l+1) + ".mif", 'w+') as f_shift:
                with open(str(Mif_Path) + "/Weight_Signs_L1_CO_" + str(l+1) + ".mif", 'w+') as f_sign:
                    for k in range(np.shape(shift_conv_l1)[2]):
                        for j in range(np.shape(shift_conv_l1)[0]):
                            for i in range(np.shape(shift_conv_l1)[1]):
                                f_shift.write(Bits(uint=shift_conv_l1[j,i,k,l], length=self.WEIGHT_SHIFT_BIT_WIDTH).bin+"\n")
                                f_sign.write(check_sign(weights_conv_l1[j,i,k,l])+"\n")
         
        #-------- Conv Layer 2 -------------------
        with open(str(Mif_Path) + "/Kernel_Fraction_shift_L2.mif", 'w+') as f:
            f.write(Bits(int=self.fraction_shift_kernel_l2, length=self.KERNEL_EXPONENT_SHIFT_WIDTH).bin+"\n")  
        with open(str(Mif_Path) + "/Channel_Fraction_shift_L2.mif", 'w+') as f:
            f.write(Bits(int=self.fraction_shift_channel_l2, length=self.CHANNEL_EXPONENT_SHIFT_WIDTH).bin+"\n") 
                     
        for l in range(np.shape(shift_conv_l2)[3]): 
            with open(str(Mif_Path) + "/Bias_L2_CO_" + str(l+1) + ".mif", 'w+') as f_bias:
                        f_bias.write(Bits(int=bias_qaunt_l2[l], length=self.BIAS_WIDTH).bin+"\n")
            with open(str(Mif_Path) + "/Weight_Shifts_L2_CO_" + str(l+1) + ".mif", 'w+') as f_shift:
                with open(str(Mif_Path) + "/Weight_Signs_L2_CO_" + str(l+1) + ".mif", 'w+') as f_sign:
                    for k in range(np.shape(shift_conv_l2)[2]):
                        for j in range(np.shape(shift_conv_l2)[0]):
                            for i in range(np.shape(shift_conv_l2)[1]):
                                f_shift.write(Bits(uint=shift_conv_l2[j,i,k,l], length=self.WEIGHT_SHIFT_BIT_WIDTH).bin+"\n")
                                f_sign.write(check_sign(weights_conv_l2[j,i,k,l])+"\n")     """