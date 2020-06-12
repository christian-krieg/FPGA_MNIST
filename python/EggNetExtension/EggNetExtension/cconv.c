#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <math.h>

#include "NNExtension.h"
#include "dbg.h"
#include "chelper.h"

/**
 * @brief Conv2D with Shifts
 *
 */
int conv2d_3x3_shift(const uint8_t* __restrict data_in,
                     int batch,
                     int in_h,
                     int in_w,
                     int in_ch,
                     const uint8_t* __restrict kernel_shift,
                     int fh_sh,
                     int fw_sh,
                     int kin_ch_sh,
                     int kout_ch_sh,
                     const uint8_t* __restrict kernel_sign,
                     int fh_s,
                     int fw_s,
                     int kin_ch_s,
                     int kout_ch_s,
                     const int16_t* __restrict bias,
                     int bin_ch,
                     int bout_ch,
                     int input_exponent,
                     int kernel_out_exponent,
                     int channel_out_exponent,
                     int stride,
                     uint8_t** __restrict pdata_out,
                     int* pbatch_out,
                     int* pout_h,
                     int* pout_w,
                     int* pout_ch)
{
    int return_value = 0;
    // -- Setup values
    const int batch_out = batch;
    const int out_h = in_h;
    const int out_w = in_w;
    const int out_ch = kout_ch_sh;
    const int fh2 = (int)((fh_sh - 1) / 2);   // calculate the half filter heigth, odd filter size is assumed
    const int fw2 = (int)((fw_sh - 1) / 2);   // calculate the half filter width, odd filter size is assumed
    const int kernel_exp_shift =
    input_exponent - kernel_out_exponent;   // example input Q8.8 output Q8.6 --> shift to the right by 2
    const int channel_exp_shift = input_exponent - channel_out_exponent;
    const int underflow_shift_limit = (-1) * pow(2, kernel_exp_shift) - 1;
    uint8_t*  data_out = NULL;

    // -- Debug Infos
    debug("data_in     = [%d, %d, %d, %d]", batch, in_h, in_w, in_ch);
    debug("kernel_shift      = [%d, %d, %d, %d]", fh_sh, fw_sh, kin_ch_sh, kout_ch_sh);
    debug("kernel sgn  = [%d, %d, %d, %d]", fh_s, fw_s, kin_ch_s, kout_ch_s);
    debug("bias        = [%d, %d]", kin_ch_s, kout_ch_s);
    debug("data_out    = [%d, %d, %d, %d]", batch_out, out_h, out_w, out_ch);

    // ----- Input Checking & Error Handling
    CHECK(kin_ch_sh == in_ch,
          "Dimension mismatch, number of input channels must be equal to number "
          "of input filter weights");

    CHECK_AND_SET(fh_sh == fh_s, return_value, NNE_ERROR_DIMENSION_MISMATCH,
                  "Inconsistent dimensions for 'fh' and 'fh_s'");
    CHECK_AND_SET(fw_sh == fw_s, return_value, NNE_ERROR_DIMENSION_MISMATCH,
                  "Inconsistent dimensions for 'fh' and 'fh_s'");
    CHECK_AND_SET(kin_ch_sh == kin_ch_s, return_value, NNE_ERROR_DIMENSION_MISMATCH,
                  "Inconsistent dimensions for 'fh' and 'fh_s'");
    CHECK_AND_SET(kout_ch_sh == kout_ch_s, return_value, NNE_ERROR_DIMENSION_MISMATCH,
                  "Inconsistent dimensions for 'kout_ch' and 'kout_ch_s'");
    CHECK_AND_SET(bin_ch == kin_ch_s, return_value, NNE_ERROR_DIMENSION_MISMATCH,
                  "Inconsistent dimensions for 'bin_ch' and 'kin_ch_s'");
    CHECK_AND_SET(bout_ch == kout_ch_s, return_value, NNE_ERROR_DIMENSION_MISMATCH,
                  "Inconsistent dimensions for 'bout_ch' and 'kout_ch_s'");

    // Check if the filter has an uneven width
    CHECK_AND_SET(1 == fh_sh % 2, return_value, NNE_ERROR_OTHER,
                  "Only odd numbers for filter size are supported. Input filter height is %d", fh_sh);
    CHECK_AND_SET(1 == fw_sh % 2, return_value, NNE_ERROR_OTHER,
                  "Only odd numbers for filter size are supported. Input filter width is %d", fw_sh);


    // Check if input pointer are valid
    PTR_CHECK(pdata_out);
    PTR_CHECK(pbatch_out);
    PTR_CHECK(pout_h);
    PTR_CHECK(pout_w);
    PTR_CHECK(pout_ch);
    // -- Allocate memory
    CREATE_4D_ARRAY(uint8_t, data_out, batch_out, out_h, out_w, out_ch);

    *pdata_out = data_out;
    *pbatch_out = batch_out;
    *pout_h = out_h;
    *pout_w = out_w;
    *pout_ch = out_ch;


    // --------------------------------
    // -- Main Logic
    // --------------------------------

    for (int b = 0; b < batch; b++) {
        for (int k = 0; k < kout_ch_sh; k++) {
            // TODO This can be
            // Calculate the individual output kernel
            for (int i = 0; i < in_h; i += stride) {
                for (int j = 0; j < in_w; j += stride) {
                    int channel_accum = 0;
                    // TODO This could be faster, if no if() statements would be handled inside the loops

                    // Sum up over the patch and convolve it
                    for (int q = 0; q < kin_ch_sh; q++) {
                        int kernel_accum = 0;

                        for (int di = 0; di < fh_sh; di++) {
                            for (int dj = 0; dj < fw_sh; dj++) {
                                int ix = i + di - fh2;
                                int jx = j + dj - fw2;


                                const int patch_h_start = MAX(0, i - fh2);   // goes from -1...26
                                const int patch_h_end = MIN(in_h, i - fh2 + fw_sh);   // goes from  2...29
                                const int patch_w_start = MAX(0, j - fw2);   // goes from -1...26
                                const int patch_w_end = MIN(in_w, j - fw2 + fw_sh);   // goes from  2...29

                                if (!((ix >= 0 && ix < in_h) && (jx >= 0 && jx < in_h))) {
                                    // skip computation, zero padding
                                    continue;
                                }
                                // accum += array_in[b][ix][jx][q] * kernel_in[di][dj][q][k];

                                // Shift
                                uint8_t _temp_val = DATA_IN(b, ix, jx, q) >> KERNEL_SH(di, dj, q, k);

                                // Check for the sign
                                if (KERNEL_SGN(di, dj, q, k) == 0) { kernel_accum += _temp_val; }
                                else {
                                    kernel_accum -= _temp_val;
                                }
                            }
                        }
                        kernel_accum += BIAS_CONV(q, k);
                        if (kernel_accum < 0 && kernel_accum > underflow_shift_limit) {
                            kernel_accum = 0;
                        }
                        else {
                            kernel_accum >>= kernel_exp_shift;   // shift to use pseudo floating point computations
                            kernel_accum = CLAMP(kernel_accum,-256, 255);   // clip kernel output to int9
                            channel_accum += kernel_accum;
                        }
                    }
                    //fprintf(stdout, "channel_accum[%d][%d][%d][%d]: %d\n", b, i, j, k,channel_accum);
                    if (channel_accum > 0) {
                        channel_accum >>= channel_exp_shift;
                        channel_accum = MIN(channel_accum, 255);
                    }
                    else {
                        channel_accum = 0;
                    }

                    DATA_OUT(b, i, j, k) = (uint8_t)channel_accum;
                }
            }
        }
    }
    return return_value;

error:
    free(data_out);
    *pdata_out = NULL;
    *pbatch_out = 0;
    *pout_ch = 0;
    *pout_h = 0;
    *pout_w = 0;
    return return_value;
}


