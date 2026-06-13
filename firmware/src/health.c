/*
 * EFES - health check del SoC. Ogni ~2 s legge un registro "sicuro" di ogni
 * slave Wishbone e fa un sanity check sul valore; pubblica la riga
 *   $HLT m=<mask hex S0..S8> adc= fft= nor= lk= hd=<head>
 * sull'UART caratteri (S6), inoltrata dall'ESP32 alla dashboard.
 *
 * S1 (SPI ADC) NON si legge direttamente: l'ack di 0x00 e' gated su data_ready
 * e il DMA (M1, prioritario) lo consuma di continuo -> rischio stallo. La sua
 * salute e' il contatore campioni dell'acceleratore (S0/0x84) che avanza.
 * Se uno slave smette di ackare la CPU resta appesa sulla lettura: il $HLT
 * sparisce e la dashboard marca lo stato come perso (rilevazione implicita).
 */
#include <stdint.h>
#include "health.h"
#include "norflash.h"
#include "emit_tone.h"
#include "display_manager.h"
#include "../include/periphs.h"

#define S0_STATUS   (*(volatile uint32_t*)(0x48000000u + 0x80u))
#define S0_RDYCNT   (*(volatile uint32_t*)(0x48000000u + 0x84u))
#define S0_IRQCNT   (*(volatile uint32_t*)(0x48000000u + 0x8Cu))
#define S2_PWM10    (*(volatile uint32_t*)0x50000000u)
#define S3_PWM4     (*(volatile uint32_t*)0x60000000u)
#define S5_DMA      (*(volatile uint32_t*)0x30000000u)

static uint32_t prev_rdy, prev_irq;
static uint16_t prev_mask = 0;
static int      primed = 0;

static uint16_t s_mask = 0;            /* ultimo stato riportato (per il display) */
static int      s_fft = 0, s_adc = 0;
unsigned health_last_mask(void) { return s_mask; }
int      health_last_fft(void)  { return s_fft; }
int      health_last_adc(void)  { return s_adc; }

/* solo al primo giro: marker prima di ogni prima-lettura di uno slave, cosi' se
 * una lettura non acka e la CPU resta appesa il monitor dice DOVE e' morta */
static void probe(const char *tag) {
    if (primed) return;
    uartext_putchar('$'); uartext_putchar('H'); uartext_putchar('P'); uartext_putchar(' ');
    while (*tag) uartext_putchar(*tag++);
    uartext_putchar('\n');
}

static void put_s(const char *s) { while (*s) uartext_putchar(*s++); }
static void put_u(uint32_t v) {
    char b[10]; int i = 0;
    if (v == 0) { uartext_putchar('0'); return; }
    while (v) { b[i++] = (char)('0' + (v % 10u)); v /= 10u; }
    while (i) uartext_putchar(b[--i]);
}
static void put_hex3(uint32_t v) {
    static const char H[] = "0123456789ABCDEF";
    uartext_putchar(H[(v >> 8) & 0xF]);
    uartext_putchar(H[(v >> 4) & 0xF]);
    uartext_putchar(H[v & 0xF]);
}

void health_tick(void) {
    static uint32_t last = 0;
    uint32_t now = rdcycle32();
    /* prima scansione (probe + baseline) ~3 s dal boot, poi report ogni 15 s */
    uint32_t period = primed ? 15u * CPU_HZ : 3u * CPU_HZ;
    if ((uint32_t)(now - last) < period) return;
    last = now;

    uint32_t v;
    uint16_t m = 0;
    probe("s0");
    uint32_t rdy = S0_RDYCNT, irq = S0_IRQCNT;

    v = S0_STATUS;                                   /* burst<=19 e idx<=26 */
    if (((v >> 8) & 0x1Fu) <= 19u && (v & 0x3Fu) <= 26u) m |= 1u << 0;
    if (primed && rdy != prev_rdy)                   m |= 1u << 1;   /* S1 via S0/0x84 */
    probe("s2");
    if (S2_PWM10 == 0u)                              m |= 1u << 2;
    probe("s3");
    if (S3_PWM4 == 0u)                               m |= 1u << 3;
    probe("s5");
    if (S5_DMA == 0u)                                m |= 1u << 5;
    probe("s6");
    if ((UARTEXT_STATUS & 0xFFFFFFFCu) == 0u)        m |= 1u << 6;
    probe("s7");
    if ((NORUART_STATUS & 0xFFFFFFFCu) == 0u)        m |= 1u << 7;
    probe("s8");
    if ((NORSPI_STATUS & 0xFFFFFFFCu) == 0u)         m |= 1u << 8;
    probe("s4");                                     /* per ultimo: era il piantato */
    if ((GPIO_REG & 0xFFFFFFFEu) == 0u)              m |= 1u << 4;
    probe("done");

    int fft = (primed && irq != prev_irq) ? 1 : 0;
    prev_rdy = rdy; prev_irq = irq;

    /* debounce: una singola lettura sporca non spegne il blocco in dashboard */
    uint16_t rep = (uint16_t)(m | prev_mask);
    prev_mask = m;
    s_mask = rep; s_fft = fft; s_adc = (rep >> 1) & 1;

    /* log sul display quando lo stato degli slave cambia (prima volta inclusa) */
    {
        static uint16_t logged = 0xFFFF;
        if (rep != logged) {
            static const char H[] = "0123456789ABCDEF";
            char b[12];
            b[0]='H'; b[1]='L'; b[2]='T'; b[3]=' '; b[4]='M'; b[5]='=';
            b[6]=H[(rep >> 8) & 0xF]; b[7]=H[(rep >> 4) & 0xF]; b[8]=H[rep & 0xF];
            b[9]=0;
            dm_log(b);
            logged = rep;
        }
    }
    if (!primed) { primed = 1; return; }             /* 1o giro: solo baseline */

    put_s("$HLT m=");  put_hex3(rep);
    put_s(" adc=");    uartext_putchar((rep & (1u << 1)) ? '1' : '0');
    put_s(" fft=");    uartext_putchar(fft ? '1' : '0');
    put_s(" nor=");    uartext_putchar(nor_present() ? '1' : '0');
    put_s(" lk=");     uartext_putchar(nor_locked() ? '1' : '0');
    put_s(" hd=");     put_u((uint32_t)nor_head());
    uartext_putchar('\n');
}
