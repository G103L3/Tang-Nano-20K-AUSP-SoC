/*
 * EFES - mini-dashboard sul TFT ST7789 (GMT020-02-7P) via spi_display (S9).
 * Vedi display_manager.h per il layout a 4 zone e i view flags.
 *
 * Architettura non bloccante: una coda di "job" (fill rettangolo / testo) e un
 * esecutore che a ogni display_tick() spinge al massimo ~128-200 byte SPI,
 * cosi' il loop principale resta reattivo (FIFO UART da 16 mai saturata).
 * I colori vengono dai settings in NOR (nor_colors) e a ogni save (epoch)
 * il display si ridisegna da zero con tema e zone aggiornati.
 */
#include <stdint.h>
#include "display_manager.h"
#include "emit_tone.h"      /* rdcycle32, ms_to_cycles, emit_* */
#include "norflash.h"       /* nor_colors, nor_views, nor_settings_epoch */
#include "health.h"         /* health_last_mask/fft/adc */
#include "read_sdram.h"     /* g_sdram[512] */
#include "../include/periphs.h"

#define S0_IRQCNT   (*(volatile uint32_t*)(0x48000000u + 0x8Cu))

/* link -nostdlib: GCC emette memcpy per le copie di struct (job_t) */
void *memcpy(void *dst, const void *src, unsigned long n) {
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    while (n--) *d++ = *s++;
    return dst;
}

/* ---- geometria: landscape 320x240, 4 zone ---- */
#define SCR_W 320
#define SCR_H 240
typedef struct { uint16_t x, y, w, h; } rect_t;
static const rect_t ZR[4] = {
    {   0,   0,  96, 240 },     /* 0 = sinistra      */
    {  96,   0, 128, 120 },     /* 1 = alto-centro   */
    {  96, 120, 128, 120 },     /* 2 = basso-centro  */
    { 224,   0,  96, 240 },     /* 3 = destra        */
};
#define TITLE_H 16

enum { CON_NONE, CON_SLAVES, CON_RX, CON_WAVE, CON_IRQ, CON_LOGS, CON_TX, CON_PEAKS };

#define C_GREEN 0x07E0u
#define C_RED   0xF800u
#define C_AMBER 0xFD20u

static uint16_t c_main, c_text, c_bg;

/* ---- dati per le zone ---- */
static char     rx_last = '-';
static uint32_t rx_cnt = 0;
#define LOG_N 6
static char     logring[LOG_N][21];
static unsigned log_head = 0, log_n = 0;
static uint32_t irq_prev = 0;

/* uptime in secondi (accumulo delta rdcycle in display_tick: regge il wrap) */
static uint32_t up_s = 0, up_last = 0, up_acc = 0;

void dm_note_rx(char c) { rx_last = c; rx_cnt++; }

/* ogni riga di log porta il prefisso uptime "NNNs " */
void dm_log(const char *s) {
    char *d = logring[log_head];
    unsigned i = 0;
    char t[10]; int ti = 0;
    uint32_t v = up_s;
    if (v == 0) t[ti++] = '0';
    while (v && ti < 6) { t[ti++] = (char)('0' + (v % 10u)); v /= 10u; }
    while (ti) d[i++] = t[--ti];
    d[i++] = 'S'; d[i++] = ' ';
    for (unsigned k = 0; s[k] && i < sizeof(logring[0]) - 1; k++) d[i++] = s[k];
    d[i] = 0;
    log_head = (log_head + 1) % LOG_N;
    if (log_n < LOG_N) log_n++;
}

/* =================== livello basso ST7789 (S9) =================== */
static uint8_t ctrl_sh = 0;     /* bit0 DC, bit1 RST, bit2 CS */