int conv2d(const float* __restrict data_in,
           const int batch,
           const int in_h,
           const int in_w,
           const int in_ch,
           const float* __restrict kernel,
           const int fh,
           const int fw,
           const int kin_ch,
           const int kout_ch,
           const int stride,
           float**   pdata_out,
           int*      pbatch_out,
           int*      pout_h,
           int*      pout_w,
           int*      pout_ch)
{
    /*
    Perform a 2D convolution over a batch of tensors. This is equivalent to

     output[b, i, j, k] =
         sum_{di, dj, q} input[b, strides[1] * i + di, strides[2] * j + dj, q] *
                         filter[di, dj, q, k]

    :param data_in: Input data tensor with shape [batch, height, width, channels_in]
    :param kernel: Convolution kernel tensor with shape [kernel_height, kernel_width, channels_in, channels_out]
    :param stride: Integer for the step width
    :return: Tensor with shape [batch, height/stride, width/stride, channels_out]
    */

    int return_value = 0;

    const int batch_out = batch;
    const int out_h = in_h;
    const int out_w = in_w;
    const int out_ch = kout_ch;
    const int fh2 = (int)((fh - 1) / 2);   // calculate the half filter heigth, odd filter size is assumed
    const int fw2 = (int)((fw - 1) / 2);   // calculate the half filter width, odd filter size is assumed
    float* data_out = NULL;

    // Define Multidimensional array pointers
    // Unfortunatly not compatible with Windoof MSVC Compiler
    // To ease the compialtion process, those are replaced by macros
    // float(*array_in)[in_h][in_w][in_ch] = NULL;
    // float(*kernel_in)[fw][in_ch][out_ch] = NULL;
    // float(*array_out)[out_h][out_w][out_ch] = NULL;

    debug("data_in   = [%d, %d, %d, %d]", batch, in_h, in_w, in_ch);
    debug("kernel    = [%d, %d, %d, %d]", fh, fw, kin_ch, kout_ch);
    debug("data_out  = [%d, %d, %d, %d]", batch_out, out_h, out_w, out_ch);

    // ----- Input Checking & Error Handling

    CHECK(kin_ch == in_ch, "Dimension mismatch, number of input channels must be equal to number "
                           "of input filter weights");

    // Check if the filter has an uneven width
    CHECK_AND_SET(1 == fh % 2, return_value, NNE_ERROR_OTHER,
                  "Only odd numbers for filter size are supported. Input filter height is %d", fh);
    CHECK_AND_SET(1 == fw % 2, return_value, NNE_ERROR_OTHER,
                  "Only odd numbers for filter size are supported. Input filter width is %d", fw);


    // Check if input pointer are valid
    PTR_CHECK(pdata_out);
    PTR_CHECK(pbatch_out);
    PTR_CHECK(pout_h);
    PTR_CHECK(pout_w);
    PTR_CHECK(pout_ch);

    // Allocate memory
    CREATE_4D_ARRAY(float, data_out, batch_out, out_h, out_w, out_ch);

    *pdata_out = data_out;
    *pbatch_out = batch_out;
    *pout_h = out_h;
    *pout_w = out_w;
    *pout_ch = out_ch;

    // Assing Multi-Dim Array Pointers for easy access
    // array_in = (float(*)[in_h][in_w][in_ch])data_in;
    // kernel_in = (float(*)[fw][in_ch][out_ch])kernel;
    // array_out = (float(*)[out_h][out_w][out_ch])data_out;


    // output[b, i, j, k] =
    //     sum_{di, dj, q} input[b, strides[1] * i + di, strides[2] * j + dj, q] *
    //                     filter[di, dj, q, k]
    for (int b = 0; b < batch; b++) {
        for (int k = 0; k < kout_ch; k++) {
            // Calculate the individual output kernel
            for (int i = 0; i < in_h; i += stride) {
                for (int j = 0; j < in_w; j += stride) {
                    float accum = 0.0;
                    // Sum up over the patch and convolve it
                    for (int di = 0; di < fh; di++) {
                        for (int dj = 0; dj < fw; dj++) {
                            int ix = i + di - fh2;
                            int jx = j + dj - fw2;

                            const int patch_h_start = MAX(0, i - fh2);         // goes from -1...26
                            const int patch_h_end = MIN(in_h, i - fh2 + fw);   // goes from  2...29
                            const int patch_w_start = MAX(0, j - fw2);         // goes from -1...26
                            const int patch_w_end = MIN(in_w, j - fw2 + fw);   // goes from  2...29


                            if (!((ix >= 0 && ix < in_h) && (jx >= 0 && jx < in_h))) {
                                // skip computation, zero padding
                                continue;
                            }
                            for (int q = 0; q < kin_ch; q++) {
                                accum += DATA_IN(b, ix, jx, q) + KERNEL(di, dj, q, k);
                                // accum += array_in[b][ix][jx][q] * kernel_in[di][dj][q][k];
                            }
                        }
                    }
                    DATA_OUT(b, i, j, k) = accum;
                    // array_out[b][i][j][k] = accum;
                }
            }
        }
    }

    return return_value;

    // Jump label in case of errors
error:
    return return_value;
}

