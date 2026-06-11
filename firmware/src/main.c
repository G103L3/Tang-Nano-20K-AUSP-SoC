/*
 * EFES - firmware soft core PicoRV32 (snello).
 *   TX (emit)  -> emit_tone.c  : UART char -> coda -> PWM due toni.
 *   RX (decode)-> decoder.c    : magnitudini FFT -> simbolo (port dello slave:
 *                                noise floor adattivo + max locale + interp. parabolica).
 *   Qui restano: l'init, il "ponte" S0 (la FSM tst_ legge la SDRAM, noi prendiamo i
 *   burst via bus), il driver RX a polling (l'IRQ FFT non arriva alla CPU) e la diagnostica.
 */
#include <stdint.h>
#include "../include/periphs.h"
#include "emit_tone.h"      /* CPU_HZ, rdcycle32, ms_to_cycles, emit_* */
#include "decoder.h"        /* decode_char */
#include "read_sdram.h"     /* g_sdram[512], g_sdram_ready, read_sdram_collect */

#define BAUD  115200u

/* ── S0 (0x4800_0000): buffer di burst della FSM tst_ + contatori HW dell'acceleratore ──
 *   0x00..0x64 = 26 parole del burst corrente (xk_re)
 *   0x80 = stato [31]frame_ready [16]in_read [12:8]burst [5:0]idx
 *   0x84 = #campioni ADC, 0x88 = #trigger FFT, 0x8C = #IRQ FFT (frame fatti) */
#define FFT_S0_WORDS   ((volatile uint32_t*)0x48000000u)
#define FFT_S0_STATUS  (*(volatile uint32_t*)(0x48000000u + 0x80))
#define FFT_S0_RDY     (*(volatile uint32_t*)(0x48000000u + 0x84))
#define FFT_S0_TRIG    (*(volatile uint32_t*)(0x48000000u + 0x88))
#define FFT_S0_IRQC    (*(volatile uint32_t*)(0x48000000u + 0x8C))
#define DIAG_BINS      78                /* bin 0..77 scanditi dalla diagnostica PK */

/* crt0.S richiede il simbolo irq_handler. L'IRQ non arriva alla CPU (si fa polling),
 * quindi e' uno stub. */
void irq_handler(void) { }

/* ===========================================================================
 * Diagnostica (canale $...\n, inoltrato verbatim dall'ESP32). Token sicuri.
 * =========================================================================== */
static uint32_t g_loops, g_sess, g_ok, g_to;

/* debug_on: 1 = manda i dump diagnostici sul canale $...\n (DEC/PK, SYS/ACC, MAX/F...);
 * 0 = li tace, resta solo la sequenza dei caratteri ricevuti (A/B/C) e i log dell'ESP32.
 * Metterlo a 1 quando serve diagnosticare lo spettro/letture. */
static int debug_on = 0;

static void dbg_begin(void) { uartext_putchar('$'); }
static void dbg_end(void)   { uartext_putchar('\n'); }
static void dbg_str(const char *s) { while (*s) uartext_putchar(*s++); }
static void put_u32(uint32_t v) {
    char b[10]; int i = 0;
    if (v == 0) { uartext_putchar('0'); return; }
    while (v) { b[i++] = (char)('0' + (v % 10u)); v /= 10u; }
    while (i) uartext_putchar(b[--i]);
}
static void put_hh(uint8_t b) {
    static const char H[] = "0123456789ABCDEF";
    uartext_putchar(H[(b >> 4) & 0xF]); uartext_putchar(H[b & 0xF]);
}

static int fft_mag(int bin) {           /* |xk_re| del bin dallo spettro coerente */
    if (bin < 0 || bin >= 512) return 0;
    int16_t v = g_sdram[bin];
    return (v < 0) ? -(int)v : (int)v;
}

/* bin per 'DEC m=' (protocollo carrier+bit c9bf2c0):
 *   carrier master(22) / carrier slave(27) / bit0(39) / bit1(50) / EOF(32) */
static const int DISP_BIN[5] = { 22, 27, 39, 50, 32 };

