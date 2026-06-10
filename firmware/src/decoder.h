/*! \file decoder.h
 * \brief Decoder protocollo (lato MASTER, soft core PicoRV32). Portato dal decoder
 *        dello slave (Project01Giunta/src/decoder.c): noise floor adattivo (x4),
 *        massimo locale +-3, interpolazione parabolica. Adattamenti:
 *          - lavora sull'array di bin FFT letti dalla SDRAM (solo parte reale xk_re;
 *            magnitudine = |re|), non sui 512 complessi dello slave;
 *          - i bin si ricavano dalle FREQUENZE col NOSTRO fs (46875) e N=512;
 *          - il master ascolta il carrier SLAVE (2400) oltre al proprio (2000=loopback).
 */
#ifndef DECODER_H_
#define DECODER_H_
#include <stdint.h>

/* channel: 0=master(loopback) 1=slave ; sym: 0=bit0 1=bit1 2=EOF ; -1 = niente */
typedef struct { int channel; int sym; } rx_symbol_t;

/* re = bin FFT (parte reale xk_re), indice = numero di bin (0..n-1); n = bin disponibili.
 * Ritorna il simbolo rilevato (channel/sym = -1 se niente). */
rx_symbol_t decode_symbol(const int16_t *re, int n);

/* come sopra ma ritorna il char di protocollo: master->'a'/'b'/'c', slave->'A'/'B'/'C',
 * 0 = niente. */
char decode_char(const int16_t *re, int n);

/* 1 se il carrier dello SLAVE (bin27) e' presente nel frame (indipendente dal dato e
 * dal proprio carrier). La logica del canale (main) lo usa per non parlare/interrompersi
 * quando lo slave sta trasmettendo. */
int decode_slave_carrier(const int16_t *re, int n);

#endif /* DECODER_H_ */