/**
 * @brief Implementation of a convolution with a 3x3 kernel
 *
 * @param data_in tensor with shape [batch, in_h, in_w, in_ch]
 * @param batch
 * @param in_h
 * @param in_w
 * @param in_ch
 * @param kernel tensor with shape [fh, fw, kin_ch, kout_ch]
 * @param fh
 * @param fw
 * @param kin_ch
 * @param kout_ch
 * @param pdata_out pointer to tensor with shape [batch, in_h, in_w, in_ch]
 * @param pbatch_out
 * @param pout_h
 * @param pout_w
 * @param pout_ch
 * @return int
 */
int conv2d_3x3(const float* __restrict data_in,
               const int batch,
               const int in_h,
               const int in_w,
               const int in_ch,
               const float* __restrict kernel,
               const int fh,
               const int fw,
               const int kin_ch,
               const int kout_ch,
               float**   pdata_out,
               int*      pbatch_out,
               int*      pout_h,
               int*      pout_w,
               int*      pout_ch)
{
    int return_value = 0;

    const int batch_out = batch;
    const int out_h = in_h;
    const int out_w = in_w;
    const int out_ch = kout_ch;
    float*    data_out = NULL;

    // Define Multidimensional array pointers
    // Unfortunatly not compatible with Windoof MSVC Compiler
    // // To ease the compialtion process, those are replaced by macros
    // float(*array_in)[in_h][in_w][in_ch] = NULL;
    // float(*kernel_in)[fw][in_ch][out_ch] = NULL;
    // float(*array_out)[out_h][out_w][out_ch] = NULL;

    // Assing Multi-Dim Array Pointers for easy access

    // Allocate memory
    CREATE_4D_ARRAY(float, data_out, batch_out, out_h, out_w, out_ch);

    // array_in = (float(*)[in_h][in_w][in_ch])data_in;
    // kernel_in = (float(*)[fw][in_ch][out_ch])kernel;
    // array_out = (float(*)[out_h][out_w][out_ch])data_out;


    debug("data_in   = [%d, %d, %d, %d]", batch, in_h, in_w, in_ch);
    debug("kernel    = [%d, %d, %d, %d]", fh, fw, kin_ch, kout_ch);
    debug("data_out  = [%d, %d, %d, %d]", batch_out, out_h, out_w, out_ch);

    // ----- Input Checking & Error Handling
    assert(fh == 3);
    assert(fw == 3);
    assert(kin_ch == in_ch);

    // Check if input pointer are valid
    PTR_CHECK(pdata_out);
    PTR_CHECK(pbatch_out);
    PTR_CHECK(pout_h);
    PTR_CHECK(pout_w);
    PTR_CHECK(pout_ch);


    // Assign values
    *pdata_out = data_out;
    *pbatch_out = batch_out;
    *pout_h = out_h;
    *pout_w = out_w;
    *pout_ch = out_ch;


    // First: Calculate the valid padding
    for (int b = 0; b < batch; b++) {
        for (int kout_ch = 0; kout_ch < out_ch; kout_ch++) {
            for (int i = 1; i < in_h - 1; i++) {
                for (int j = 1; j < in_w - 1; j++) {
                    float a = 0.0;
                    for (int k = 0; k < in_ch; k++) {
                        // a += kernel_in[0][0][k][kout_ch] * array_in[b][i - 1][j - 1][k];
                        // a += kernel_in[0][1][k][kout_ch] * array_in[b][i - 1][j][k];
                        // a += kernel_in[0][2][k][kout_ch] * array_in[b][i - 1][j + 1][k];
                        // a += kernel_in[1][0][k][kout_ch] * array_in[b][i][j - 1][k];
                        // a += kernel_in[1][1][k][kout_ch] * array_in[b][i][j][k];
                        // a += kernel_in[1][2][k][kout_ch] * array_in[b][i][j + 1][k];
                        // a += kernel_in[2][0][k][kout_ch] * array_in[b][i + 1][j - 1][k];
                        // a += kernel_in[2][1][k][kout_ch] * array_in[b][i + 1][j][k];
                        // a += kernel_in[2][2][k][kout_ch] * array_in[b][i + 1][j + 1][k];

                        // A 3x3 Kernel goes from -1 to 1
                        a += KERNEL(0, 0, k, kout_ch) * DATA_IN(b, i - 1, j - 1, k);
                        a += KERNEL(0, 1, k, kout_ch) * DATA_IN(b, i - 1, j, k);
                        a += KERNEL(0, 2, k, kout_ch) * DATA_IN(b, i - 1, j + 1, k);
                        a += KERNEL(1, 0, k, kout_ch) * DATA_IN(b, i, j - 1, k);
                        a += KERNEL(1, 1, k, kout_ch) * DATA_IN(b, i, j, k);
                        a += KERNEL(1, 2, k, kout_ch) * DATA_IN(b, i, j + 1, k);
                        a += KERNEL(2, 0, k, kout_ch) * DATA_IN(b, i + 1, j - 1, k);
                        a += KERNEL(2, 1, k, kout_ch) * DATA_IN(b, i + 1, j, k);
                        a += KERNEL(2, 2, k, kout_ch) * DATA_IN(b, i + 1, j + 1, k);
                    }
                    // array_out[b][i][j][kout_ch] = a;
                    DATA_OUT(b, i, j, kout_ch) = a;
                }
            }

            // Calculate Corners
            const int H = in_h - 1;
            const int W = in_w - 1;
            float     c_ul = 0.0, c_ur = 0.0, c_bl = 0.0, c_br = 0.0;
            for (int k = 0; k < in_ch; k++) {
                // Corner Top Left
                c_ul += KERNEL(1, 1, k, kout_ch) * DATA_IN(b, 0, 0, k);
                c_ul += KERNEL(1, 2, k, kout_ch) * DATA_IN(b, 0, 1, k);
                c_ul += KERNEL(2, 1, k, kout_ch) * DATA_IN(b, 1, 0, k);
                c_ul += KERNEL(2, 2, k, kout_ch) * DATA_IN(b, 1, 1, k);
                // Corner Top Right
                c_ur += KERNEL(1, 0, k, kout_ch) * DATA_IN(b, 0, W - 1, k);
                c_ur += KERNEL(1, 1, k, kout_ch) * DATA_IN(b, 0, W, k);
                c_ur += KERNEL(2, 0, k, kout_ch) * DATA_IN(b, 1, W - 1, k);
                c_ur += KERNEL(2, 1, k, kout_ch) * DATA_IN(b, 1, W, k);
                // Corner Bottom Left
                c_bl += KERNEL(0, 1, k, kout_ch) * DATA_IN(b, H - 1, 0, k);
                c_bl += KERNEL(0, 2, k, kout_ch) * DATA_IN(b, H - 1, 1, k);
                c_bl += KERNEL(1, 1, k, kout_ch) * DATA_IN(b, H, 0, k);
                c_bl += KERNEL(1, 2, k, kout_ch) * DATA_IN(b, H, 1, k);
                // Corner Bottom Right
                c_br += KERNEL(0, 0, k, kout_ch) * DATA_IN(b, H - 1, W - 1, k);
                c_br += KERNEL(0, 1, k, kout_ch) * DATA_IN(b, H - 1, W, k);
                c_br += KERNEL(1, 0, k, kout_ch) * DATA_IN(b, H, W - 1, k);
                c_br += KERNEL(1, 1, k, kout_ch) * DATA_IN(b, H, W, k);
            }
            DATA_OUT(b, 0, 0, kout_ch) = c_ul;
            DATA_OUT(b, 0, W, kout_ch) = c_ur;
            DATA_OUT(b, H, 0, kout_ch) = c_bl;
            DATA_OUT(b, H, W, kout_ch) = c_br;


            // Vertical Lines
            for (int i = 1; i < in_h - 1; i++) {
                // Left Side
                float a_l = 0;
                for (int k = 0; k < in_ch; k++) {
                    a_l += KERNEL(0, 1, k, kout_ch) * DATA_IN(b, i - 1, 0, k);
                    a_l += KERNEL(0, 2, k, kout_ch) * DATA_IN(b, i - 1, 1, k);
                    a_l += KERNEL(1, 1, k, kout_ch) * DATA_IN(b, i, 0, k);
                    a_l += KERNEL(1, 2, k, kout_ch) * DATA_IN(b, i, 1, k);
                    a_l += KERNEL(2, 1, k, kout_ch) * DATA_IN(b, i + 1, 0, k);
                    a_l += KERNEL(2, 2, k, kout_ch) * DATA_IN(b, i + 1, 1, k);
                }
                DATA_OUT(b, i, 0, kout_ch) = a_l;

                // Right Side
                float a_r = 0;
                for (int k = 0; k < in_ch; k++) {
                    a_r += KERNEL(0, 0, k, kout_ch) * DATA_IN(b, i - 1, W - 1, k);
                    a_r += KERNEL(0, 1, k, kout_ch) * DATA_IN(b, i - 1, W, k);
                    a_r += KERNEL(1, 0, k, kout_ch) * DATA_IN(b, i, W - 1, k);
                    a_r += KERNEL(1, 1, k, kout_ch) * DATA_IN(b, i, W, k);
                    a_r += KERNEL(2, 0, k, kout_ch) * DATA_IN(b, i + 1, W - 1, k);
                    a_r += KERNEL(2, 1, k, kout_ch) * DATA_IN(b, i + 1, W, k);
                }
                DATA_OUT(b, i, W, kout_ch) = a_r;
            }

            // Horizontal Lines
            for (int i = 1; i < in_w - 1; i++) {
                float a_l = 0, a_r = 0;
                for (int k = 0; k < in_ch; k++) {
                    // Top Side
                    a_l += KERNEL(1, 0, k, kout_ch) * DATA_IN(b, 0, i - 1, k);
                    a_l += KERNEL(1, 1, k, kout_ch) * DATA_IN(b, 0, i, k);
                    a_l += KERNEL(1, 2, k, kout_ch) * DATA_IN(b, 0, i + 1, k);
                    a_l += KERNEL(2, 0, k, kout_ch) * DATA_IN(b, 1, i - 1, k);
                    a_l += KERNEL(2, 1, k, kout_ch) * DATA_IN(b, 1, i, k);
                    a_l += KERNEL(2, 2, k, kout_ch) * DATA_IN(b, 1, i + 1, k);

                    // Bottom Side
                    a_r += KERNEL(0, 0, k, kout_ch) * DATA_IN(b, H - 1, i - 1, k);
                    a_r += KERNEL(0, 1, k, kout_ch) * DATA_IN(b, H - 1, i, k);
                    a_r += KERNEL(0, 2, k, kout_ch) * DATA_IN(b, H - 1, i + 1, k);
                    a_r += KERNEL(1, 0, k, kout_ch) * DATA_IN(b, H, i - 1, k);
                    a_r += KERNEL(1, 1, k, kout_ch) * DATA_IN(b, H, i, k);
                    a_r += KERNEL(1, 2, k, kout_ch) * DATA_IN(b, H, i + 1, k);
                }
                DATA_OUT(b, 0, i, kout_ch) = a_l;
                DATA_OUT(b, H, i, kout_ch) = a_r;
            }
        }
    }

    return return_value;

error:
    // Clean up allocated data in case of error
    free(*pdata_out);
    *pdata_out = NULL;
    return return_value;
}

