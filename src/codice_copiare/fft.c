/*! \file fft.c
 * \author Gioele Giunta
 * \version 1.7
 * \since 2025
 * \brief Implementazione del modulo fft
 */

/* Headers specifici */
#include "fft.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Header */

complex_g3_t out[NN];	/* Output array for FFT results */
complex_g3_t scratch[NN];	/* Scratch space for FFT computation */
complex_g3_t twiddles[NN];	/* Twiddle factors */

/**
 * \brief Calculates the twiddle factors for the FFT
 * \param N The number of samples in the FFT, which should be a power of two
 * \returns void
 * 
 * This function calculates the twiddle factors, which are complex exponentials used to 
 * reduce the number of computations in the Fast Fourier Transform (FFT). These factors 
 * are needed to efficiently combine the DFT results of subproblems in the FFT algorithm.
*/
/**
 * @brief Funzione FFT_get_twiddle_factors.
 * @param N Parametro N.
 */
void FFT_get_twiddle_factors (int N)
{
	int k;

	for (k = 0; k < N; ++k)
	{
		double angle = -2.0 * G_PI * k / N;

		twiddles[k].re = cos(angle);
		twiddles[k].im = sin(angle);
	}
}


/**
 * \brief Performs the actual FFT on an array of complex numbers
 * \param x Pointer to a complex array of input data
 * \param N The number of samples in the array, should be a power of two
 * \param X Output pointer to an array where the frequency spectrum of the input signal will be stored
 * \param scratch Scratch space used for intermediate calculations
 * \param twiddles Twiddle factors precomputed for the FFT size N
 * \returns A pointer to an array of complex numbers representing the frequency spectrum of the input signal
 * 
 * This function performs the Cooley-Tukey FFT algorithm on a complex data array. It recursively divides the 
 * DFT into smaller DFTs, utilizing symmetry and periodicity properties of the DFT through the use of twiddle factors. 
 * This function uses an in-place algorithm where the results are computed directly in the input arrays using the `scratch` 
 * space for efficient memory usage.
*/
/**
 * @brief Funzione FFT_calculate.
 * @param x Parametro x.
 * @param N Parametro N.
 * @param X Parametro X.
 * @param scratch Parametro scratch.
 * @param twiddles Parametro twiddles.
 */
void FFT_calculate (complex_g3_t *x, long N, complex_g3_t *X, complex_g3_t *scratch, complex_g3_t *twiddles)
{
	int k, m, n;
	int skip;
	boolean evenIteration = N & 0x55555555;
	complex_g3_t* E;
	complex_g3_t* Xp, *Xp2, *Xstart;

	if (N == 1)
	{
		X[0] = x[0];
		return;
	}

	E = x;

	for (n = 1; n < N; n = n * 2)
	{
		Xstart = evenIteration ? scratch : X;
		skip = N / (2 * n);
		Xp = Xstart;
		Xp2 = Xstart + N / 2;

		for (k = 0; k < n; k++)
		{
			double tim = twiddles[k * skip].im;
			double tre = twiddles[k * skip].re;

			for (m = 0; m < skip; ++m)
			{
				complex_g3_t* D = E + skip;
				double dre = D->re * tre - D->im * tim;
				double dim = D->re * tim + D->im * tre;

				Xp->re = E->re + dre;
				Xp->im = E->im + dim;
				Xp2->re = E->re - dre;
				Xp2->im = E->im - dim;

				++Xp;
				++Xp2;
				++E;
			}

			E += skip;
		}

		E = Xstart;
		evenIteration = !evenIteration;
	}
}

/**
 * \brief Simplified interface to perform FFT on a complex array of voltage levels
 * \param x Pointer to a complex array of voltage levels
 * \param N The number of samples in the array, should be a power of two
 * \returns A pointer to a global array representing the frequency spectrum of the input signal, note that this is not thread-safe
 * 
 * This function provides a simplified interface to perform the FFT, suitable for straightforward use cases. It wraps the operations of computing twiddle factors and executing the FFT into a single call, managing all intermediate storage internally. This is ideal for single-threaded applications where ease of use is more critical than modularity.
*/
/**
 * @brief Funzione FFT_simple.
 * @param x Parametro x.
 * @param N Parametro N.
 * @return Valore di ritorno.
 */
complex_g3_t* FFT_simple (complex_g3_t* x, int N)
{
	FFT_get_twiddle_factors(N);

	FFT_calculate(x, N, out, scratch, twiddles);

	return out;	/* Note: this returns a pointer to a global array */
}

#ifdef __cplusplus
}
#endif
