#include "read_sdram.h"
#include "../include/periphs.h"   /* FFT_BSRAM, S0_FILLCNT */

/* ── Lettura SDRAM via snapshot BSRAM hardware (S0, 0x48001000) ───────────────
 * La FSM tst_ legge la SDRAM come sempre (i 20 burst da 26 parole) e scarica ogni
 * parola nel suo bin di una BSRAM da 512 (bin = burst*26 + idx). Quella BSRAM
 * resta STABILE per tutto il frame (~11 ms): la CPU la copia con calma, senza
 * rincorrere i "cassettini" da 200 cicli (che venivano sovrascritti prima che il
 * bus finisse di leggerli -> letture rotte). Sync su fill_cnt: cambia a ogni
 * frame completato, quindi quando cambia la BSRAM e' appena stata riempita. */

int16_t           g_sdram[512];
volatile int      g_sdram_ready = 0;
volatile uint32_t g_catch_b0 = 0, g_catch_b1 = 0;   /* diag: frame copiati */
volatile uint32_t g_b1_maxidx = 0;                  /* diag legacy (non piu' usato) */

static uint32_t rs_last_fill = 0xFFFFFFFFu;

void read_sdram_tick(void) {
    if (g_sdram_ready) return;                 /* il main non ha ancora consumato */

    uint32_t fc = S0_FILLCNT;
    if (fc == rs_last_fill) return;            /* nessun frame nuovo completato */
    rs_last_fill = fc;

    /* snapshot coerente: copia i 512 bin dalla BSRAM stabile (niente race) */
    for (int i = 0; i < 512; i++)
        g_sdram[i] = (int16_t)(FFT_BSRAM[i] & 0xFFFFu);

    g_catch_b0++; g_catch_b1++;                /* diag: 1 frame coerente copiato */
    g_sdram_ready = 1;                          /* il main decodifica e azzera il flag */
}