static void dbg_decode(int got, char d) {
    static uint32_t last = 0;
    uint32_t now = rdcycle32();
    if ((uint32_t)(now - last) < (CPU_HZ / 4u)) return;   /* max ~4/s */
    last = now;

    dbg_begin();
    if (got) {
        dbg_str("DEC m=");
        for (int c = 0; c < 5; c++) {
            put_u32((uint32_t)fft_mag(DISP_BIN[c]));
            if (c < 4) uartext_putchar('/');
        }
        dbg_str(" d="); if (d) put_hh((uint8_t)d); else uartext_putchar('0');
    } else {
        dbg_str("DEC TO");
    }
    dbg_str(" sess="); put_u32(g_sess);
    dbg_str(" ok=");   put_u32(g_ok);
    dbg_str(" to=");   put_u32(g_to);
    dbg_end();

    if (got) {   /* top-2 picchi (bin>=10, salto DC/hum): b1 dovrebbe essere il carrier,
                  * b2 il tono-DATO -> vediamo a che bin/Hz sta e quanto e' forte. */
        int b1 = 0, m1 = 0;
        for (int k = 10; k < DIAG_BINS; k++) { int m = fft_mag(k); if (m > m1) { m1 = m; b1 = k; } }
        int b2 = 0, m2 = 0;
        for (int k = 10; k < DIAG_BINS; k++) {
            if (k >= b1 - 1 && k <= b1 + 1) continue;   /* escludo solo il bin del 1o picco (toni a 2 bin) */
            int m = fft_mag(k); if (m > m2) { m2 = m; b2 = k; }
        }
        dbg_begin();
        dbg_str("PK b1="); put_u32((uint32_t)b1); uartext_putchar('@'); put_u32(((uint32_t)b1 * 46875u) / 512u);
        dbg_str(" m1=");   put_u32((uint32_t)m1);
        dbg_str(" b2=");   put_u32((uint32_t)b2); uartext_putchar('@'); put_u32(((uint32_t)b2 * 46875u) / 512u);
        dbg_str(" m2=");   put_u32((uint32_t)m2);
        dbg_end();
    }
}

/* === DEBUG (dump dei 512 bin dallo snapshot BSRAM, STABILE e attendibile).
 *     Serve a sapere se la SDRAM contiene i dati FFT veri: se F0 mostra bin0 ~1015
 *     (offset DC dell'ADC) la pipe e' viva; se 0 la FFT non arriva in SDRAM. Ora
 *     legge la BSRAM (no race): i bin riflettono davvero lo spettro del frame. */
static uint16_t dbgbuf[20][26];
static void dbg_dump512(void) {
    static uint32_t last = 0;
    uint32_t now = rdcycle32();
    if ((uint32_t)(now - last) < (CPU_HZ * 3u)) return;   /* ~ogni 3s */
    last = now;

    /* lettura DIRETTA e STABILE dalla BSRAM (snapshot del frame, niente race) */
    for (int bin = 0; bin < 512; bin++)
        dbgbuf[bin / 26][bin % 26] = (uint16_t)(FFT_BSRAM[bin] & 0xFFFFu);

    int bmaxi = 0, mmax = 0;                               /* picco (salto DC, bin>=4) */
    for (int bin = 4; bin < 512; bin++) {
        int16_t v = (int16_t)dbgbuf[bin / 26][bin % 26];
        int m = (v < 0) ? -(int)v : (int)v;
        if (m > mmax) { mmax = m; bmaxi = bin; }
    }
    dbg_begin();
    dbg_str("MAX bin="); put_u32((uint32_t)bmaxi);
    uartext_putchar('@'); put_u32(((uint32_t)bmaxi * 46875u) / 512u);
    dbg_str(" m=");      put_u32((uint32_t)mmax);
    dbg_str(" cap=");    put_u32(20u);   /* snapshot BSRAM: sempre completo */
    dbg_end();

    for (int burst = 0; burst < 20; burst++) {            /* tutti i 512 bin, 26/riga */
        dbg_begin();
        dbg_str("F"); put_u32((uint32_t)(burst * 26));
        for (int j = 0; j < 26; j++) {
            int bin = burst * 26 + j;
            if (bin >= 512) break;
            int16_t v = (int16_t)dbgbuf[burst][j];
            int m = (v < 0) ? -(int)v : (int)v;
            uartext_putchar(' '); put_u32((uint32_t)m);
        }
        dbg_end();
    }
}

