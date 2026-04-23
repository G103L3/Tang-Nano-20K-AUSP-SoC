/*! \file reader.h
 * \author Gioele Giunta
 * \version 1.3
 * \since 2025
 * \brief Interfaccia del modulo reader
 */

#ifndef READER_H_
#define READER_H_
/* Librerie */
#include <stdio.h>
#include <stdlib.h>
#include <driver/i2s.h>

/* Headers specifici */
#include "complex_g3.h"
#include "global_parameters.h"

#ifdef __cplusplus
extern "C" {
#endif




#define ARRAY_ELEMENTS G_ARRAY_SIZE
#define SAMPLE_RATE G_SAMPLE_RATE
#define I2S_PORT I2S_NUM_0
#define DMA_BUFFER_SIZE 1024
#define DMA_BUFFERS 4


extern volatile int data_ready;
extern volatile int status_flag;
extern complex_g3_t *array_ready;

void reader_init(void);

#ifdef __cplusplus
}
#endif

#endif /* READER_H_ */