static void dsp_ctrl(int dc, int rst, int cs) {
    ctrl_sh = (uint8_t)((dc ? 1 : 0) | (rst ? 2 : 0) | (cs ? 4 : 0));
    DISP_CTRL = ctrl_sh;
}
static void wait_idle(void) {
    uint32_t t0 = rdcycle32();
    while (DISP_STATUS & 1u) {
        if ((uint32_t)(rdcycle32() - t0) > ms_to_cycles(1)) break;
    }
}
static void wr8(uint8_t b) { wait_idle(); DISP_TXDATA = b; }
static void cmd8(uint8_t c) {
    wait_idle(); DISP_CTRL = (uint8_t)(ctrl_sh & ~1u);   /* DC=0 comando */
    wr8(c);
    wait_idle(); DISP_CTRL = (uint8_t)(ctrl_sh | 1u);    /* DC=1 dato */
}
static void dat16(uint16_t v) { wr8((uint8_t)(v >> 8)); wr8((uint8_t)v); }
static void window(uint16_t x, uint16_t y, uint16_t w, uint16_t h) {
    cmd8(0x2A); dat16(x); dat16((uint16_t)(x + w - 1));
    cmd8(0x2B); dat16(y); dat16((uint16_t)(y + h - 1));
    cmd8(0x2C);
}
static void px(uint16_t c) { wr8((uint8_t)(c >> 8)); wr8((uint8_t)c); }

/* =================== font 5x7 (0x20..0x5A, colonne, bit0=riga alta) ============ */
static const uint8_t font5x7[][5] = {
    {0x00,0x00,0x00,0x00,0x00},{0x00,0x00,0x5F,0x00,0x00},{0x00,0x07,0x00,0x07,0x00},
    {0x14,0x7F,0x14,0x7F,0x14},{0x24,0x2A,0x7F,0x2A,0x12},{0x23,0x13,0x08,0x64,0x62},
    {0x36,0x49,0x55,0x22,0x50},{0x00,0x05,0x03,0x00,0x00},{0x00,0x1C,0x22,0x41,0x00},
    {0x00,0x41,0x22,0x1C,0x00},{0x08,0x2A,0x1C,0x2A,0x08},{0x08,0x08,0x3E,0x08,0x08},
    {0x00,0x50,0x30,0x00,0x00},{0x08,0x08,0x08,0x08,0x08},{0x00,0x60,0x60,0x00,0x00},
    {0x20,0x10,0x08,0x04,0x02},{0x3E,0x51,0x49,0x45,0x3E},{0x00,0x42,0x7F,0x40,0x00},
    {0x42,0x61,0x51,0x49,0x46},{0x21,0x41,0x45,0x4B,0x31},{0x18,0x14,0x12,0x7F,0x10},
    {0x27,0x45,0x45,0x45,0x39},{0x3C,0x4A,0x49,0x49,0x30},{0x01,0x71,0x09,0x05,0x03},
    {0x36,0x49,0x49,0x49,0x36},{0x06,0x49,0x49,0x29,0x1E},{0x00,0x36,0x36,0x00,0x00},
    {0x00,0x56,0x36,0x00,0x00},{0x00,0x08,0x14,0x22,0x41},{0x14,0x14,0x14,0x14,0x14},
    {0x41,0x22,0x14,0x08,0x00},{0x02,0x01,0x51,0x09,0x06},{0x32,0x49,0x79,0x41,0x3E},
    {0x7E,0x11,0x11,0x11,0x7E},{0x7F,0x49,0x49,0x49,0x36},{0x3E,0x41,0x41,0x41,0x22},
    {0x7F,0x41,0x41,0x22,0x1C},{0x7F,0x49,0x49,0x49,0x41},{0x7F,0x09,0x09,0x09,0x01},
    {0x3E,0x41,0x41,0x51,0x32},{0x7F,0x08,0x08,0x08,0x7F},{0x00,0x41,0x7F,0x41,0x00},
    {0x20,0x40,0x41,0x3F,0x01},{0x7F,0x08,0x14,0x22,0x41},{0x7F,0x40,0x40,0x40,0x40},
    {0x7F,0x02,0x0C,0x02,0x7F},{0x7F,0x04,0x08,0x10,0x7F},{0x3E,0x41,0x41,0x41,0x3E},
    {0x7F,0x09,0x09,0x09,0x06},{0x3E,0x41,0x51,0x21,0x5E},{0x7F,0x09,0x19,0x29,0x46},
    {0x46,0x49,0x49,0x49,0x31},{0x01,0x01,0x7F,0x01,0x01},{0x3F,0x40,0x40,0x40,0x3F},
    {0x1F,0x20,0x40,0x20,0x1F},{0x7F,0x20,0x18,0x20,0x7F},{0x63,0x14,0x08,0x14,0x63},
    {0x07,0x08,0x70,0x08,0x07},{0x61,0x51,0x49,0x45,0x43},
};
static const uint8_t *glyph(char c) {
    if (c >= 'a' && c <= 'z') c = (char)(c - 32);
    if (c < 0x20 || c > 0x5A) c = '?';
    return font5x7[c - 0x20];
}

