#include "emit_tone.h"
#include "../include/periphs.h"

/* PWM DDS S2: 0x04 = dat[31:16]=tono(f2), dat[15:0]=carrier(f1) -> start; 0x08 stop. */
#define PWM10_TONES  (*(volatile uint32_t*)(0x50000000u + 0x04))
#define PWM10_STOPW  (*(volatile uint32_t*)(0x50000000u + 0x08))

#define TONE_MS   144u   /* tono raddoppiato (era 72) -> piu' frame FFT/simbolo al RX */
#define SIL_MS    400u   /* pausa fra i toni = 400 ms (era 350) */
#define WARMUP_MS 300u   /* EOF di warmup (char 'd'/'D'): tono lungo per assestare l'AGC
                          * del mic del ricevitore prima del frame. E' EOF -> flush a vuoto */

static uint32_t s_rx = 0;     /* char catturati */
static uint32_t s_em = 0;     /* toni completati */

static int is_proto(uint8_t c) {
    /* a-c / A-C = simboli del protocollo; d/D = EOF di WARMUP (tono lungo, vedi player) */
    return (c >= 'a' && c <= 'd') || (c >= 'A' && c <= 'D');
}

/* char -> parola PWM. UN TONO ALLA VOLTA: metto la freq del simbolo in f1 [15:0], f2=0
 * [31:16] (oscillatore 2 spento). Stesse 3 frequenze del decode (half-duplex condiviso).
 * 'd'/'D' = EOF di warmup (stessa freq di 'c'/'C', cambia solo la durata nel player). */
static int tone_word_for_char(char ch, uint32_t *word) {
    int sig = 0;
    if      (ch == 'd') ch = 'c';
    else if (ch == 'D') ch = 'C';
    char up = (ch >= 'a' && ch <= 'z') ? (char)(ch - 32) : ch;
    switch (up) {
        case 'A': sig = 1200; break;   /* bit 0 -> bin13 */
        case 'B': sig = 1700; break;   /* bit 1 -> bin19 */
        case 'C': sig = 2472; break;   /* EOF   -> bin27 */
        default: return 0;
    }
    *word = (uint32_t)sig;             /* f1=sig (tono), f2=0 (spento) */
    return 1;
}

/* ---- coda SW dei char da suonare ---- */
#define TXQ_LEN 16u
static uint8_t  tone_q[TXQ_LEN];
static unsigned q_head = 0, q_tail = 0, q_count = 0;

static void enqueue(uint8_t c) {
    if (q_count >= TXQ_LEN) { q_tail = (q_tail + 1u) % TXQ_LEN; q_count--; }
    tone_q[q_head] = c; q_head = (q_head + 1u) % TXQ_LEN; q_count++;
}
static int dequeue(uint8_t *c) {
    if (q_count == 0) return 0;
    *c = tone_q[q_tail]; q_tail = (q_tail + 1u) % TXQ_LEN; q_count--; return 1;
}

/* ---- player toni (FSM non bloccante) ---- */
typedef enum { P_IDLE, P_TONE, P_SIL } pstate_t;
static pstate_t pstate = P_IDLE;
static uint32_t p_t0 = 0;
static int      p_warm = 0;     /* il tono in corso e' un EOF di warmup ('d'/'D') -> lungo */

void emit_capture(void) {
    if (UARTEXT_STATUS & 0x2u) {                 /* bit1 = rx_valid (non consuma) */
        uint8_t ch = (uint8_t)(UARTEXT_DATA & 0xFFu);  /* bit8 race -> ignorato */
        if (is_proto(ch)) { enqueue(ch); s_rx++; }
    }
}

void emit_player_tick(void) {
    uint32_t now = rdcycle32();
    uint8_t ch; uint32_t word;
    switch (pstate) {
        case P_IDLE:
            if (dequeue(&ch) && tone_word_for_char((char)ch, &word)) {
                PWM10_TONES = word; p_t0 = now;
                p_warm = (ch == 'd' || ch == 'D');   /* EOF di warmup -> tono lungo */
                pstate = P_TONE;
            }
            break;
        case P_TONE:
            if ((now - p_t0) >= ms_to_cycles(p_warm ? WARMUP_MS : TONE_MS)) {
                PWM10_STOPW = 1; p_t0 = now; pstate = P_SIL;
            }
            break;
        case P_SIL:
            if ((now - p_t0) >= ms_to_cycles(SIL_MS)) {
                s_em++; pstate = P_IDLE;
            }
            break;
    }
}

uint32_t emit_rx_count(void)  { return s_rx; }
uint32_t emit_em_count(void)  { return s_em; }
unsigned emit_queue_len(void) { return q_count; }
int      emit_busy(void)      { return pstate != P_IDLE; }
