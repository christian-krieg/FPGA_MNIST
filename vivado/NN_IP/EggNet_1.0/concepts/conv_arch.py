import numpy as np

def convolution2d(image, kernel, bias):
    m, n = kernel.shape
    if (m == n):
        y, x = image.shape
        y = y - m + 1
        x = x - m + 1
        new_image = np.zeros((y,x))
        for i in range(y):
            for j in range(x):
                new_image[i][j] = np.sum(image[i:i+m, j:j+m]*kernel) + bias
    return new_image


# Define Input Image Data
I = np.array([
    1,4,7,
    2,5,8,
    3,6,9,
]).reshape((3,3))



# Define Weights
W = np.array([
    2,2,2,
    2,2,2,
    2,2,2,
]).reshape((3,3))

Ipad = np.pad(I, pad_width=(1,1))
Y = convolution2d(Ipad,W,0)

Y1 = np.zeros(shape=(3,5))
Y2 = np.zeros(shape=(3,3))

Y2[1,0] = np.sum(I[:,:-1]*W[:,:-1])
Y2[1,1] = np.sum(I*W)
Y2[1,2] = np.sum(I[:,1:]*W[:,1:])



w1 = W[:,0]
w2 = W[:,1]
w3 = W[:,2]

i1 = I[:,0]
i2 = I[:,1]
i3 = I[:,2]



a3_1 = 0
a3_2 = 0
a3_3 = 0

type = 'conv'
# type = 'fc'

for i in range(0,5):
    i_patch = Ipad[1:-1,i]
    
    # MUL
    z1_1 = w1 * i_patch
    z1_2 = w2 * i_patch
    z1_3 = w3 * i_patch

    # ADD
    z2_1 = np.sum(z1_1)
    z2_2 = np.sum(z1_2)
    z2_3 = np.sum(z1_3)


    if type == 'conv':
        # ACCUM + SHIFT
        Y1[1,i] = a3_3 + z2_3
        a3_3 = a3_2 + z2_2
        a3_2 = a3_1 + z2_1
        a3_1 = 0
    elif type == 'fc':
        # ONLY ACCUM
        a3_3 = a3_3 + z2_3
        a3_2 = a3_2 + z2_2
        a3_1 = a3_1 + z2_1
    else:
        raise Exception()
    
    
    


print(Y)
print(Y1)