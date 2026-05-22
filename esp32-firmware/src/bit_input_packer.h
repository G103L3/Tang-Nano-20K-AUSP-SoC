/*! \file bit_input_packer.h
 * \brief Accumula signal codes provenienti dal canale RX UART (FPGA decoder)
 * e li compatta in pacchetti ASCII di 7-bit/char, pronti per il routing
 * verso il protocol layer.
 *
 * Porting dal C reference, con tre differenze:
 *   1) now_ms() usa millis() (Arduino) invece di clock_gettime
 *   2) printf rimossi (Serial debug puo' essere riattivato definendo BIP_VERBOSE)
 *   3) include Arduino.h per i tipi base
 */
#ifndef BIT_INPUT_PACKER_H
#define BIT_INPUT_PACKER_H

#include <Arduino.h>
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#include "global_parameters.h"

#ifdef __cplusplus
extern "C" {
#endif

#define MAX_ARRAY_SIZE        1024
#define NUM_ARRAYS            3
#define MAX_CONSECUTIVE_ZEROS 21
#define ASCII_ARRAY_SIZE      256
#define ASCII_NUM_ARRAYS      8
#define ASCII_PACKET_SIZE     (ASCII_ARRAY_SIZE * ASCII_NUM_ARRAYS)

typedef struct {
    uint8_t arrays[NUM_ARRAYS][MAX_ARRAY_SIZE];
    size_t  bit_position;
    size_t  array_index;
    size_t  ascii_char_index;
    size_t  ascii_array_index;
} BitPacker;

bool process_tone_bits(struct_tone_bits input);
bool flush_and_convert_to_ascii(BitPacker* packer, const char* label);
bool add_bit(BitPacker* packer, uint8_t signal_code, const char* label);

extern BitPacker master_packer;
extern BitPacker slave_packer;
extern BitPacker config_packer;

extern char master_ascii_arrays[ASCII_NUM_ARRAYS][ASCII_ARRAY_SIZE];
extern char slave_ascii_arrays [ASCII_NUM_ARRAYS][ASCII_ARRAY_SIZE];
extern char config_ascii_arrays[ASCII_NUM_ARRAYS][ASCII_ARRAY_SIZE];

extern bool master_ascii_ready;
extern bool slave_ascii_ready;
extern bool config_ascii_ready;

#ifdef __cplusplus
}
#endif

#endif /* BIT_INPUT_PACKER_H */
