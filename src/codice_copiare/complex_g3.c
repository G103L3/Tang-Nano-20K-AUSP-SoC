/*! \file complex_g3.c
 * \author Gioele Giunta
 * \version 1.4
 * \since 2025
 * \brief Implementazione del modulo complex g3
 */

/* Headers specifici */
#include "decoder.h"
#include "complex_g3.h"
/**
 * @brief Funzione complex_from_polar.
 * @param r Parametro r.
 * @param theta_radians Parametro theta_radians.
 * @return Valore di ritorno.
 */

complex_g3_t complex_from_polar(double r, double theta_radians)
{
    complex_g3_t result;

    result.re = r * cos(theta_radians);
    result.im = r * sin(theta_radians);

    return result;
}
/**
 * @brief Funzione complex_magnitude.
 * @param c Parametro c.
 * @return Valore di ritorno.
 */

double complex_magnitude(complex_g3_t c)
{
    return sqrt(c.re*c.re + c.im*c.im);
}
/**
 * @brief Funzione complex_decibels.
 * @param c Parametro c.
 * @return Valore di ritorno.
 */

double complex_decibels(complex_g3_t c){
    return 20 * log10(complex_magnitude(c));
}
/**
 * @brief Funzione complex_add.
 * @param left Parametro left.
 * @param right Parametro right.
 * @return Valore di ritorno.
 */

complex_g3_t complex_add(complex_g3_t left, complex_g3_t right)
{
    complex_g3_t result;

    result.re = left.re + right.re;
    result.im = left.im + right.im;

    return result;
}
/**
 * @brief Funzione complex_sub.
 * @param left Parametro left.
 * @param right Parametro right.
 * @return Valore di ritorno.
 */

complex_g3_t complex_sub(complex_g3_t left, complex_g3_t right)
{
    complex_g3_t result;

    result.re = left.re - right.re;
    result.im = left.im - right.im;

    return result;
}
/**
 * @brief Funzione complex_mult.
 * @param left Parametro left.
 * @param right Parametro right.
 * @return Valore di ritorno.
 */

complex_g3_t complex_mult(complex_g3_t left, complex_g3_t right)
{
    complex_g3_t result;

    result.re = left.re*right.re - left.im*right.im;
    result.im = left.re*right.im + left.im*right.re;

    return result;
}
