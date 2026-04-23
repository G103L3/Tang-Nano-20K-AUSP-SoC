#ifndef BIT_OUTPUT_PACKER_H
#define BIT_OUTPUT_PACKER_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include "global_parameters.h"

#define BOP_MAX_CHARS    2048
#define BOP_MAX_BITS     (BOP_MAX_CHARS * 7)
#define ZIPPED_ARRAY_SIZE 1024
#define ZIPPED_NUM_ARRAYS 2

typedef struct {
    struct_out_tones *pairs;
    size_t            pair_count;
} BitOutputPacker;

void bit_output_packer_init(BitOutputPacker *packer);
void bit_output_packer_free(BitOutputPacker *packer);
bool bit_output_packer_compress(BitOutputPacker *packer, const char *text);
bool bit_output_packer_convert(BitOutputPacker *packer, int role);

extern int    zipped_pack[ZIPPED_NUM_ARRAYS][ZIPPED_ARRAY_SIZE];
extern size_t zipped_array_index;
extern size_t zipped_position;

#endif
