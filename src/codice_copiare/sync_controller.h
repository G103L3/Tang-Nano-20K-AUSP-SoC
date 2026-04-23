/*! \file sync_controller.h
 * \author Gioele Giunta
 * \version 2.4
 * \since 2025
 * \brief Interfaccia del modulo sync controller
 */

/* Librerie */
#include <stdint.h>
#include <stdbool.h>

/* Headers specifici */
#include "complex_g3.h"
#include "global_parameters.h"

/**
 * @file sync_controller.h
 * @brief Synchronization controller for window-based DTMF tone detection.
 *
 * This module handles the extraction of a fixed-size window from the reading queue,
 * applies FFT, and decodes the resulting tones.
 * 
 * Author: Gioele Giunta
 * Date: 2025-05-15
 */

 #ifndef SYNC_CONTROLLER_H
 #define SYNC_CONTROLLER_H
 
 #ifdef __cplusplus
 extern "C" {
 #endif
 

 /*/ Fixed size for the analysis window */
 #define WINDOW_SIZE G_ARRAY_SIZE

 
 /**
  * @brief Initializes the synchronization controller parameters.
  *
  * This function resets the start position to zero and sets the window range
  * to the default value of 1024.
  */
 void sync_controller_init(void);
 
 /**
  * @brief Detects DTMF tones within a window of values extracted from the reading queue.
  *
  * This function extracts a window of samples from the reading queue,
  * performs an FFT on the window, and decodes the resulting frequencies.
  *
  * @return true if the detection process completes successfully, false otherwise.
  */
bool detect_tones(void);

bool is_channel_free(void);

void sync_time_init(void);
void wait_for_next_slot(void);
void resync_time(void);

 
 #ifdef __cplusplus
}
#endif
 
 #endif /* SYNC_CONTROLLER_H */
 
