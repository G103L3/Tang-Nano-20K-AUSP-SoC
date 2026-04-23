/*! \file movement_sensor.c
 * \author Gioele Giunta
 * \version 1.1
 * \since 2025
 * \brief Implementazione del modulo movement sensor
 */

/* Librerie */
#include <Arduino.h>

/* Headers specifici */
#include "movement_sensor.h"
/**
 * @brief Funzione movement_sensor_init.
 */

void movement_sensor_init(void){
    pinMode(PIR_PIN, INPUT);
}

static volatile bool abort_flag = false;
static volatile bool was_aborted = false;
/**
 * @brief Funzione movement_sensor_detect.
 * @param duration_ms Parametro duration_ms.
 * @return Valore di ritorno.
 */

bool movement_sensor_detect(unsigned long duration_ms){
    unsigned long start = millis();
    was_aborted = false;
    while(millis() - start < duration_ms){
        if(abort_flag){
            was_aborted = true;
            abort_flag = false;
            return false;
        }
        if(analogRead(PIR_PIN) > PIR_THRESHOLD){
            abort_flag = false;
            return true;
        }
        delay(10);
    }
    abort_flag = false;
    return false;
}
/**
 * @brief Funzione movement_sensor_abort.
 */

void movement_sensor_abort(void){
    abort_flag = true;
}
/**
 * @brief Funzione movement_sensor_aborted.
 * @return Valore di ritorno.
 */

bool movement_sensor_aborted(void){
    bool ret = was_aborted;
    was_aborted = false;
    return ret;
}