/* =================== coda job + esecutore a chunk =================== */
typedef struct {
    uint8_t  kind;              /* 0 = fill, 1 = testo, 2 = barra verticale */
    uint16_t x, y, w, h;        /* fill/vbar: rettangolo; testo: origine, w = scala */
    uint16_t fg, bg;
    uint16_t aux;               /* vbar: altezza della barra (fg in basso, bg sopra) */
    char     txt[22];
} job_t;
#define JOBQ_N 48
static job_t   jq[JOBQ_N];
static unsigned jq_head = 0, jq_count = 0;

static void job_push(const job_t *j) {
    if (jq_count >= JOBQ_N) return;                  /* coda piena: si perde un elemento */
    jq[(jq_head + jq_count) % JOBQ_N] = *j;
    jq_count++;
}
static void job_fill(uint16_t x, uint16_t y, uint16_t w, uint16_t h, uint16_t c) {
    job_t j; j.kind = 0; j.x = x; j.y = y; j.w = w; j.h = h; j.fg = c; j.bg = c;
    j.aux = 0; j.txt[0] = 0;
    job_push(&j);
}
static void job_text(uint16_t x, uint16_t y, uint8_t scale, uint16_t fg, uint16_t bg, const char *s) {
    job_t j; unsigned i = 0;
    j.kind = 1; j.x = x; j.y = y; j.w = scale; j.h = 0; j.fg = fg; j.bg = bg; j.aux = 0;
    for (; s[i] && i < sizeof(j.txt) - 1; i++) j.txt[i] = s[i];
    j.txt[i] = 0;
    job_push(&j);
}
/* colonna completa: bg sopra + barra fg in basso -> overwrite senza flicker */
static void job_vbar(uint16_t x, uint16_t y, uint16_t w, uint16_t h,
                     uint16_t bar_h, uint16_t fg, uint16_t bg) {
    job_t j; j.kind = 2; j.x = x; j.y = y; j.w = w; j.h = h; j.fg = fg; j.bg = bg;
    j.aux = (bar_h > h) ? h : bar_h; j.txt[0] = 0;
    job_push(&j);
}

static job_t    ex;
static int      ex_active = 0;
static uint32_t ex_rem = 0;      /* fill/vbar: pixel rimanenti */
static uint32_t ex_tot = 0;      /* vbar: pixel totali (per ricavare la riga) */
static unsigned ex_ci = 0;       /* testo: indice carattere */

static void ex_start(void) {
    ex = jq[jq_head];
    jq_head = (jq_head + 1) % JOBQ_N;
    jq_count--;
    ex_active = 1;
    if (ex.kind == 0 || ex.kind == 2) {
        window(ex.x, ex.y, ex.w, ex.h);
        ex_tot = (uint32_t)ex.w * ex.h;
        ex_rem = ex_tot;
    } else {
        ex_ci = 0;
    }
}

static void ex_chunk(void) {
    if (ex.kind == 0) {                              /* fill: max 64 px per tick */
        uint32_t n = (ex_rem > 64u) ? 64u : ex_rem;
        for (uint32_t i = 0; i < n; i++) px(ex.fg);
        ex_rem -= n;
        if (ex_rem == 0) ex_active = 0;
    } else if (ex.kind == 2) {                       /* vbar: bg sopra, fg in basso */
        uint32_t n = (ex_rem > 64u) ? 64u : ex_rem;
        for (uint32_t i = 0; i < n; i++) {
            uint32_t row = (ex_tot - ex_rem + i) / ex.w;
            px((row >= (uint32_t)(ex.h - ex.aux)) ? ex.fg : ex.bg);
        }
        ex_rem -= n;
        if (ex_rem == 0) ex_active = 0;
    } else {                                         /* testo: 1 carattere per tick */
        char c = ex.txt[ex_ci];
        if (c == 0) { ex_active = 0; return; }
        unsigned s = ex.w ? ex.w : 1;
        const uint8_t *g = glyph(c);
        window((uint16_t)(ex.x + ex_ci * 6 * s), ex.y, (uint16_t)(6 * s), (uint16_t)(8 * s));
        for (unsigned row = 0; row < 8 * s; row++) {
            unsigned fr = row / s;
            for (unsigned col = 0; col < 6 * s; col++) {
                unsigned fc = col / s;
                int on = (fc < 5 && fr < 7) ? ((g[fc] >> fr) & 1) : 0;
                px(on ? ex.fg : ex.bg);
            }
        }
        ex_ci++;
        if (ex.txt[ex_ci] == 0) ex_active = 0;
    }
}

