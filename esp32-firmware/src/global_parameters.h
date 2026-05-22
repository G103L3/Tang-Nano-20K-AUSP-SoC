/*! \file global_parameters.h
 * \brief Parametri globali per il firmware ESP32 (versione FPGA-offloaded).
 *
 * Questa versione e' molto piu' magra del reference C: la maggior parte dei
 * parametri audio (sample rate, FFT size, ADC, I2S) sta sull'FPGA. Qui
 * restano solo i parametri del protocollo (carrier, signal codes, packet
 * structure) e i tipi condivisi tra moduli.
 */
#ifndef GLOBAL_PARAMETERS_H_
#define GLOBAL_PARAMETERS_H_

#include <Arduino.h>

#define G_MODE 1 /* 0: No debug, 1: Info, 2: Debug */

/* Frequenze del protocollo (Hz) ----------------------------------------- */
#define MASTER_BASE      1000
#define SLAVE_BASE       MASTER_BASE
#define CONFIG_BASE      MASTER_BASE
#define MASTER_CARRIER   8200
#define SLAVE_CARRIER    9000
#define CONFIG_CARRIER   8600
#define TONE_STEP        400
#define ROW_LEN          19

/* Codifica char <-> signal code lato UART FPGA --------------------------- *
 * Master  (carrier 8200): 'a'..'h' = code 0..7, 'i' = code 8 (EOP),
 *                          'j'..'q' = code 10..17 (skip code 9 = free).
 * Config  (carrier 8600): 'A'..'H', 'I' = EOP, 'J'..'Q'.
 * Slave   (carrier 9000): non usato per ora (decoder FPGA ascolta solo
 *                          master e config, vedi audio_decoder.vhd).
 */
#define CHAR_MASTER_BASE 'a'
#define CHAR_CONFIG_BASE 'A'

/* Bottoni / sensori ----------------------------------------------------- */
#define HOTSPOT_PIN      34
#define PIR_PIN          39
#define PIR_THRESHOLD    2048

/* Tipi condivisi -------------------------------------------------------- */
typedef struct struct_out_tones {
    int tones[2];
} struct_out_tones;

typedef struct struct_tone_frequencies {
    int master[3];
    int slave[3];
    int configuration[3];
} struct_tone_frequencies;

typedef struct struct_tone_bits {
    int master;
    int slave;
    int configuration;
} struct_tone_bits;

#endif /* GLOBAL_PARAMETERS_H_ */
