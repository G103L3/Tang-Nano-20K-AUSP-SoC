#ifndef DECODER_H_
#define DECODER_H_

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include "complex_g3.h"
#include "global_parameters.h"

#define NN G_ARRAY_SIZE
#define FS G_SAMPLE_RATE

typedef struct struct_interpolated_frequency {
    double frequency;
    double estimated_amplitude;
    int    work;
    double dynamic_amplitude_threshold;
} struct_interpolated_frequency;

struct_tone_frequencies decode_ausp(complex_g3_t *data);
struct_interpolated_frequency check_active_frequencies(complex_g3_t *data, int bin_1, int bin_2, int id, double noise_floor);
double estimate_noise_floor(complex_g3_t *data, int size);

#endif
