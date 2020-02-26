import os
from typing import List

import numpy as np

from NeuralNetwork.NN.ConvLayer import Conv2dLayer, MaxPool2dLayer
from NeuralNetwork.NN.Costs import mean_squared_error
from NeuralNetwork.NN.FullyConnected import FullyConnectedLayer
from NeuralNetwork.NN.Layer import Layer
from NeuralNetwork.NN.Quant import QuantConvLayerType, QuantFullyConnectedType, quantize_vector
from NeuralNetwork.NN.Util import ReshapeLayer


def check_layers(list_of_layers: List[Layer]):
    """

    :type list_of_layers: List[Layer]
    """

    for i in range(1, len(list_of_layers)):
        l1 = list_of_layers[i - 1]
        l2 = list_of_layers[i]

        # Get the shapes and convert to numpy arrays
        l1_shape_out = np.array(l1.get_output_shape())
        l2_shape_in = np.array(l2.get_input_shape())

        if l2_shape_in.ndim == 0:
            # Zero dimension layer accepts every input
            continue

        if not (l1_shape_out.ndim == l2_shape_in.ndim):
            raise ValueError(
                "Output of layer {} dim({}) but input of layer {} has dim({})".format(i, len(l1_shape_out), i + 1,
                                                                                      len(l2_shape_in)))
        if not np.all(l1_shape_out == l2_shape_in):
            raise ValueError(
                "Layer {} has dimensions [{}] but layer {} has [{}]".format(i, l1_shape_out, i + 1, l2_shape_in))


class Network:
    layers: List[Layer]

    def __init__(self, list_of_layers: List[Layer]):
        """

        :type list_of_layers: List[Layer]
        """
        # check_layers(list_of_layers)

        self.layers = list_of_layers

    def __call__(self, *args, **kwargs):
        return self.forward(*args, **kwargs)

    def forward(self, x, *args, **kwargs):
        z, _ = self.forward_intermediate(x)
        return z

    def forward_intermediate(self, x):
        z = x  # copy data
        zs = []
        for l in self.layers:
            z = l(z)
            zs.append(z)
        return z, zs

    def backprop(self, x, y_):
        y, zs = self.forward_intermediate(x)
        loss = mean_squared_error(y, y_)
        delta = y - y_
        deltas = []
        for l in self.layers:
            delta = l.backprop(delta)
            deltas.append(delta)
            l.update_weights(delta)

    def __copy__(self):
        net = Network(list_of_layers=[layer.deepcopy() for layer in self.layers])
        return net

    def cast(self, new_dtype: np.dtype):

        # Only cast to other floating point types
        if not (new_dtype in (np.float, np.float32, np.float16)):
            # for integer types take special considerations
            return self.quantize_network(network=self, target_dype=new_dtype)
        else:
            layers = [layer.deepcopy() for layer in self.layers]

            for layer in layers:
                layer.cast(new_dtype)

            net = Network(list_of_layers=layers)
            return net

    def quantize_network(self, new_dtype, max_value, min_value,
                         full_layer_quant_type=QuantFullyConnectedType.FULL_LAYER,
                         conv_layer_quant_type=QuantConvLayerType.PER_CHANNEL):
        """
        Quantizes the weights and activations of the network and returns a copy

        A Survey on Methods and Theories of Quantized Neural Networks,
        Yunhui Guo
        University of California, San Diego,
        arXiv:1808.04752v2, 2018

        Args:
            min_value:
            max_value:
            target_dype:
            full_layer_quant_type:
            conv_layer_quant_type:

        Returns:

        """

        layers_copy = [layer.deepcopy() for layer in self.layers]
        for layer in layers_copy:
            layer.quantize_layer(target_type=new_dtype, max_value=max_value, min_value=min_value)
        net = Network(list_of_layers=layers_copy)
        return net

    def get_network_weights(self):
        weights_dict = {}

        for i, layer in enumerate(self.layers):
            if isinstance(layer, FullyConnectedLayer):
                weights_dict["{}:FC:W".format(i)] = layer.weights
                weights_dict["{}:FC:b".format(i)] = layer.bias
            elif isinstance(layer, Conv2dLayer):
                weights_dict["{}:Conv2D:kernel".format(i)] = layer.weights
                weights_dict["{}:Conv2D:b".format(i)] = layer.bias

        return weights_dict