/*******************************************************************************************************
 *
 * Macro Meta Programming Section
 *
 *******************************************************************************************************/

#define new_conv_protofunc_definition(dtype)                                                            \
    int conv2d_##dtype(const dtype* __restrict data_in, const int batch, const int in_h,                \
                       const int in_w, const int in_ch, const dtype* __restrict kernel, const int fh,   \
                       const int fw, const int kin_ch, const int kout_ch, const int stride,             \
                       dtype** pdata_out, int* pbatch_out, int* pout_h, int* pout_w, int* pout_ch)      \
    {                                                                                                   \
        int       return_value = 0;                                                                     \
        const int batch_out = batch;                                                                    \
        const int out_h = in_h;                                                                         \
        const int out_w = in_w;                                                                         \
        const int out_ch = kout_ch;                                                                     \
        const int fh2 = (int)((fh - 1) / 2);                                                            \
        const int fw2 = (int)((fw - 1) / 2);                                                            \
        dtype*    data_out = NULL;                                                                      \
        debug("data_in   = [%d, %d, %d, %d]", batch, in_h, in_w, in_ch);                                \
        debug("kernel    = [%d, %d, %d, %d]", fh, fw, kin_ch, kout_ch);                                 \
        debug("data_out  = [%d, %d, %d, %d]", batch_out, out_h, out_w, out_ch);                         \
                                                                                                        \
        CHECK(kin_ch == in_ch,                                                                          \
              "Dimension mismatch, number of input channels must be equal to number "                   \
              "of input filter weights");                                                               \
        CHECK_AND_SET(1 == fh % 2, return_value, NNE_ERROR_OTHER,                                       \
                      "Only odd numbers for filter size are supported. Input filter height is %d", fh); \
        CHECK_AND_SET(1 == fw % 2, return_value, NNE_ERROR_OTHER,                                       \
                      "Only odd numbers for filter size are supported. Input filter width is %d", fw);  \
        PTR_CHECK(pdata_out);                                                                           \
                                                                                                        \
        PTR_CHECK(pbatch_out);                                                                          \
        PTR_CHECK(pout_h);                                                                              \
        PTR_CHECK(pout_w);                                                                              \
        PTR_CHECK(pout_ch);                                                                             \
        CREATE_4D_ARRAY(dtype, data_out, batch_out, out_h, out_w, out_ch);                              \
                                                                                                        \
        *pdata_out = data_out;                                                                          \
        *pbatch_out = batch_out;                                                                        \
        *pout_h = out_h;                                                                                \
        *pout_w = out_w;                                                                                \
        *pout_ch = out_ch;                                                                              \
                                                                                                        \
        for (int b = 0; b < batch; b++) {                                                               \
            for (int k = 0; k < kout_ch; k++) {                                                         \
                for (int i = 0; i < in_h; i += stride) {                                                \
                    for (int j = 0; j < in_w; j += stride) {                                            \
                        dtype accum = 0.0;                                                              \
                                                                                                        \
                        for (int di = 0; di < fh; di++) {                                               \
                            for (int dj = 0; dj < fw; dj++) {                                           \
                                int ix = i + di - fh2;                                                  \
                                int jx = j + dj - fw2;                                                  \
                                                                                                        \
                                const int patch_h_start = MAX(0, i - fh2);                              \
                                const int patch_h_end = MIN(in_h, i - fh2 + fw);                        \
                                const int patch_w_start = MAX(0, j - fw2);                              \
                                const int patch_w_end = MIN(in_w, j - fw2 + fw);                        \
                                                                                                        \
                                                                                                        \
                                if (!((ix >= 0 && ix < in_h) && (jx >= 0 && jx < in_h))) {              \
                                    continue;                                                           \
                                }                                                                       \
                                for (int q = 0; q < kin_ch; q++) {                                      \
                                    accum += DATA_IN(b, ix, jx, q) * KERNEL(di, dj, q, k);              \
                                }                                                                       \
                            }                                                                           \
                        }                                                                               \
                                                                                                        \
                        DATA_OUT(b, i, j, k) = accum;                                                   \
                    }                                                                                   \
                }                                                                                       \
            }                                                                                           \
        }                                                                                               \
                                                                                                        \
        return return_value;                                                                            \
                                                                                                        \
                                                                                                        \
    error:                                                                                              \
        return return_value;                                                                            \
    }


