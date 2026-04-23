/*! \file reading_queue.c
 * \author Gioele Giunta
 * \version 1.0
 * \since 2025
 * \brief Implementazione del modulo reading queue
 */

/* Librerie */
#include <string.h> // for memcpy

/* Headers specifici */
#include "reading_queue.h"

 /*
  * @file reading_queue.c
  * @brief Implementation of the ring buffer queue using a circular buffer.
  *
  * Author: Gioele Giunta (refactored)
  * Date: 2025-05-28
  */
 
 
 reading_queue_t queue;
/**
 * @brief Funzione reading_queue_init.
 */
 
 void reading_queue_init(void) {
     queue.head = 0;
     queue.tail = 0;
     queue.mutex = xSemaphoreCreateMutex();
 }
/**
 * @brief Funzione reading_queue_enqueue.
 * @param value Parametro value.
 */
 
 void reading_queue_enqueue(const complex_g3_t *value) {
     if (queue.mutex == NULL) return; /* not initialized */
     xSemaphoreTake(queue.mutex, portMAX_DELAY);
     uint16_t next_head = (queue.head + 1) % READING_QUEUE_SIZE;
     /* If full, advance tail to overwrite oldest */
     if (next_head == queue.tail) {
         queue.tail = (queue.tail + 1) % READING_QUEUE_SIZE;
     }
     queue.data[queue.head] = *value;
     queue.head = next_head;
     xSemaphoreGive(queue.mutex);
 }
/**
 * @brief Funzione reading_queue_range.
 * @param from Parametro from.
 * @param range Parametro range.
 * @param out_array Parametro out_array.
 * @return Valore di ritorno.
 */
 
 bool reading_queue_range(uint16_t from, uint16_t range, complex_g3_t *out_array) {
     if (queue.mutex == NULL) return false;
     xSemaphoreTake(queue.mutex, portMAX_DELAY);
     /* Compute available samples */
     uint16_t available = (queue.head >= queue.tail)
                          ? (queue.head - queue.tail)
                          : (READING_QUEUE_SIZE - queue.tail + queue.head);
     if (from + range > available) {
         xSemaphoreGive(queue.mutex);
         return false;
     }
     /* Copy elements */
     for (uint16_t i = 0; i < range; i++) {
         uint16_t idx = (queue.tail + from + i) % READING_QUEUE_SIZE;
         out_array[i] = queue.data[idx];
     }
     xSemaphoreGive(queue.mutex);
     return true;
 }
 