/* =================== helper stringhe =================== */
static char *sapp(char *p, const char *s) { while (*s) *p++ = *s++; *p = 0; return p; }
static char *sappu(char *p, uint32_t v) {
    char b[10]; int i = 0;
    if (v == 0) { *p++ = '0'; *p = 0; return p; }
    while (v) { b[i++] = (char)('0' + (v % 10u)); v /= 10u; }
    while (i) *p++ = b[--i];
    *p = 0; return p;
}

/* =================== contenuti delle zone =================== */
static int zone_content(int z) {
    uint8_t v = nor_views();
    switch (z) {
        case 0: return (v & 0x04) ? CON_SLAVES : (v & 0x40) ? CON_TX    : CON_NONE;
        case 1: return (v & 0x01) ? CON_WAVE   : (v & 0x10) ? CON_PEAKS : CON_NONE;
        case 2: return (v & 0x02) ? CON_LOGS   : CON_NONE;
        default: return (v & 0x20) ? CON_RX    : (v & 0x08) ? CON_IRQ   : CON_NONE;
    }
}
static const char *con_title(int con) {
    switch (con) {
        case CON_SLAVES: return "SLAVES";
        case CON_RX:     return "RX PKT";
        case CON_WAVE:   return "ONDA";
        case CON_IRQ:    return "IRQ DMA";
        case CON_LOGS:   return "MEMORIA";
        case CON_TX:     return "TX PKT";
        case CON_PEAKS:  return "PEAKS";
        default:         return "---";
    }
}

static void emit_static(int z) {
    const rect_t *r = &ZR[z];
    job_fill(r->x, r->y, r->w, r->h, c_bg);
    job_fill((uint16_t)(r->x + 2), (uint16_t)(r->y + 2), (uint16_t)(r->w - 4), TITLE_H, c_main);
    job_text((uint16_t)(r->x + 6), (uint16_t)(r->y + 6), 1, c_bg, c_main, con_title(zone_content(z)));
}

static int fft_abs(int bin) {
    int16_t v = g_sdram[bin];
    return (v < 0) ? -(int)v : (int)v;
}

/* bin del protocollo (fs=46875, N=512): carrier master 22 (2000 Hz),
 * carrier slave 26 (2400), EOF 32 (2900), bit0 38 (3500), bit1 49 (4500) */
#define WB_LO 16
#define WB_HI 55
static int is_proto_bin(int b) {
    return b == 22 || b == 26 || b == 32 || b == 38 || b == 39 || b == 49 || b == 50;
}
static int near_bin(int b, int t) { return b >= t - 1 && b <= t + 1; }

/* numero compatto per le cifre grandi nelle zone strette (>99999 -> migliaia+K) */
static char *sappuk(char *p, uint32_t v) {
    if (v > 99999u) { p = sappu(p, v / 1000u); return sapp(p, "K"); }
    return sappu(p, v);
}

/* pad (e tronca) a larghezza fissa: i refresh SOVRASCRIVONO il vecchio testo
 * senza clear della zona -> niente flicker al ritmo di 150 ms */
static void padto(char *buf, unsigned n) {
    unsigned l = 0;
    while (buf[l] && l < n) l++;
    while (l < n) buf[l++] = ' ';
    buf[l] = 0;
}

