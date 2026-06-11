/*
 * EFES - health check del SoC dalla CPU: verifica che gli slave Wishbone
 * rispondano (S0..S8) e che la catena audio avanzi, e pubblica ~ogni 2 s una
 * riga "$HLT ..." sull'UART caratteri (S6) che l'ESP32 inoltra alla dashboard.
 */
#ifndef HEALTH_H
#define HEALTH_H

/* Da chiamare nel loop principale: non bloccante, fa qualcosa solo ~ogni 2 s. */
void health_tick(void);

#endif
