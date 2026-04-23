/*! \file movement_sensor.h
 * \author Gioele Giunta
 * \version 2.5
 * \since 2025
 * \brief Interfaccia del modulo movement sensor
 */

#ifndef MOVEMENT_SENSOR_H
#define MOVEMENT_SENSOR_H
/* Librerie */
#include <stdbool.h>

/* Headers specifici */
#include "global_parameters.h"

#ifdef __cplusplus
extern "C" {
#endif

#define PIR_THRESHOLD 2048

void movement_sensor_init(void);
bool movement_sensor_detect(unsigned long duration_ms);
void movement_sensor_abort(void);
bool movement_sensor_aborted(void);

#ifdef __cplusplus
}
#endif

#endif /* MOVEMENT_SENSOR_H */
