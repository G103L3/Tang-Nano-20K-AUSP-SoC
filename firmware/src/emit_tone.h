/*! \file emit_tone.h
 * \brief Emissione (TX) sul soft core: legge i char di protocollo dall'UART caratteri
 *        (S6) e li suona come due toni (carrier+segnale) sulla PWM DDS (S2), tutto NON
 *        bloccante (coda SW + player a tempo via rdcycle). Estratto da main.c.
 */
#ifndef EMIT_TONE_H_
#define EMIT_TONE_H_
#include <stdint.h>

#define CPU_HZ 40500000u

/* contatore cicli (ENABLE_COUNTERS=1: conta i cicli reali a 40.5 MHz) */
static inline uint32_t rdcycle32(void) {
    uint32_t c;
    __asm__ volatile ("rdcycle %0" : "=r"(c));
    return c;
}
static inline uint32_t ms_to_cycles(uint32_t ms) { return ms * (CPU_HZ / 1000u); }

/* stato del canale (CSMA half-duplex): 1 = sto sentendo il carrier dello SLAVE ->
 * il player NON emette / si interrompe. Lo aggiorna decode_step() in main.c. */
extern volatile int g_channel_busy;

void     emit_capture(void);      /* legge un char dall'UART (S6) e lo accoda (non blocca) */
void     emit_player_tick(void);  /* FSM toni PWM, non bloccante (rispetta g_channel_busy) */

/* accessori per la diagnostica */
uint32_t emit_rx_count(void);     /* char di protocollo catturati */
uint32_t emit_em_count(void);     /* toni completati */
unsigned emit_queue_len(void);    /* profondita' coda */
int      emit_busy(void);         /* 1 se un tono e' in corso */

#endif /* EMIT_TONE_H_ */