new_conv_protofunc_definition(float);
new_conv_protofunc_definition(double);
new_conv_protofunc_definition(int8_t);
new_conv_protofunc_definition(int16_t);
new_conv_protofunc_definition(int32_t);
new_conv_protofunc_definition(int64_t);
new_conv_protofunc_definition(uint8_t);
new_conv_protofunc_definition(uint16_t);
new_conv_protofunc_definition(uint32_t);
new_conv_protofunc_definition(uint64_t);

/*
#define new_conv_shift_protofunc_definition(dtype)                                                         \
    int conv2d_shift_##dtype(const dtype* __restrict data_in, const int batch, const int in_h,             \
                             const int in_w, const int in_ch, const dtype* __restrict kernel_shift,        \
                             const int fh_sh, const int fw_sh, const int kin_ch_sh,                        \
                             const int kout_ch_sh, const dtype* __restrict kernel_sign,                    \
                             const int fh_s, const int fw_s, const int kin_ch_s, const int kout_ch_s,      \
                             const __restrict uint16_t* bias, const int bin_ch, const int bout_ch,         \
                             const int input_exponent, const int kernel_out_exponent,                      \
                             const int channel_out_exponent, const int stride, dtype** pdata_out,          \
                             int* pbatch_out, int* pout_h, int* pout_w, int* pout_ch)                      \
    {                                                                                                      \                                                                     
        const int batch_out = batch;                                                                       \
        const int out_h = in_h;                                                                            \
        const int out_w = in_w;                                                                            \
        const int out_ch = kout_ch_sh;                                                                     \
        int       return_value = 0;   \   
        const int fh2 = (int)((fh_sh - 1) / 2);                                                            \
        const int fw2 = (int)((fw_sh - 1) / 2);                                                            \
        const int channel_exp_shift = input_exponent - channel_out_exponent;                               \
        const int underflow_shift_limit = (-1) * pow(2, kernel_exp_shift) - 1;                             \
        int*      data_out = NULL;                                                                         \
        debug("data_in = [%d, %d, %d, %d]", batch, in_h, in_w, in_ch);                                     \
        debug("kernel_shift = [%d, %d, %d, %d]", fh_sh, fw_sh, kin_ch_sh, kout_ch_sh);                     \
        debug("kernel sgn  = [%d, %d, %d, %d]", fh_s, fw_s, kin_ch_s, kout_ch_s);                          \
        debug("bias        = [%d, %d]", kin_ch_s, kout_ch_s);                                              \
        debug("data_out    = [%d, %d, %d, %d]", batch_out, out_h, out_w, out_ch);                          \
        CHECK(kin_ch_sh == in_ch, "Dimension mismatch, number of input channels must be equal to "         \
                                  "number of input filter weights");                                       \
        CHECK_AND_SET(fh_sh == fh_s, return_value, NNE_ERROR_DIMENSION_MISMATCH,                           \
                      "Inconsistent dimensions for 'fh' and 'fh_s'");                                      \
        CHECK_AND_SET(fw_sh == fw_s, return_value, NNE_ERROR_DIMENSION_MISMATCH,                           \
                      "Inconsistent dimensions for 'fh' and 'fh_s'");                                      \
        CHECK_AND_SET(kin_ch_sh == kin_ch_s, return_value, NNE_ERROR_DIMENSION_MISMATCH,                   \
                      "Inconsistent dimensions for 'fh' and 'fh_s'");                                      \
        CHECK_AND_SET(kout_ch_sh == kout_ch_s, return_value, NNE_ERROR_DIMENSION_MISMATCH,                 \
                      "Inconsistent dimensions for 'kout_ch' and 'kout_ch_s'");                            \
        CHECK_AND_SET(bin_ch == kin_ch_s, return_value, NNE_ERROR_DIMENSION_MISMATCH,                      \
                      "Inconsistent dimensions for 'bin_ch' and 'kin_ch_s'");                              \
        CHECK_AND_SET(bout_ch == kout_ch_s, return_value, NNE_ERROR_DIMENSION_MISMATCH,                    \
                      "Inconsistent dimensions for 'bout_ch' and 'kout_ch_s'");                            \
        CHECK_AND_SET(1 == fh_sh % 2, return_value, NNE_ERROR_OTHER,                                       \
                      "Only odd numbers for filter size are supported. Input filter height is %d", fh_sh); \
        CHECK_AND_SET(1 == fw_sh % 2, return_value, NNE_ERROR_OTHER,                                       \
                      "Only odd numbers for filter size are supported. Input filter width is %d", fw_sh);  \
        PTR_CHECK(pdata_out);                                                                              \
        PTR_CHECK(pbatch_out);                                                                             \
        PTR_CHECK(pout_h);                                                                                 \
        PTR_CHECK(pout_w);                                                                                 \
        PTR_CHECK(pout_ch);                                                                                \
        CREATE_4D_ARRAY(uint8_t, data_out, batch_out, out_h, out_w, out_ch);                               \
        *pdata_out = data_out;                                                                             \
        *pbatch_out = batch_out;                                                                           \
        *pout_h = out_h;                                                                                   \
        *pout_w = out_w;                                                                                   \
        *pout_ch = out_ch;                                                                                 \
        for (int b = 0; b < batch; b++) {                                                                  \
            fprintf(stdout, "Batch: %d\n", b);                                                             \
            for (int k = 0; k < kout_ch_sh; k++) {                                                         \
                fprintf(stdout, "Out Channel: %d\n", k);                                                   \
                for (int i = 0; i < in_h; i += stride) {                                                   \
                    for (int j = 0; j < in_w; j += stride) {                                               \
                        int channel_accum = 0;                                                             \
                        for (int q = 0; q < kin_ch_sh; q++) {                                              \
                            int kernel_accum = 0;                                                          \
                            for (int di = 0; di < fh_sh; di++) {                                           \
                                for (int dj = 0; dj < fw_sh; dj++) {                                       \
                                    int       ix = i + di - fh2;                                           \
                                    int       jx = j + dj - fw2;                                           \
                                    const int patch_h_start = MAX(0, i - fh2);                             \
                                    const int patch_h_end = MIN(in_h, i - fh2 + fw_sh);                    \
                                    const int patch_w_start = MAX(0, j - fw2);                             \
                                    const int patch_w_end = MIN(in_w, j - fw2 + fw_sh);                    \
                                    if (!((ix >= 0 && ix < in_h) && (jx >= 0 && jx < in_h))) {             \
                                        continue;                                                          \
                                    }                                                                      \
                                    uint8_t _temp_val = DATA_IN(b, ix, jx, q) >> KERNEL_S(di, dj, q, k);   \
                                    if (KERNEL_S(di, dj, q, k) == 0) {                                     \
                                        kernel_accum += _temp_val;                                         \
                                    }                                                                      \
                                    else {                                                                 \
                                        kernel_accum -= _temp_val;                                         \
                                    }                                                                      \
                                }                                                                          \
                            }                                                                              \
                            kernel_accum += BIAS_CONV(q, k);                                               \
                            if (kernel_accum < 0 && kernel_accum > underflow_shift_limit) {                \
                                kernel_accum = 0;                                                          \
                            }                                                                              \
                            else {                                                                         \
                                kernel_accum >>= kernel_exp_shift;                                         \
                                kernel_accum = MAX(kernel_accum, 255);                                     \
                                kernel_accum = MIN(kernel_accum, -256);                                    \
                                channel_accum += kernel_accum;                                             \
                            }                                                                              \
                        }                                                                                  \
                        if (channel_accum > 0) {                                                           \
                            channel_accum >>= channel_exp_shift;                                           \
                            channel_accum = MAX(channel_accum, 255);                                       \
                        }                                                                                  \
                        else {                                                                             \
                            channel_accum = 0;                                                             \
                        }                                                                                  \
                        DATA_OUT(b, i, j, k) = (uint8_t)channel_accum;                                     \
                    }                                                                                      \
                }                                                                                          \
            }                                                                                              \
        }                                                                                                  \
        return return_value;                                                                               \
    error:                                                                                                 \
        free(data_out);                                                                                    \
        *pdata_out = NULL;                                                                                 \
        *pbatch_out = 0;                                                                                   \
        *pout_ch = 0;                                                                                      \
        *pout_h = 0;                                                                                       \
        *pout_w = 0;                                                                                       \
        return return_value;                                                                               \
    }

new_conv_shift_protofunc_definition(int8_t);
new_conv_shift_protofunc_definition(int16_t);
new_conv_shift_protofunc_definition(int32_t);
new_conv_shift_protofunc_definition(int64_t);
new_conv_shift_protofunc_definition(uint8_t);
new_conv_shift_protofunc_definition(uint16_t);
new_conv_shift_protofunc_definition(uint32_t);
new_conv_shift_protofunc_definition(uint64_t);
*/