#ifndef COMPLEX_G3_H
#define COMPLEX_G3_H

#include <math.h>
#include "global_parameters.h"

typedef struct complex_g3_t {
    double re;
    double im;
} complex_g3_t;

complex_g3_t complex_from_polar(double r, double theta_radians);
double       complex_magnitude(complex_g3_t c);
double       complex_decibels(complex_g3_t c);
complex_g3_t complex_add(complex_g3_t left, complex_g3_t right);
complex_g3_t complex_sub(complex_g3_t left, complex_g3_t right);
complex_g3_t complex_mult(complex_g3_t left, complex_g3_t right);

#endif
