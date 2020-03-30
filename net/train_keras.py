#!/usr/bin/env python3
from __future__ import print_function, division

import os

import keras
import keras.layers as layers
import numpy as np
from keras.layers import BatchNormalization, Reshape, Conv2D, ReLU, Dropout, MaxPooling2D, Flatten, Dense

MODEL_SAVE_PATH = "keras"
MODEL_CKPT_PATH = os.path.join("keras", "cp.ckpt")
MODEL_WGHTS_SAVE_PATH = os.path.join(MODEL_SAVE_PATH, 'weights.h5')
MODEL_CONFIG_SAVE_PATH = os.path.join(MODEL_SAVE_PATH, 'model_config.json')

IMG_HEIGHT = 28
IMG_WIDTH = 28
DEFAULT_PLOT_HISTORY = False
DEFAULT_EPOCHS = 10
BATCH_SIZE = 128

KERAS_SAVE_DIR = 'keras'
KERAS_CONFIG_FILE = os.path.join(KERAS_SAVE_DIR, 'model_config.json')
KERAS_WEIGHTS_FILE = os.path.join(KERAS_SAVE_DIR, 'weights.h5')

EXPORT_DIR = 'np'
SCRIPT_PATH = os.path.dirname(os.path.abspath(__file__))


def train(nepochs=DEFAULT_EPOCHS, batch_size=BATCH_SIZE, plot_history=DEFAULT_PLOT_HISTORY):
    (x_train, y_train), (x_test, y_test) = keras.datasets.mnist.load_data()
    x_train, x_test = x_train / 255.0, x_test / 255.0

    # Define Constraints (useful for quantization)
    kernel_constraint = keras.constraints.max_norm(max_value=1)

    """
    Define the model here
    
    Changes:
    - Added initial BatchNorm: Makes sense to distribute the input image data evenly around zero
    - Increased value of dropout layer to .5 in first fully connected layer 
    - Removed bias from conv layers
    """
    model = keras.models.Sequential(name="KerasEggNet", layers=[
        # Hack: Reshape the image to 1D to make the Keras BatchNorm layer work
        # Reshape(target_shape=(IMG_HEIGHT * IMG_WIDTH, 1), input_shape=(IMG_HEIGHT, IMG_WIDTH)),
        # BatchNormalization(),
        Reshape((IMG_HEIGHT, IMG_WIDTH, 1), input_shape=(IMG_HEIGHT, IMG_WIDTH)),
        # Reshape to 3D input for the Conv layer
        Conv2D(filters=16, kernel_size=3, padding='same', activation='linear', use_bias=True,
               kernel_constraint=kernel_constraint),
        Dropout(0.25),
        ReLU(max_value=4.0),
        MaxPooling2D(),
        # BatchNormalization(axis=-1),  # Normalize along the channels (meaning last axis)
        Conv2D(filters=24, kernel_size=3, padding='same', activation='linear', use_bias=True,
               kernel_constraint=kernel_constraint),
        Dropout(0.25),
        ReLU(max_value=4.0),
        MaxPooling2D(),
        Flatten(),
        Dense(32, activation='linear', kernel_constraint=kernel_constraint),
        Dropout(0.25),
        ReLU(max_value=4.0),
        Dense(10, activation='softmax', kernel_constraint=kernel_constraint)
    ])

    # You must install pydot and graphviz for `pydotprint` to work.
    # keras.utils.plot_model(model, 'multi_input_and_output_model.png', show_shapes=True)
    model.compile(optimizer='adam',
                  loss='sparse_categorical_crossentropy',
                  metrics=['accuracy'])
    model.build()
    model.summary()
    checkpoint_dir = os.path.dirname(MODEL_CKPT_PATH)

    # Create a callback that saves the model's weights
    cp_callback = keras.callbacks.ModelCheckpoint(filepath=MODEL_CKPT_PATH,
                                                  save_weights_only=True,
                                                  verbose=1)

    # For higher GPU Utilization it is useful to increase batch_size but this can slow down training
    history = model.fit(x_train, y_train,
                        epochs=nepochs,
                        batch_size=batch_size,
                        validation_split=0.1,
                        callbacks=[cp_callback])

    # Save JSON config to disk
    json_config = model.to_json()
    with open(MODEL_CONFIG_SAVE_PATH, 'w') as json_file:
        json_file.write(json_config)

    # Save weights in binary to disk
    model.save_weights(MODEL_WGHTS_SAVE_PATH)
    model.evaluate(x_test, y_test, verbose=2)

    save_lenet_keras_weights(model=model)

    if plot_history:
        _plot_history(history=history)

    return model


