/*! \file leds.c
 * \author Gioele Giunta
 * \version 1.7
 * \since 2025
 * \brief Implementazione del modulo leds
 */

/* Headers specifici */
#include "leds.h"

#ifdef __cplusplus
extern "C" {
#endif
/**
 * @brief Funzione turn_red.
 * @param val Parametro val.
 */

void turn_red(uint8_t val){
    pinMode(RED_LED, OUTPUT);
    pinMode(GREEN_LED, OUTPUT);
    digitalWrite(RED_LED, val);
    digitalWrite(GREEN_LED, !val);
}
/**
 * @brief Funzione turn_green.
 * @param val Parametro val.
 */
void turn_green(uint8_t val){
    pinMode(GREEN_LED, OUTPUT);
    digitalWrite(GREEN_LED, val);
}
/**
 * @brief Funzione turn_blue.
 * @param val Parametro val.
 */
void turn_blue(uint8_t val){
    pinMode(BLUE_LED, OUTPUT);
    digitalWrite(BLUE_LED, val);
}
/**
 * @brief Funzione turn_off.
 */

void turn_off(){
    pinMode(RED_LED, OUTPUT);
    digitalWrite(RED_LED, LOW);    
    turn_green(0);
    turn_blue(0);
}

#ifdef __cplusplus
}
#endif
