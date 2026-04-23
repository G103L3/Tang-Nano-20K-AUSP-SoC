/*! \file gtzl.c
 * \author Gioele Giunta
 * \version 2.2
 * \since 2025
 * \brief Implementazione del modulo gtzl
 */

/* Librerie */
#include <math.h>

/* Headers specifici */
#include "global_parameters.h"
#include "gtzl.h"

 
 /* Constants */
 #ifndef M_PI
 #define M_PI 3.141592654
 #endif
 
 #define G3_2PI (2 * M_PI)
 #define FS G_SAMPLE_RATE  /* Sample Rate */
 #define GTZ_AR_SZ 1020     /* # elements to be used by the Goertzel algorithm */
 
 #define DTMF_FRQS {697, 770, 852, 941, 1209, 1336, 1477, 1633, 2000, 4000}  /* DTMF Frequencies */
 
 /* k = round((GTZ_AR_SZ * freq) / FS) */
 #define K_0697 round((GTZ_AR_SZ * 697) / FS)
 #define K_0770 round((GTZ_AR_SZ * 770) / FS)
 #define K_0852 round((GTZ_AR_SZ * 852) / FS)
 #define K_0941 round((GTZ_AR_SZ * 941) / FS)
 #define K_1209 round((GTZ_AR_SZ * 1209) / FS)
 #define K_1336 round((GTZ_AR_SZ * 1336) / FS)
 #define K_1477 round((GTZ_AR_SZ * 1477) / FS)
 #define K_1633 round((GTZ_AR_SZ * 1633) / FS)
 #define K_2000 round((GTZ_AR_SZ * 18000) / FS)
 #define K_4000 round((GTZ_AR_SZ * 18000) / FS)
 
 /* w = ((2 * G3_PI) / GTZ_AR_SZ) * K_XXXX */
 #define W_0697 ((G3_2PI / GTZ_AR_SZ) * K_0697)
 #define W_0770 ((G3_2PI / GTZ_AR_SZ) * K_0770)
 #define W_0852 ((G3_2PI / GTZ_AR_SZ) * K_0852)
 #define W_0941 ((G3_2PI / GTZ_AR_SZ) * K_0941)
 #define W_1209 ((G3_2PI / GTZ_AR_SZ) * K_1209)
 #define W_1336 ((G3_2PI / GTZ_AR_SZ) * K_1336)
 #define W_1477 ((G3_2PI / GTZ_AR_SZ) * K_1477)
 #define W_1633 ((G3_2PI / GTZ_AR_SZ) * K_1633)
 #define W_2000 ((G3_2PI / GTZ_AR_SZ) * K_2000)
 #define W_4000 ((G3_2PI / GTZ_AR_SZ) * K_4000)
 
 
 /* COS_xxxx = cos(W_XXXX) */
 #define COS_0697 cos(W_0697)
 #define COS_0770 cos(W_0770)
 #define COS_0852 cos(W_0852)
 #define COS_0941 cos(W_0941)
 #define COS_1209 cos(W_1209)
 #define COS_1336 cos(W_1336)
 #define COS_1477 cos(W_1477)
 #define COS_1633 cos(W_1633)
 #define COS_2000 cos(W_2000)
 #define COS_4000 cos(W_4000)
 
 /* SIN_xxxx = sin(W_XXXX) */
 #define SIN_0697 sin(W_0697)
 #define SIN_0770 sin(W_0770)
 #define SIN_0852 sin(W_0852)
 #define SIN_0941 sin(W_0941)
 #define SIN_1209 sin(W_1209)
 #define SIN_1336 sin(W_1336)
 #define SIN_1477 sin(W_1477)
 #define SIN_1633 sin(W_1633)
 #define SIN_2000 sin(W_2000)
 #define SIN_4000 sin(W_4000)
 
 /* Coefficient equation: CEF_XXXX = 2 * COS_XXXX */
 #define CEF_0697 (2 * COS_0697)
 #define CEF_0770 (2 * COS_0770)
 #define CEF_0852 (2 * COS_0852)
 #define CEF_0941 (2 * COS_0941)
 #define CEF_1209 (2 * COS_1209)
 #define CEF_1336 (2 * COS_1336)
 #define CEF_1477 (2 * COS_1477)
 #define CEF_1633 (2 * COS_1633)
 #define CEF_2000 (2 * COS_2000)
 #define CEF_4000 (2 * COS_4000)
 
 /* Function Declarations */
 double mag_eqn_optimised(double q1, double q2, double cef);
 
 /* Goertzel Algorithm Implementation */
/**
 * @brief Funzione goertzel.
 * @param signal Parametro signal.
 * @param amplitudes[10] Parametro amplitudes[10].
 * @return Valore di ritorno.
 */
 int goertzel(complex_g3_t* signal, double amplitudes[10]) {
	
	 double q1[10] = {0};
	 double q2[10] = {0};
	 double q0[10] = {0};
	 double cef[10] = {CEF_0697, CEF_0770, CEF_0852, CEF_0941, CEF_1209, CEF_1336, CEF_1477, CEF_1633, CEF_2000, CEF_4000};
 
	 for (unsigned short i = 0; i < GTZ_AR_SZ; i++) {
		 for (int f = 0; f < 10; f++) {
			 q0[f] = (cef[f] * q1[f]) - q2[f] + signal[i].re;
			 q2[f] = q1[f];
			 q1[f] = q0[f];
		 }
	 }
 
	 for (int f = 0; f < 10; f++) {
		 amplitudes[f] = mag_eqn_optimised(q1[f], q2[f], cef[f]);
	 }
 
	 return 0;
 }
 
 /* Optimized Magnitude Equation */
/**
 * @brief Funzione mag_eqn_optimised.
 * @param q1 Parametro q1.
 * @param q2 Parametro q2.
 * @param cef Parametro cef.
 * @return Valore di ritorno.
 */
 double mag_eqn_optimised(double q1, double q2, double cef) {
	 return (q1 * q1) + (q2 * q2) - (q1 * q2 * cef);
 }
 