def _plot_history(history):
    # If you have problems with matplotlib try this
    # import matplotlib
    # matplotlib.use('TkAgg')  # to get rid of runtime error
    import matplotlib.pyplot as plt
    # Plot training & validation accuracy values
    plt.figure()
    plt.plot(history.history['accuracy'])
    plt.plot(history.history['val_accuracy'])
    plt.title('Model accuracy')
    plt.ylabel('Accuracy')
    plt.xlabel('Epoch')
    plt.legend(['Train', 'Test'], loc='upper left')

    # Plot training & validation loss values
    plt.figure()
    plt.plot(history.history['loss'])
    plt.plot(history.history['val_loss'])
    plt.title('Model loss')
    plt.ylabel('Loss')
    plt.xlabel('Epoch')
    plt.legend(['Train', 'Test'], loc='upper left')
    plt.show()


def load_keras() -> keras.Model:
    if not os.path.exists(KERAS_CONFIG_FILE) or not os.path.exists(KERAS_WEIGHTS_FILE):
        raise RuntimeError("There is no trained model data! (or the model might have the wrong filename?)")

    # Reload the model from the 2 files we saved
    with open(KERAS_CONFIG_FILE) as json_file:
        json_config = json_file.read()

    model = keras.models.model_from_json(json_config)
    model.load_weights(KERAS_WEIGHTS_FILE)
    return model


def save_keras_weights(kmodel):
    for l_ix, layer in enumerate(kmodel.layers):
        # print(layer.get_config(), layer.get_weights())
        for w_ix, weight in enumerate(layer.get_weights()):
            # T
            vals = weight.flatten(order='C')  # Save to np format
            np.savetxt(os.path.join(EXPORT_DIR, 'k_{}_{}_{}.txt'.format(l_ix, layer.name, w_ix)), vals,
                       header=str(weight.shape))


def save_lenet_keras_weights(model):
    model.weights[0].numpy()
    model.weights[1].numpy()
    model.weights[2].numpy()
    model.weights[3].numpy()
    model.weights[4].numpy()
    model.weights[5].numpy()
    model.weights[6].numpy()
    model.weights[7].numpy()

    # Save Binary
    np.save(file=os.path.join(EXPORT_DIR, 'k_cn1.weight'), arr=model.weights[0].numpy())
    np.save(file=os.path.join(EXPORT_DIR, 'k_cn1.bias'), arr=model.weights[1].numpy())
    np.save(file=os.path.join(EXPORT_DIR, 'k_cn2.weight'), arr=model.weights[2].numpy())
    np.save(file=os.path.join(EXPORT_DIR, 'k_cn2.bias'), arr=model.weights[3].numpy())
    np.save(file=os.path.join(EXPORT_DIR, 'k_fc1.weight'), arr=model.weights[4].numpy())
    np.save(file=os.path.join(EXPORT_DIR, 'k_fc1.bias'), arr=model.weights[5].numpy())
    np.save(file=os.path.join(EXPORT_DIR, 'k_fc2.weight'), arr=model.weights[6].numpy())
    np.save(file=os.path.join(EXPORT_DIR, 'k_fc2.bias'), arr=model.weights[7].numpy())

    # Save as TXT
    np.savetxt(fname=os.path.join(EXPORT_DIR, 'k_cn1.weight.txt'), X=model.weights[0].numpy().flatten(),header=str(model.weights[0].numpy().shape))
    np.savetxt(fname=os.path.join(EXPORT_DIR, 'k_cn1.bias.txt'), X=model.weights[1].numpy().flatten(),header=str(model.weights[1].numpy().shape))
    np.savetxt(fname=os.path.join(EXPORT_DIR, 'k_cn2.weight.txt'), X=model.weights[2].numpy().flatten(),header=str(model.weights[2].numpy().shape))
    np.savetxt(fname=os.path.join(EXPORT_DIR, 'k_cn2.bias.txt'), X=model.weights[3].numpy().flatten(),header=str(model.weights[3].numpy().shape))
    np.savetxt(fname=os.path.join(EXPORT_DIR, 'k_fc1.weight.txt'), X=model.weights[4].numpy().flatten(),header=str(model.weights[4].numpy().shape))
    np.savetxt(fname=os.path.join(EXPORT_DIR, 'k_fc1.bias.txt'), X=model.weights[5].numpy().flatten(),header=str(model.weights[5].numpy().shape))
    np.savetxt(fname=os.path.join(EXPORT_DIR, 'k_fc2.weight.txt'), X=model.weights[6].numpy().flatten(),header=str(model.weights[6].numpy().shape))
    np.savetxt(fname=os.path.join(EXPORT_DIR, 'k_fc2.bias.txt'), X=model.weights[7].numpy().flatten(),header=str(model.weights[7].numpy().shape))


if __name__ == '__main__':
    # Add argument parsing to start it from the command line
    # parser = argparse.ArgumentParser()
    # parser.add_argument("plot_history", help="Print the training history using matplotlib",
    #                     default=PRINT_HISTORY_DEFAULT)
    # parser.add_argument()
    # args = parser.parse_args(args=sys.argv)
    # plot_history = args.plot_history
    global model
    model = train()
