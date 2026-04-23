/*! \file reading_queue.h
 * \author Gioele Giunta
 * \version 2.2
 * \since 2025
 * \brief Interfaccia del modulo reading queue
 */

/* Librerie */
#include <stdint.h>
#include <stdbool.h>
#include "complex_g3.h"  ///< complex_g3_t definition

/* Headers specifici */
#include "complex_g3.h"  ///< complex_g3_t definition
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"

/*
 * @file reading_queue.h
 * @brief Ring buffer FIFO queue for sequential data reading using a circular buffer.
 *
 * Author: Gioele Giunta (refactored)
 * Date: 2025-05-28
 */

 #ifndef READING_QUEUE_H
 #define READING_QUEUE_H
 
 #ifdef __cplusplus
 extern "C" {
 #endif
 
 
 #define READING_QUEUE_SIZE G_WINDOW_SIZE
 
 /**
  * @brief Ring buffer queue structure for complex samples.
  */
 typedef struct {
     complex_g3_t data[READING_QUEUE_SIZE];
     uint16_t head;          /*/< Next write index */
     uint16_t tail;          /*/< Next read index (oldest) */
     SemaphoreHandle_t mutex;/*/< Protects buffer access */
 } reading_queue_t;
 
 /** Global queue instance */
 extern reading_queue_t queue;
 
 /**
  * @brief Initializes the reading queue.
  *
  * Creates mutex and resets head/tail.
  */
 void reading_queue_init(void);
 
 /**
  * @brief Enqueues a new complex_g3_t value into the ring buffer.
  *
  * If the buffer is full, the oldest element is overwritten (tail advances).
  *
  * @param value Pointer to the complex_g3_t value to enqueue.
  */
 void reading_queue_enqueue(const complex_g3_t *value);
 
 /**
  * @brief Copies a range of elements from the queue into an output array.
  *
  * @param from  Starting offset from the oldest element (0-based)
  * @param range Number of elements to copy
  * @param out_array Pointer to array where copied elements will be stored
  * @return true if successful; false if range invalid or buffer not initialized
  */
 bool reading_queue_range(uint16_t from, uint16_t range, complex_g3_t *out_array);
 
 #ifdef __cplusplus
 }
 #endif
 
 #endif /* READING_QUEUE_H */
 
