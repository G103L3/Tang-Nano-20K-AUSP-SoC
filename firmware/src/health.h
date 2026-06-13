/*
 * EFES - health check del SoC dalla CPU: verifica che gli slave Wishbone
 * rispondano (S0..S8) e che la catena audio avanzi, e pubblica ~ogni 2 s una
 * riga "$HLT ..." sull'UART caratteri (S6) che l'ESP32 inoltra alla dashboard.
 */
#ifndef HEALTH_H
#define HEALTH_H

/* Da chiamare nel loop principale: non bloccante. Prima scansione ~3 s dopo il
 * boot (con probe $HP), poi un report $HLT ogni 15 s. */
void health_tick(void);

/* ultimo stato riportato (per il display): mask S0..S8, fft viva, adc vivo */
unsigned health_last_mask(void);
int      health_last_fft(void);
int      health_last_adc(void);

#endif
