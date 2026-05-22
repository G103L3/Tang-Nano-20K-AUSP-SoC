/*! \file bit_output_packer.h
 * \brief Encoder: testo ASCII -> sequenza di signal code (run-length BINARIO).
 *
 * Schema {1,2,4} (vedi DIARIO 2026-05-22): ogni run di N bit uguali viene
 * scomposto greedy nei pesi {4,2,1} ed emesso come codici consecutivi dello
 * stesso bit (il ricevitore li somma). I codici prodotti sono "channel-agnostic"
 * (0/1/2 = 1/2/4 zeri, 10/11/12 = 1/2/4 uni, 8 = EOP). Il canale (master/config)
 * viene applicato al momento dell'invio via fpga_uart_code_to_char(code, role).
 */
#ifndef BIT_OUTPUT_PACKER_H
#define BIT_OUTPUT_PACKER_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include "global_parameters.h"

#ifdef __cplusplus
extern "C" {
#endif

#define BOP_MAX_CHARS 256
/* peggior caso: bit alternati -> 7 code/char (1 per bit) + EOP */
#define BOP_MAX_CODES (BOP_MAX_CHARS * 7 + 4)

typedef struct {
    uint8_t codes[BOP_MAX_CODES];   /* sequenza di signal code da inviare */
    size_t  count;                  /* numero di code validi (incluso EOP) */
} BitOutputPacker;

void bit_output_packer_init(BitOutputPacker* p);

/* Comprime `text` in signal code binari + EOP finale. true se ok. */
bool bit_output_packer_compress(BitOutputPacker* p, const char* text);

#ifdef __cplusplus
}
#endif

#endif /* BIT_OUTPUT_PACKER_H */
