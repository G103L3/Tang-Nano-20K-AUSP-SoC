/*! \file bit_output_packer.cpp
 * \brief Encoder run-length BINARIO {1,2,4}. Vedi bit_output_packer.h.
 */
#include "bit_output_packer.h"

void bit_output_packer_init(BitOutputPacker* p) {
    if (!p) return;
    p->count = 0;
}

/* Emette i codici per un run di `n` bit di valore `bit`, scomposizione greedy
 * nei pesi {4,2,1}. weight 4 -> indice 2, 2 -> 1, 1 -> 0.
 *   code zeri = indice (0,1,2);  code uni = 10 + indice (10,11,12). */
static void emit_run(BitOutputPacker* p, int bit, int n) {
    /* Pesi {2,1}: NIENTE peso 4 -> non si usano mai Z4(4800)/O4(5200), troppo
     * alti per lo speaker/mic. Tono massimo = O2 4400 Hz (banda forte). */
    static const int weights[2] = {2, 1};
    static const int widx[2]    = {1, 0};
    for (int k = 0; k < 2; k++) {
        int w = weights[k];
        while (n >= w) {
            int code = (bit == 0) ? widx[k] : (10 + widx[k]);
            if (p->count < BOP_MAX_CODES) p->codes[p->count++] = (uint8_t)code;
            n -= w;
        }
    }
}

bool bit_output_packer_compress(BitOutputPacker* p, const char* text) {
    if (!p || !text) return false;
    p->count = 0;

    int last_bit = -1;
    int run = 0;

    for (const char* c = text; *c; ++c) {
        unsigned char ch = (unsigned char)*c;
        for (int b = 6; b >= 0; --b) {        /* 7 bit per char, MSB first */
            int bit = (ch >> b) & 1;
            if (bit == last_bit) {
                run++;
            } else {
                if (last_bit >= 0) emit_run(p, last_bit, run);
                last_bit = bit;
                run = 1;
            }
        }
    }
    if (last_bit >= 0) emit_run(p, last_bit, run);

    /* EOP finale */
    if (p->count < BOP_MAX_CODES) p->codes[p->count++] = 8;
    return true;
}
