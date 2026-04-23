/*! \file global_parameters.h
 * \author Gioele Giunta
 * \version 1.6
 * \since 2025
 * \brief Interfaccia del modulo global parameters
 */

#ifndef GLOBAL_PARAMETERS_H_
#define GLOBAL_PARAMETERS_H_
/* Librerie */
#include <Arduino.h>

#define G_MODE 1 /* 0: No debug, 1: Info, 2: Debug */
/* 48000 è il nuovo sample rate, 48000 campioni al secondo */
#define G_SAMPLE_RATE 48000

/* Dimensione array calcolata per 0.064 secondi: 0.064 * 48000 = 3072 */
#define G_ARRAY_SIZE 512

/* Dimensione della finestra scorrevole (coda FIFO) di cui poi verranno analizzati solo 1024 elementi a volta*/
#define G_WINDOW_SIZE 256

/* Massima ampiezza ADC a 12-bit */
#define G_MAX_AMPLITUDE 4096.0

#define G_SEQUENCE_LENGTH 100
#define G_PI 3.14159265358979323846

#define G_LINEAR_REGRESSION_MODE 0 /* 0: No linear regression, 1: Linear regression Emitting 2: Linear regression Decoding  */

#define G_TESTING_MODE 0 /* 0: Both modes active, 1: Only Emitting, 2: Only Decoding */

/*AUSP frequencies pattern (adjusted for 400 Hz tone spacing) */
#define MASTER_BASE 1000
#define SLAVE_BASE MASTER_BASE
#define CONFIG_BASE MASTER_BASE
#define SLAVE_CARRIER 9000
#define CONFIG_CARRIER 8600
#define TONE_STEP 400
#define ROW_LEN      19

/*MAP PINS */
#define RED_LED         13
#define BLUE_LED        12
#define GREEN_LED       14
#define I2S_DATA_PIN    27    /**< Serial Data (DIN) pin connected to GPIO14 */
#define I2S_BCK_PIN     26    /**< Bit Clock pin (BCLK) connected to GPIO33 */
#define I2S_WS_PIN      25    /**< Word Select (LRC) pin connected to GPIO32 */
/* Pin configuration for I2S microphone (INMP441) */
#define I2S_MIC_BCK_PIN 33   /* BCLK */
#define I2S_MIC_WS_PIN  32  /* LRCL (word select) */
#define I2S_MIC_SD_PIN  35  /* DOUT */
/*Pin HotSpot mode */
#define HOTSPOT_PIN     34    /* Pin to enable HotSpot mode (HIGH = HotSpot mode enabled) */
/*Pin Sensors  */
#define PIR_PIN         39    /* Pin for PIR motion sensor */


typedef struct struct_out_tones {
    int tones[2];
} struct_out_tones;

typedef struct struct_tone_frequencies {
    int master[3];
    int slave[3];
    int configuration[3];
} struct_tone_frequencies;

typedef struct struct_sync_frequencies {
    int list[10];
} struct_sync_frequencies;

typedef struct struct_tone_bits {
    int master;
    int slave;
    int configuration;
} struct_tone_bits;


typedef struct amplitude_profile {
    int new_profile;
    double estimated_threshold_low_bottom;
    double estimated_threshold_low_top;
    double estimated_threshold_mid_bottom;
    double estimated_threshold_mid_top;
    double estimated_threshold_high_bottom;
    double estimated_threshold_high_top;
} amplitude_profile;



#endif