static void sys_tick(void) {
    static uint32_t last = 0;
    uint32_t now = rdcycle32();
    if ((uint32_t)(now - last) < (uint32_t)CPU_HZ) return;   /* ~1/s */
    last = now;

    dbg_begin();
    dbg_str("SYS lp="); put_u32(g_loops);
    dbg_str(" rx=");    put_u32(emit_rx_count());
    dbg_str(" em=");    put_u32(emit_em_count());
    dbg_str(" q=");     put_u32(emit_queue_len());
    dbg_str(" sess=");  put_u32(g_sess);
    dbg_str(" ok=");    put_u32(g_ok);
    dbg_str(" to=");    put_u32(g_to);
    dbg_end();

    dbg_begin();
    dbg_str("ACC rdy="); put_u32(FFT_S0_RDY);
    dbg_str(" trig=");   put_u32(FFT_S0_TRIG);
    dbg_str(" irq=");    put_u32(FFT_S0_IRQC);
    dbg_str(" cb0=");    put_u32(g_catch_b0);   /* burst0 presi (diag read_sdram) */
    dbg_str(" cb1=");    put_u32(g_catch_b1);   /* burst1 presi: se 0 -> non becca lo stream */
    dbg_str(" b1ix=");   put_u32(g_b1_maxidx);  /* max idx visto sul burst1 (se <26 -> gate) */
    dbg_end();
}

/* ── RX: la CPU legge la SDRAM (read_sdram_collect) in g_sdram[512] in modo coerente,
 *    alza g_sdram_ready, qui lo consumiamo passandolo al decoder (che usa solo i bin
 *    ai target +-3). Niente piu' lettura strappata burst-per-burst. ── */
/* CSMA half-duplex: tengo l'istante in cui ho sentito l'ULTIMA volta il carrier dello
 * slave. Se e' nei 3 s -> canale occupato -> il player non emette (vedi emit_tone.c). */
static uint32_t g_slave_last = 0;
static int      g_slave_seen = 0;
#define CHANNEL_HOLD_CYCLES (3u * CPU_HZ)        /* 3 secondi a 40.5 MHz */

static void decode_step(void) {
    read_sdram_tick();                          /* 1 poll: snapshot BSRAM stabile */
    if (g_sdram_ready) {
        g_sess++;
        if (decode_slave_carrier(g_sdram, 512)) {   /* sento il carrier SLAVE (bin27)? */
            g_slave_last = rdcycle32(); g_slave_seen = 1;
        }
        char d = decode_char(g_sdram, 512);
        g_ok++;
        if (d >= 'A' && d <= 'C') uartext_putchar(d);   /* SOLO RX dallo slave (maiuscole) */
        if (debug_on) dbg_decode(1, d);
        g_sdram_ready = 0;                       /* consumato -> prossima cattura */
    }
    /* canale occupato se il carrier slave e' stato udito negli ultimi 3 s */
    g_channel_busy = (g_slave_seen &&
        (uint32_t)(rdcycle32() - g_slave_last) < CHANNEL_HOLD_CYCLES) ? 1 : 0;
}

int main(void) {
    uartext_init(CPU_HZ, BAUD, UARTEXT_CFG_PARITY_NONE | UARTEXT_CFG_BITS(8));
    uartext_puts("\r\nSYSTEM UP v34 (eof-2472)\r\n");

    DMA_SETBASE = 0;       /* acceleratore audio: base + start (si auto-avvia comunque) */
    DMA_START   = 1;

    for (;;) {
        g_loops++;
        emit_capture();      /* TX */
        emit_player_tick();  /* TX */
        decode_step();       /* RX (polling + decoder) */
        if (debug_on) {
            sys_tick();      /* diagnostica ~1/s */
            dbg_dump512();   /* dump 512 bin ~ogni 3s */
        }
    }
    return 0;
}
