#include "read_sdram.h"

/* S0 (0x4800_0000): ponte verso la FSM tst_ che legge la SDRAM.
 *   0x00..0x64 = 26 parole del burst corrente (tst_rd_arr2)
 *   0x80       = stato [12:8]=burst (0..19), [5:0]=idx (0..26)
 *   0x8C       = contatore IRQ FFT (frame fatti) -> sync sul nuovo frame */
#define S0_WORDS   ((volatile uint32_t*)0x48000000u)
#define S0_STATUS  (*(volatile uint32_t*)(0x48000000u + 0x80))
#define S0_IRQC    (*(volatile uint32_t*)(0x48000000u + 0x8C))

int16_t           g_sdram[512];
volatile int      g_sdram_ready = 0;
volatile uint32_t g_catch_b0 = 0, g_catch_b1 = 0;   /* diagnostica: burst presi */
volatile uint32_t g_b1_maxidx = 0;                  /* diag: max idx visto sul burst1 */

/* parole di protocollo per burst (+ vicini), ALTA-PRIMA: la 1a lettura dopo lo
 * status e' la piu' coerente (la FSM tiene il burst fermo a idx=26 per ~200 cicli,
 * ma sul bus lento la finestra e' ~poche letture). Leggendo SOLO le poche parole
 * utili (non tutte le 26), restano nella finestra coerente del bus lento.
 * FREQUENZE NUOVE (ben distanziate): master 1200=bin13, slave 1700=bin19 -> ENTRAMBI i
 * carrier ora nel BURST0; dati EOF 2930=bin32(w6), bit0 3571=bin39(w13), bit1 4578=bin50(w24)
 * nel BURST1 (bin = 26 + w).
 *   burst0: carrier slave=w19 (gate RX, letto per 1o), carrier master=w13   (bin = w)
 *   burst1: EOF=w6, bit0=w13, bit1=w24                                      (bin = 26 + w) */
static const unsigned char b0_words[] = {19, 18, 20, 13, 12, 14};
static const unsigned char b1_words[] = {6, 5, 7, 13, 12, 14, 24, 23, 25};

/* === Cattura come il v25 (che PRENDEVA il burst1) =============================
 * Stato tra una chiamata e l'altra (la tick va chiamata 1 volta per giro di main):
 *  - !attivo: aspetta che cambi IRQC (nuovo frame FFT -> la FSM sta per stream-are
 *    i 20 burst). All'edge azzera g_sdram e apre una "sessione".
 *  - attivo : ad ogni giro legge lo stato; quando vede burst 0 o 1 a idx>=26 (e non
 *    gia' preso) ne legge le proto-parole. La MASCHERA fa si' che, preso il burst0,
 *    si continui a pollare ASPETTANDO il burst1 (senza ri-prendere il burst0).
 *  - presi burst0+burst1 (o scaduto il deadline) -> g_sdram_ready=1, il main decodifica. */
#define RS_DEADLINE 20000u
#define RS_NEED     ((1u << 0) | (1u << 1))   /* servono burst0 E burst1 */

static int      rs_active   = 0;
static unsigned rs_mask     = 0;
static uint32_t rs_dl       = 0;
static uint32_t rs_last_irqc = 0;

static void grab_burst(unsigned b, const unsigned char *ws, unsigned nw) {
    for (unsigned k = 0; k < nw; k++) {        /* prime letture = piu' coerenti */
        unsigned w   = ws[k];
        unsigned bin = b * 26u + w;
        int16_t  v   = (int16_t)(S0_WORDS[w] & 0xFFFFu);
        int      m   = (v < 0) ? -(int)v : (int)v;
        int16_t  cur = g_sdram[bin];
        int      cm  = (cur < 0) ? -(int)cur : (int)cur;
        if (m > cm) g_sdram[bin] = v;           /* tieni il piu' forte */
    }
}

void read_sdram_tick(void) {
    if (g_sdram_ready) return;                  /* il main non ha ancora consumato */

    if (!rs_active) {                           /* aspetta il nuovo frame */
        uint32_t irqc = S0_IRQC;
        if (irqc != rs_last_irqc) {
            rs_last_irqc = irqc;
            rs_active = 1; rs_mask = 0; rs_dl = RS_DEADLINE;
            for (int i = 0; i < 512; i++) g_sdram[i] = 0;
        }
        return;
    }

    uint32_t a   = S0_STATUS;                   /* sessione attiva: cerca i burst 0/1 */
    unsigned idx = a & 0x3Fu;
    unsigned b   = (a >> 8) & 0x1Fu;
    if (b == 1u && idx > g_b1_maxidx) g_b1_maxidx = idx;   /* diag */
    if (idx >= 26u) {
        if      (b == 1u && !(rs_mask & 2u)) { grab_burst(1, b1_words, (unsigned)sizeof(b1_words)); rs_mask |= 2u; g_catch_b1++; }
        else if (b == 0u && !(rs_mask & 1u)) { grab_burst(0, b0_words, (unsigned)sizeof(b0_words)); rs_mask |= 1u; g_catch_b0++; }
    }

    if ((rs_mask & RS_NEED) == RS_NEED) { g_sdram_ready = 1; rs_active = 0; }
    else if (--rs_dl == 0)              { g_sdram_ready = 1; rs_active = 0; }  /* decodifica cio' che c'e' */
}