static void emit_content(int z) {
    const rect_t *r = &ZR[z];
    uint16_t cx = (uint16_t)(r->x + 4), cy = (uint16_t)(r->y + TITLE_H + 6);
    uint16_t cw = (uint16_t)(r->w - 8),  ch = (uint16_t)(r->h - TITLE_H - 10);
    char buf[22], *p;
    (void)cw;

    switch (zone_content(z)) {

        case CON_SLAVES: {
            unsigned m = health_last_mask();
            for (int i = 0; i < 9; i++) {
                int ok = (m >> i) & 1;
                p = sapp(buf, "S"); p = sappu(p, (uint32_t)i);
                p = sapp(p, ok ? "  OK" : "  KO");
                job_text((uint16_t)(cx + 4), (uint16_t)(cy + 4 + i * 18), 1,
                         ok ? C_GREEN : C_RED, c_bg, buf);
            }
            job_text((uint16_t)(cx + 4), (uint16_t)(cy + 4 + 9 * 18), 1,
                     nor_present() ? C_GREEN : C_RED, c_bg,
                     nor_present() ? "NOR OK" : "NOR KO");
            break;
        }

        case CON_RX: {
            job_text((uint16_t)(cx + 4), cy, 1, c_text, c_bg, "ULTIMO:");
            buf[0] = rx_last; buf[1] = 0;
            job_text((uint16_t)(cx + cw / 2 - 6), (uint16_t)(cy + 24), 2, c_main, c_bg, buf);
            p = sapp(buf, "N="); p = sappu(p, rx_cnt); padto(buf, 13);
            job_text((uint16_t)(cx + 4), (uint16_t)(cy + 64), 1, c_text, c_bg, buf);
            break;
        }

        case CON_WAVE: {                             /* spettro: un rettangolo per bin
                                                        analizzato (16..55), altezza =
                                                        magnitude, autoscala sul max;
                                                        bin di protocollo in accent.
                                                        vbar = colonna intera (bg sopra,
                                                        barra sotto): refresh senza flicker */
            uint16_t bh = (uint16_t)(ch - 14);
            int vmax = 60;
            for (int b = WB_LO; b <= WB_HI; b++) {
                int a = fft_abs(b);
                if (a > vmax) vmax = a;
            }
            for (int b = WB_LO; b <= WB_HI; b++) {
                uint32_t h = (uint32_t)fft_abs(b) * bh / (uint32_t)vmax;
                if (h > bh) h = bh;
                if (h < 1)  h = 1;
                job_vbar((uint16_t)(cx + (b - WB_LO) * 3), cy, 2, bh,
                         (uint16_t)h, is_proto_bin(b) ? c_main : c_text, c_bg);
            }
            job_text((uint16_t)(cx + 2), (uint16_t)(cy + bh + 4), 1, c_text, c_bg,
                     "1.5-5KHZ B16-55");
            break;
        }

        case CON_IRQ: {
            uint32_t irqc = S0_IRQCNT;
            job_text((uint16_t)(cx + 4), cy, 1, c_text, c_bg, "FFT FATTE:");
            p = sappuk(buf, irqc); padto(buf, 7);
            job_text((uint16_t)(cx + 4), (uint16_t)(cy + 20), 2, c_main, c_bg, buf);
            p = sapp(buf, "+"); p = sappu(p, irqc - irq_prev); p = sapp(p, " NUOVE");
            padto(buf, 13);
            job_text((uint16_t)(cx + 4), (uint16_t)(cy + 48), 1, c_text, c_bg, buf);
            irq_prev = irqc;
            break;
        }

        case CON_LOGS: {                             /* memoria persistente NOR: gli
                                                        stessi record della dashboard
                                                        (#seq tipo testo tempo), letti
                                                        dalla flash via S8. Cache
                                                        rinfrescata solo quando head
                                                        cambia (append nuovi). */
            static uint8_t dlog[6][16];
            static int dlog_n = 0;
            static uint32_t dlog_epoch = 0xFFFFFFFFu;
            if (nor_log_epoch() != dlog_epoch) {
                dlog_epoch = nor_log_epoch();
                dlog_n = 0;
                for (int back = 0; back < 12 && dlog_n < 6; back++)
                    if (nor_log_get(back, dlog[dlog_n])) dlog_n++;
            }
            for (int i = 0; i < dlog_n; i++) {
                const uint8_t *rc = dlog[i];
                uint32_t seq = ((uint32_t)rc[0] << 8) | rc[1];
                uint32_t ts  = ((uint32_t)rc[3] << 24) | ((uint32_t)rc[4] << 16) |
                               ((uint32_t)rc[5] << 8)  |  (uint32_t)rc[6];
                p = sapp(buf, "#"); p = sappu(p, seq % 10000u);
                p = sapp(p, " ");
                *p++ = (char)rc[2]; *p = 0;          /* tipo: B/R/P/N/E */
                p = sapp(p, " ");
                for (int k = 8; k < 16; k++) {       /* testo (note, eventi) */
                    char c = (char)rc[k];
                    if (c < 0x20 || c > 0x7E) break;
                    *p++ = c;
                }
                *p = 0;
                p = sapp(p, " ");
                {
                    uint32_t tv; char suf;
                    if (ts < 60u)        { tv = ts;         suf = 'S'; }
                    else if (ts < 3600u) { tv = ts / 60u;   suf = 'M'; }
                    else                 { tv = ts / 3600u; suf = 'H'; if (tv > 99u) tv = 99u; }
                    p = sappu(p, tv); *p++ = suf; *p = 0;
                }
                padto(buf, 20);
                job_text((uint16_t)(cx + 2), (uint16_t)(cy + 2 + i * 14), 1,
                         (i == 0) ? c_main : c_text, c_bg, buf);
            }
            if (dlog_n == 0) {
                p = sapp(buf, nor_present() ? "VUOTA" : "NOR ASSENTE");
                padto(buf, 20);
                job_text((uint16_t)(cx + 2), (uint16_t)(cy + 2), 1, c_text, c_bg, buf);
            }
            break;
        }

        case CON_TX: {
            job_text((uint16_t)(cx + 4), cy, 1, c_text, c_bg, "EMESSI:");
            p = sappuk(buf, emit_em_count()); padto(buf, 7);
            job_text((uint16_t)(cx + 4), (uint16_t)(cy + 20), 2, c_main, c_bg, buf);
            p = sapp(buf, "CODA "); p = sappu(p, emit_queue_len()); padto(buf, 13);
            job_text((uint16_t)(cx + 4), (uint16_t)(cy + 48), 1, c_text, c_bg, buf);
            break;
        }

        case CON_PEAKS: {                            /* coppia di picchi piu' alta nei bin
                                                        di protocollo + Hz + simbolo */
            int b1 = WB_LO, m1 = 0, b2 = WB_LO, m2 = 0;
            for (int b = WB_LO; b <= WB_HI; b++) {
                int a = fft_abs(b);
                if (a > m1) { m1 = a; b1 = b; }
            }
            for (int b = WB_LO; b <= WB_HI; b++) {
                if (b >= b1 - 2 && b <= b1 + 2) continue;
                int a = fft_abs(b);
                if (a > m2) { m2 = a; b2 = b; }
            }
            p = sapp(buf, "B");  p = sappu(p, (uint32_t)b1);
            p = sapp(p, " ");    p = sappu(p, (uint32_t)b1 * 46875u / 512u);
            p = sapp(p, "HZ M"); p = sappu(p, (uint32_t)m1);
            padto(buf, 20);
            job_text((uint16_t)(cx + 2), (uint16_t)(cy + 2), 1, c_main, c_bg, buf);
            p = sapp(buf, "B");  p = sappu(p, (uint32_t)b2);
            p = sapp(p, " ");    p = sappu(p, (uint32_t)b2 * 46875u / 512u);
            p = sapp(p, "HZ M"); p = sappu(p, (uint32_t)m2);
            padto(buf, 20);
            job_text((uint16_t)(cx + 2), (uint16_t)(cy + 16), 1, c_text, c_bg, buf);

            /* traduzione carattere: carrier (master 22 / slave 26) + tono dati */
            {
                int mast = near_bin(b1, 22) || near_bin(b2, 22);
                int slav = near_bin(b1, 26) || near_bin(b2, 26);
                int d0 = near_bin(b1, 38) || near_bin(b2, 38) || near_bin(b1, 39) || near_bin(b2, 39);
                int d1 = near_bin(b1, 49) || near_bin(b2, 49) || near_bin(b1, 50) || near_bin(b2, 50);
                int de = near_bin(b1, 32) || near_bin(b2, 32);
                char sym = (d0 ? 'A' : d1 ? 'B' : de ? 'C' : '-');
                if (!mast && !slav) sym = '-';
                p = sapp(buf, "SIMBOLO ");
                p = sapp(p, slav ? "SLAVE" : (mast ? "MASTER" : "-"));
                padto(buf, 20);
                job_text((uint16_t)(cx + 2), (uint16_t)(cy + 38), 1, c_text, c_bg, buf);
                buf[0] = sym; buf[1] = 0;
                job_text((uint16_t)(cx + cw / 2 - 6), (uint16_t)(cy + 54), 2,
                         (sym == '-') ? c_text : C_GREEN, c_bg, buf);
            }
            break;
        }

        default:
            break;
    }
}

