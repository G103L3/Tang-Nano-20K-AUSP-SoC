/*! \file leds.h
 * \author Gioele Giunta
 * \version 2.8
 * \since 2025
 * \brief Interfaccia del modulo leds
 */

/* Librerie */
#include <Arduino.h>

/* Headers specifici */
#include "global_parameters.h"

 #ifndef _LEDS_H_
 #define _LEDS_H_

#ifdef __cplusplus
extern "C" {
#endif
 /* C Library Headers */
 
 void turn_red(uint8_t val);
 void turn_green(uint8_t val);
 void turn_blue(uint8_t val);
 void turn_off();

#ifdef __cplusplus
}
#endif

 #endif
 
 /* ******************************* Gioele Giunta University Of Malta ************************************* */
 
