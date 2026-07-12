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

/* Protocollo CARRIER + BIT (c9bf2c0): il MASTER emette SEMPRE il proprio carrier
 * (bin22 ~2014 Hz) PIU' il tono-dato, come DUE toni simultanei sul DDS PWM (la HW
 * somma sin(f1)+sin(f2)). Lo slave decodifica il carrier master (=ci sente il
 * mittente) + il bit. Frequenze = centro-bin a fs=46875, N=512 (bin*91.55 Hz). */
#define CARRIER_MASTER 2014   /* bin22: carrier del master (sempre presente in TX) */
#define F_BIT0         3571   /* bin39: bit 0 */
#define F_BIT1         4577   /* bin50: bit 1 */
#define F_EOF          2930   /* bin32: EOF */

/* char -> parola PWM a DUE toni: f1[15:0]=carrier master, f2[31:16]=tono-dato.
 * 'A'/'a'->bit0, 'B'/'b'->bit1, 'C'/'c'->EOF. 'd'/'D' = EOF di warmup (tono lungo). */
static int tone_word_for_char(char ch, uint32_t *word) {
    int f2 = 0;
    if      (ch == 'd') ch = 'c';
    else if (ch == 'D') ch = 'C';
    char up = (ch >= 'a' && ch <= 'z') ? (char)(ch - 32) : ch;
    switch (up) {
        case 'A': f2 = F_BIT0; break;   /* bit 0 -> bin39 */
        case 'B': f2 = F_BIT1; break;   /* bit 1 -> bin50 */
        case 'C': f2 = F_EOF;  break;   /* EOF   -> bin32 */
        default: return 0;
    }
    *word = ((uint32_t)f2 << 16) | (uint32_t)CARRIER_MASTER;   /* f2=dato, f1=carrier */
    return 1;
}

/* Stato del canale (aggiornato dal decode in main.c): 1 = sto sentendo il carrier
 * dello SLAVE -> non devo parlare / se sto parlando mi interrompo (CSMA half-duplex). */
volatile int g_channel_busy = 0;

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
            /* CSMA: non parlo se il canale e' occupato dallo slave (carrier slave udito
             * negli ultimi 3 s). Tengo il char in coda e riprovo al giro dopo. */
            if (!g_channel_busy && dequeue(&ch) && tone_word_for_char((char)ch, &word)) {
                PWM10_TONES = word; p_t0 = now;
                p_warm = (ch == 'd' || ch == 'D');   /* EOF di warmup -> tono lungo */
                pstate = P_TONE;
            }
            break;
        case P_TONE:
            /* niente CSMA a meta' emissione: il master sentiva il PROPRIO carrier
             * (bin22) come se fosse lo slave (bin27) e si auto-interrompeva. Il gate
             * CSMA resta solo in P_IDLE (parto se il canale e' libero da 3 s). Una
             * volta partito, il tono va sempre a fondo, non lo interrompe piu' niente. */
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