class LeNet(Network):
    """
    Implementation of LeNet with own Neural Network Library
    """

    CN1_SHAPE = (1, 16, 3, 3)
    CN2_SHAPE = (16, 32, 3, 3)
    FC1_SHAPE = (32 * 7 * 7, 32)
    FC2_SHAPE = (32, 10)

    def __init__(self, dtype=np.float32):
        r1 = ReshapeLayer(newshape=[-1, 28, 28, 1])
        cn1 = Conv2dLayer(in_channels=1, out_channels=16, kernel_size=3, activation='relu',
                          dtype=np.float32)  # [? 28 28 16]
        mp1 = MaxPool2dLayer(size=2)  # [? 14 14 16]
        cn2 = Conv2dLayer(in_channels=16, out_channels=32, kernel_size=3, activation='relu')  # [? 14 14 32]
        mp2 = MaxPool2dLayer(size=2)  # [?  7  7 32]
        r2 = ReshapeLayer(newshape=[-1, 32 * 7 * 7])
        fc1 = FullyConnectedLayer(input_size=32 * 7 * 7, output_size=32, activation='relu', dtype=np.float32)
        fc2 = FullyConnectedLayer(input_size=32, output_size=10, activation='softmax')

        # Store a reference to each layer
        self.r1 = r1
        self.cn1 = cn1
        self.mp1 = mp1
        self.cn2 = cn2
        self.mp2 = mp2
        self.r2 = r2
        self.fc1 = fc1
        self.fc2 = fc2
        self.lenet_layers = [r1, cn1, mp1, cn2, mp2, r2, fc1, fc2]

        super(LeNet, self).__init__(self.lenet_layers)

    @staticmethod
    def load_from_files(save_dir):
        """
        Loads the LeNet with the files specified in the passed directory
        Args:
            save_dir:

        Returns:

        """

        model = LeNet()

        model.cn1.kernel = np.loadtxt(os.path.join(save_dir, 'w0.txt')).reshape(model.cn1.kernel.shape)
        model.cn1.b = np.loadtxt(os.path.join(save_dir, 'w1.txt')).reshape(model.cn1.b.shape)
        model.cn2.kernel = np.loadtxt(os.path.join(save_dir, 'w2.txt')).reshape(model.cn2.kernel.shape)
        model.cn2.b = np.loadtxt(os.path.join(save_dir, 'w3.txt')).reshape(model.cn2.b.shape)
        model.fc1.W = np.loadtxt(os.path.join(save_dir, 'w4.txt')).reshape(model.fc1.W.shape)
        model.fc1.b = np.loadtxt(os.path.join(save_dir, 'w5.txt')).reshape(model.fc1.b.shape)
        model.fc2.W = np.loadtxt(os.path.join(save_dir, 'w6.txt')).reshape(model.fc2.W.shape)
        model.fc2.b = np.loadtxt(os.path.join(save_dir, 'w7.txt')).reshape(model.fc2.b.shape)

        return model

    @staticmethod
    def load_from_files_generic(save_dir):
        """

        Args:
            save_dir:

        Returns:

        """
        for root, dirs, files in os.walk(top=save_dir):
            txt_files = filter(lambda s: s.endswith('.txt'), files)
            for i, weight_file in enumerate(files):

                # Get shape
                with open(weight_file) as f:
                    init_line = f.readline()
                    # assume the first line is a comment
                    assert init_line[0] == '#'
                    p1 = init_line.find('(')
                    p2 = init_line.find(')')
                    dims = [int(ds) for ds in init_line[p1:p2].split(sep=',')]
                    # dims is tuple now
                    if len(dims) == 4:
                        # conv layer
                        pass
                    elif len(dims) == 2:
                        # fully connected
                        pass
                    elif len(dims) == 1:
                        # bias
                        pass

                weight_loaded = np.loadtxt(weight_file)
                # ToDo: Finish this up by mapping the weights to the right layer