/*! \file reader_test.h
 * \author Gioele Giunta
 * \version 2.7
 * \since 2025
 * \brief Interfaccia del modulo reader test
 */

#ifndef READER_TEST_H_
#define READER_TEST_H_
/* Librerie */
#include <stdio.h>
#include <stdlib.h>
#include <driver/i2s.h>
#include <driver/adc.h>

/* Headers specifici */
#include "complex_g3.h"
#include "global_parameters.h"
#include "reading_queue.h"

#ifdef __cplusplus
extern "C" {
#endif





#define TEST_ARRAY_ELEMENTS 1024
#define SAMPLE_RATE G_SAMPLE_RATE
#define I2S_PORT I2S_NUM_0
#define DMA_BUFFER_SIZE 1024
#define DMA_BUFFERS 4
#define VREF (3.3)
#define ADC_MASK G_MAX_AMPLITUDE
#define AUDIO_PIN ADC1_CHANNEL_0  /* GPIO36 (VP) */

/**
 * @brief Initialize the test reader: configures ADC, I2S, allocates buffers and launches test task.
 */
void reader_test_init(void);

#ifdef __cplusplus
}
#endif

#endif /* READER_TEST_H_ */
