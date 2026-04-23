/*! \file audio_driver.h
 * \author Gioele Giunta
 * \version 1.4
 * \since 2025
 * \brief Interfaccia del modulo audio driver
 */

#ifndef AUDIO_DRIVER_H
#define AUDIO_DRIVER_H
/* Librerie */
#include <driver/i2s.h>

/* Headers specifici */
#include "global_parameters.h"

#ifdef __cplusplus
extern "C" {
#endif



#define I2S_NUM         I2S_NUM_1         /**< I2S peripheral number */
#ifndef PI
#define PI 3.14159265                     /**< Pi constant */
#endif



/**
 * @brief Initializes the I2S driver with predefined configuration for audio output.
 *
 * This function sets up the ESP32's I2S peripheral for transmitting audio data to the MAX98357A.
 * The configuration includes sample rate, bit depth, and pin assignments for the BCLK, LRC, and DATA signals.
 */
void audio_init();

/**
 * @brief Generates and plays a sine wave tone of the specified frequency through the MAX98357A.
 *
 * This function creates a stereo audio buffer containing a single sine wave at the specified
 * frequency and sends it via I2S. The output is scaled to fit within 16-bit audio limits.
 * It blocks while transmitting one full cycle of the waveform with a duration of 0.0106667 seconds.
 *
 * @param frequency Frequency in Hz of the sine wave to generate and play.
 */

void play_tone(int frequency);

/**
 * @brief Generates and plays a composite tone made of two sine wave frequencies through the MAX98357A.
 *
 * This function creates a stereo audio buffer containing the sum of two sine waves at the specified
 * frequencies and sends it via I2S. The output is normalized to prevent clipping. It blocks while 
 * transmitting one full cycle of the waveform with a duration of 0.0106667 seconds.
 *
 * @param freq1 Frequency in Hz of the first sine wave.
 * @param freq2 Frequency in Hz of the second sine wave.
 */
void play_two_tones(int freq1, int freq2);

void play_nine_tones(const int freqs[9]);
/**
 * @brief Generates and plays a composite tone made of nine sine wave frequencies through the MAX98357A.
 *
 * This function creates a stereo audio buffer containing the sum of nine sine waves at the specified
 * frequencies and sends it via I2S. The output is normalized to prevent clipping. It blocks while 
 * transmitting one full cycle of the waveform with a duration of 0.0106667 seconds.
 *
 * @param freqs Array of 9 integer values representing the frequencies in Hz of the sine waves to combine.
 */

void play_nine_tones(const int freqs[9]);

#ifdef __cplusplus
}
#endif

#endif /* AUDIO_DRIVER_H */
