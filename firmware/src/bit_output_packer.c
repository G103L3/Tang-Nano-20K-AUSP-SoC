#include <string.h>
#include <stdlib.h>
#include "bit_output_packer.h"
#include "bit_freq_codec.h"

static int    consecutive_packing_zeroes = 0;
static int    consecutive_packing_ones   = 0;
static int    last = 2;
static int    rep  = 3;

int    zipped_pack[ZIPPED_NUM_ARRAYS][ZIPPED_ARRAY_SIZE];
size_t zipped_array_index = 0;
size_t zipped_position    = 0;

static struct_out_tones silent = {{0, 0}};

void bit_output_packer_init(BitOutputPacker *packer) {
    if (!packer) return;
    packer->pairs      = NULL;
    packer->pair_count = 0;
    memset(zipped_pack, 0, sizeof(zipped_pack));
    zipped_array_index          = 0;
    zipped_position             = 0;
    consecutive_packing_zeroes  = 0;
    consecutive_packing_ones    = 0;
    last = 2;
}

void bit_output_packer_free(BitOutputPacker *packer) {
    if (!packer) return;
    free(packer->pairs);
    packer->pairs      = NULL;
    packer->pair_count = 0;
}

bool bit_output_packer_compress(BitOutputPacker *packer, const char *text) {
    if (!packer || !text) return false;
    bit_output_packer_free(packer);
    memset(zipped_pack, 0, sizeof(zipped_pack));
    last               = 2;
    zipped_array_index = 0;
    zipped_position    = 0;

    size_t len = strlen(text);
    if (len > BOP_MAX_CHARS) len = BOP_MAX_CHARS;

    packer->pair_count = 0;

    for (size_t i = 0; i < len; ++i) {
        unsigned char c = (unsigned char)text[i];
        for (int b = 6; b >= 0; --b) {
            int bit = (c >> b) & 1;

            if (bit == 0) {
                bool check_zero = (i == len - 1) && (b == 0) && (consecutive_packing_zeroes > 0);
                if (last != bit && !check_zero) {
                    if (last != 2) {
                        zipped_pack[zipped_array_index][zipped_position] = 10 + consecutive_packing_ones - 1;
                        zipped_position++;
                        if (zipped_position >= ZIPPED_ARRAY_SIZE) { zipped_position = 0; zipped_array_index++; }
                    }
                    consecutive_packing_ones = 0;
                }
                last = 0;
                consecutive_packing_zeroes++;
                if (check_zero) {
                    zipped_pack[zipped_array_index][zipped_position] = consecutive_packing_zeroes - 1;
                    zipped_position++;
                    if (zipped_position >= ZIPPED_ARRAY_SIZE) { zipped_position = 0; zipped_array_index++; }
                }
            }

            if (bit == 1) {
                bool check_one = (i == len - 1) && (b == 0) && (consecutive_packing_ones > 0);
                if (last != bit && !check_one) {
                    if (last != 2) {
                        zipped_pack[zipped_array_index][zipped_position] = consecutive_packing_zeroes - 1;
                        zipped_position++;
                        if (zipped_position >= ZIPPED_ARRAY_SIZE) { zipped_position = 0; zipped_array_index++; }
                    }
                    consecutive_packing_zeroes = 0;
                }
                last = 1;
                consecutive_packing_ones++;
                if (check_one) {
                    zipped_pack[zipped_array_index][zipped_position] = 10 + consecutive_packing_ones - 1;
                    zipped_position++;
                    if (zipped_position >= ZIPPED_ARRAY_SIZE) { zipped_position = 0; zipped_array_index++; }
                }
            }
        }
    }
    return true;
}

bool bit_output_packer_convert(BitOutputPacker *packer, int role) {
    if (!packer) return false;

    size_t codes  = zipped_array_index * ZIPPED_ARRAY_SIZE + zipped_position;
    size_t needed = (codes * 7) * rep + (3 * 7) * rep;
    packer->pairs = (struct_out_tones *)malloc(needed * sizeof(struct_out_tones));
    if (!packer->pairs) return false;

    packer->pair_count = 0;
    for (size_t idx = 0; idx < codes; idx++) {
        size_t arr  = idx / ZIPPED_ARRAY_SIZE;
        size_t pos  = idx % ZIPPED_ARRAY_SIZE;
        int    code = zipped_pack[arr][pos];
        for (int j = 0; j < rep; j++) {
            packer->pairs[packer->pair_count++] = frequency_coder(code, role);
        }
        packer->pairs[packer->pair_count++] = silent;
    }

    for (int b = 6; b >= 0; --b) {
        packer->pairs[packer->pair_count++] = frequency_coder(8, role);
    }
    packer->pairs[packer->pair_count++] = silent;

    return true;
}