/* =================== fasi: reset -> init -> run =================== */
enum { PH_RST0, PH_RST1, PH_INIT, PH_RUN };
static uint8_t  phase = PH_RST0;
static uint32_t ph_t = 0;
static unsigned init_ix = 0;
static uint32_t init_wait = 0;

static const struct { uint8_t cmd; uint8_t n; uint8_t d[2]; uint8_t delay_ms; } iseq[] = {
    { 0x01, 0, {0, 0},    150 },     /* SWRESET */
    { 0x11, 0, {0, 0},    120 },     /* SLPOUT  */
    { 0x3A, 1, {0x55, 0},  10 },     /* COLMOD 16 bpp */
    { 0x36, 1, {0x60, 0},   0 },     /* MADCTL landscape */
    { 0x21, 0, {0, 0},      0 },     /* INVON (pannello IPS) */
    { 0x13, 0, {0, 0},     10 },     /* NORON */
    { 0x29, 0, {0, 0},     50 },     /* DISPON */
};
#define ISEQ_N (sizeof(iseq) / sizeof(iseq[0]))

static uint32_t seen_epoch = 0xFFFFFFFFu;
static uint8_t  statics_dirty = 0, content_dirty = 0;
static unsigned rot = 0;
static uint32_t last_rot = 0;

