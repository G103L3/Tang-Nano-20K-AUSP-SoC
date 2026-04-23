#include "complex_g3.h"

complex_g3_t complex_from_polar(double r, double theta_radians) {
    complex_g3_t result;
    result.re = r * cos(theta_radians);
    result.im = r * sin(theta_radians);
    return result;
}

double complex_magnitude(complex_g3_t c) {
    return sqrt(c.re * c.re + c.im * c.im);
}

double complex_decibels(complex_g3_t c) {
    return 20.0 * log10(complex_magnitude(c));
}

complex_g3_t complex_add(complex_g3_t left, complex_g3_t right) {
    complex_g3_t result;
    result.re = left.re + right.re;
    result.im = left.im + right.im;
    return result;
}

complex_g3_t complex_sub(complex_g3_t left, complex_g3_t right) {
    complex_g3_t result;
    result.re = left.re - right.re;
    result.im = left.im - right.im;
    return result;
}

complex_g3_t complex_mult(complex_g3_t left, complex_g3_t right) {
    complex_g3_t result;
    result.re = left.re * right.re - left.im * right.im;
    result.im = left.re * right.im + left.im * right.re;
    return result;
}
