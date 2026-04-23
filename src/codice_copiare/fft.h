/*! \file fft.h
 * \author Gioele Giunta
 * \version 3.0
 * \since 2025
 * \brief Interfaccia del modulo fft
 */

#ifndef FFT_H
#define FFT_H
/* Librerie */
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

/* Headers specifici */
#include "complex_g3.h"
#include "global_parameters.h"

#ifdef __cplusplus
extern "C" {
#endif

/* C Library Headers */

/* Driver Headers */

/* Our Headers */

#define NN G_ARRAY_SIZE  /* Define the maximum FFT size, must be a power of 2 */

/**
 * \brief Simplified interface to perform FFT on a complex array of voltage levels
 * \param x Pointer to a complex array of voltage levels
 * \param N The number of samples in the array, should be a power of two
 * \returns A pointer to a global array representing the frequency spectrum of the input signal, note that this is not thread-safe
 * 
 * This function provides a simplified interface to perform the FFT, suitable for straightforward use cases. It wraps the operations of computing twiddle factors and executing the FFT into a single call, managing all intermediate storage internally. This is ideal for single-threaded applications where ease of use is more critical than modularity.
*/
complex_g3_t *FFT_simple(complex_g3_t *x, int N);

#ifdef __cplusplus
}
#endif

#endif