static uint16_t rgb565(const uint8_t *rgb) {
    return (uint16_t)(((rgb[0] & 0xF8u) << 8) | ((rgb[1] & 0xFCu) << 3) | (rgb[2] >> 3));
}

static void run_tick(uint32_t now) {
    if (ex_active) { ex_chunk(); return; }
    if (jq_count)  { ex_start(); return; }

    if (nor_settings_epoch() != seen_epoch) {        /* tema/zone cambiati -> redraw */
        seen_epoch = nor_settings_epoch();
        const uint8_t *c = nor_colors();
        c_main = rgb565(c); c_text = rgb565(c + 3); c_bg = rgb565(c + 6);
        job_fill(0, 0, SCR_W, SCR_H, c_bg);
        statics_dirty = 0x0F; content_dirty = 0x0F;
        return;
    }
    for (int z = 0; z < 4; z++) {
        if (statics_dirty & (1u << z)) { statics_dirty &= (uint8_t)~(1u << z); emit_static(z); return; }
    }
    for (int z = 0; z < 4; z++) {
        if (content_dirty & (1u << z)) { content_dirty &= (uint8_t)~(1u << z); emit_content(z); return; }
    }
    if ((uint32_t)(now - last_rot) >= ms_to_cycles(150)) {    /* refresh a rotazione:
                                                                 1 zona ogni 150 ms ->
                                                                 tutte ogni 600 ms */
        last_rot = now;
        content_dirty |= (uint8_t)(1u << rot);
        rot = (rot + 1) & 3;
    }
}

void display_tick(void) {
    uint32_t now = rdcycle32();
    up_acc += (uint32_t)(now - up_last);
    up_last = now;
    while (up_acc >= CPU_HZ) { up_s++; up_acc -= CPU_HZ; }
    switch (phase) {
        case PH_RST0:                                /* RST basso, CS asserito */
            dsp_ctrl(0, 0, 1);
            ph_t = now;
            phase = PH_RST1;
            return;
        case PH_RST1:
            if ((uint32_t)(now - ph_t) < ms_to_cycles(20)) return;
            dsp_ctrl(0, 1, 1);                       /* rilascia il reset */
            init_wait = now + ms_to_cycles(150);
            init_ix = 0;
            phase = PH_INIT;
            return;
        case PH_INIT:
            if ((int32_t)(now - init_wait) < 0) return;
            if (init_ix >= ISEQ_N) { phase = PH_RUN; return; }
            cmd8(iseq[init_ix].cmd);
            for (unsigned i = 0; i < iseq[init_ix].n; i++) wr8(iseq[init_ix].d[i]);
            wait_idle();
            init_wait = now + ms_to_cycles(iseq[init_ix].delay_ms);
            init_ix++;
            return;
        default:
            run_tick(now);
            return;
    }
}
