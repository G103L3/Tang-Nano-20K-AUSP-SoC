/*! \file read_sdram.h
 * \brief Lettura COERENTE dei 512 bin FFT dalla SDRAM (via la FSM tst_ su S0),
 *        fatta dalla CPU stessa. Riempie un array globale da 512 e alza un flag
 *        quando lo spettro e' pronto; il main lo passa al decoder.
 */
#ifndef READ_SDRAM_H_
#define READ_SDRAM_H_
#include <stdint.h>

/* Spettro FFT (parte reale xk_re) indicizzato per bin 0..511, riempito da read_sdram_collect().
 * magnitudine del bin = |g_sdram[bin]| (come nel decoder). */
extern int16_t      g_sdram[512];

/* true (1) quando g_sdram contiene uno spettro pronto da decodificare. Il main lo
 * controlla, decodifica, e lo rimette a 0 (consumato). */
extern volatile int g_sdram_ready;

/* diagnostica: quante volte abbiamo "preso" i burst 0 e 1 (cumulativo). Se restano
 * a 0 vuol dire che il polling non becca mai lo stream -> serve sync sul frame. */
extern volatile uint32_t g_catch_b0, g_catch_b1;
extern volatile uint32_t g_b1_maxidx;   /* max idx visto sul burst1 (diag gate) */

/* Da chiamare 1 volta per giro di main: sincronizza sul nuovo frame FFT (IRQC),
 * prende i burst 0 e 1 (proto-parole, alta-prima) in g_sdram, poi mette
 * g_sdram_ready = 1. Il main decodifica e rimette il flag a 0. */
void read_sdram_tick(void);

#endif /* READ_SDRAM_H_ */
