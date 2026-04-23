/*! \file bit_output_packer.h
 * \author Gioele Giunta
 * \version 3.4
 * \since 2025
 * \brief Interfaccia del modulo bit output packer
 */

#ifndef BIT_OUTPUT_PACKER_H
#define BIT_OUTPUT_PACKER_H
/* Librerie */
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

/* Headers specifici */
#include "global_parameters.h"

#ifdef __cplusplus
extern "C" {
#endif



/* Maximum number of ASCII characters that can be packed. */
#define BOP_MAX_CHARS 2048
/* Total number of bit pairs generated from the characters. */
#define BOP_MAX_BITS (BOP_MAX_CHARS * 7)
#define ZIPPED_ARRAY_SIZE 1024
#define ZIPPED_NUM_ARRAYS 2

/**
 * @brief Holds the frequency pairs generated from a text message.
 */
typedef struct {
    struct_out_tones *pairs; /**< Dynamically allocated array of frequency pairs. */
    size_t pair_count;       /**< Number of valid pairs in @c pairs. */

} BitOutputPacker;

/**
 * @brief Reset the internal state of the packer.
 */
void bit_output_packer_init(BitOutputPacker* packer);

/**
 * @brief Release any memory held by the packer.
 */
void bit_output_packer_free(BitOutputPacker* packer);

extern int zipped_pack[ZIPPED_NUM_ARRAYS][ZIPPED_ARRAY_SIZE];
extern size_t zipped_array_index;
extern size_t zipped_position;

bool bit_output_packer_compress(BitOutputPacker* packer, const char* text);
bool bit_output_packer_convert(BitOutputPacker* packer, int role);

#ifdef __cplusplus
}
#endif

#endif /* BIT_OUTPUT_PACKER_H */
