/*! \file bit_freq_codec.h
 * \author Gioele Giunta
 * \version 1.4
 * \since 2025
 * \brief Interfaccia del modulo bit freq codec
 */

#ifndef _bit_coder_H_
#define _bit_coder_H_
/* Librerie */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/* Headers specifici */
#include "global_parameters.h"

#ifdef __cplusplus
extern "C" {
#endif

/* C Library Headers */

/* Our Headers */

struct_tone_bits bit_coder(struct_tone_frequencies tones);
struct_out_tones frequency_coder(int bit, int role);

#ifdef __cplusplus
}
#endif

#endif

/* ******************************* Gioele Giunta University Of Malta ************************************* */
