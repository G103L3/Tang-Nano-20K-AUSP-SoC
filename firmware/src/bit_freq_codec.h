#ifndef BIT_FREQ_CODEC_H_
#define BIT_FREQ_CODEC_H_

#include "global_parameters.h"

struct_tone_bits bit_coder(struct_tone_frequencies tones);
struct_out_tones frequency_coder(int bit, int role);

#endif
