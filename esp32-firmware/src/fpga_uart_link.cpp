/*! \file fpga_uart_link.cpp
 * \brief Link layer a CODEBOOK ALTERNATO verso la FPGA (master). Vedi fpga_uart_link.h.
 */
#include <Arduino.h>
#include "fpga_uart_link.h"
#include "protocol.h"

#ifndef FPGA_UART_BAUD
#define FPGA_UART_BAUD   115200
#endif
#ifndef FPGA_UART_RX_PIN
#define FPGA_UART_RX_PIN 27
#endif
#ifndef FPGA_UART_TX_PIN
#define FPGA_UART_TX_PIN 14
#endif

/* Echo diagnostico dei simboli decodificati dalla FPGA. */
#ifndef FPGA_RX_ECHO
#define FPGA_RX_ECHO 1
#endif

/* La FPGA emette ogni simbolo ~72 ms tono + ~350 ms silenzio = ~422 ms.
 * Mando un char ogni ~430 ms cosi' il ritmo dell'ESP32 segue quello della FPGA
 * e la FIFO TX (32) non si riempie. (Adegua se cambi SIL_CYCLES in top.vhd.) */
static const unsigned long EMIT_PACE_MS = 430;

/* Carrier-sense: non trasmettere mentre lo slave parla (carrier slave attivo). */
static const unsigned long CHANNEL_GUARD_MS = 1000;
static const unsigned long CSMA_MAX_WAIT_MS = 15000;

/* Reset di un frame parziale se non arrivano simboli per un po'. */
static const unsigned long FRAME_TIMEOUT_MS = 2000;

static const int EOF_BURST = 4;        /* EOF di testa/coda (ridondanza) */

static unsigned long last_rx_ms = 0;   /* ultimo char dal carrier SLAVE (carrier-sense) */

/* ---- RX: rilevazione per CAMBIO di simbolo (codebook alternato) ----
 * Un simbolo nuovo = il char e' DIVERSO dall'ultimo accettato. Un char ripetuto
 * (ripetizioni della FPGA o riverbero che tiene su lo stesso tono) si ignora.
 * Cosi' la raffica di EOF si collassa in un solo evento EOF, e ogni bit dati
 * (che nel codebook alterna sempre) e' un evento distinto. */
static char last_sym  = 0;             /* ultimo char accettato (0 = nessuno)   */
static int  rx_first  = -1;            /* primo bit del pattern in corso        */
static int  rx_len    = 0;             /* lunghezza (n. simboli dati)           */
static int  rx_last   = -1;            /* ultimo bit dati (per check alternanza)*/
static bool rx_alt    = true;          /* il pattern e' strettamente alternato? */
static unsigned long rx_last_sym_ms = 0;

void fpga_uart_init(void) {
    Serial2.begin(FPGA_UART_BAUD, SERIAL_8N1, FPGA_UART_RX_PIN, FPGA_UART_TX_PIN);
}

static void rx_reset(void) { rx_first = -1; rx_len = 0; rx_last = -1; rx_alt = true; }

/* EOF -> chiude il pattern accumulato e lo passa al protocollo */
static void rx_finish_pattern(void) {
    if (rx_len > 0) {
#if FPGA_RX_ECHO
        Serial.printf("\n[PATTERN slave] first=%d len=%d %s\n",
                      rx_first, rx_len, rx_alt ? "alt" : "NON-alt");
#endif
        protocol_on_pattern(CH_SLAVE, rx_first, rx_len, rx_alt);
    }
    rx_reset();
}

void fpga_uart_tick(void) {
    while (Serial2.available()) {
        char c = (char)Serial2.read();

        /* MAIUSCOLE A/B/C = carrier SLAVE (quello che il master riceve). */
        if (c == 'A' || c == 'B' || c == 'C') {
            unsigned long nowc = millis();
            last_rx_ms = nowc;                 /* slave attivo (carrier-sense) */

            if (c == last_sym) continue;       /* stesso simbolo (ripetiz./riverbero) */
            last_sym = c;
            rx_last_sym_ms = nowc;
#if FPGA_RX_ECHO
            Serial.write((uint8_t)c);
#endif
            if (c == 'C') {                    /* EOF -> fine pattern */
                rx_finish_pattern();
            } else {                           /* bit dati: A=0, B=1 */
                int bit = (c == 'B') ? 1 : 0;
                if (rx_len == 0)            rx_first = bit;
                else if (bit == rx_last)    rx_alt   = false;  /* due uguali di fila */
                rx_last = bit;
                if (rx_len < 16) rx_len++;
            }
        }
        /* minuscole a/b/c = carrier master = loopback del proprio TX -> ignora.
         * Altri byte (boot banner, ecc.) -> inoltro su USB solo se stampabili
         * e solo con FPGA_RX_ECHO=1, per evitare di intasare il monitor con
         * binario quando il decoder triggera sul rumore. */
        else if (c != 'a' && c != 'b' && c != 'c') {
#if FPGA_RX_ECHO
            if (c >= 0x20 && c < 0x7F) Serial.write((uint8_t)c);
#endif
        }
    }

    /* timeout: scarta un pattern parziale rimasto a meta' (silenzio prolungato).
     * Azzero anche last_sym cosi' il prossimo tono e' sempre un simbolo nuovo. */
    if (rx_len > 0 && (millis() - rx_last_sym_ms) > FRAME_TIMEOUT_MS) {
        rx_reset();
        last_sym = 0;
    }
}

/* Attende che il canale sia silenzioso da CHANNEL_GUARD_MS (con max
 * CSMA_MAX_WAIT_MS). Durante l'attesa chiama fpga_uart_tick() così last_rx_ms
 * resta aggiornato. */
static void cs_wait_quiet(void) {
    unsigned long start = millis();
    while ((millis() - last_rx_ms) < CHANNEL_GUARD_MS) {
        fpga_uart_tick();
        if (millis() - start > CSMA_MAX_WAIT_MS) break;
        delay(2);
    }
}

/* Delay attivo: continua a chiamare fpga_uart_tick() durante l'attesa per
 * aggiornare last_rx_ms (cosi' rileviamo lo slave se inizia a parlare). */
static void cs_pace(unsigned long ms) {
    unsigned long t0 = millis();
    while ((millis() - t0) < ms) {
        fpga_uart_tick();
        delay(2);
    }
}

/* TX: emette un pattern alternato. Il master trasmette sempre sul carrier master
 * => char minuscoli (a=bit0, b=bit1, c=EOF). Il bit i-esimo del pattern e'
 * first_bit XOR (i & 1): garantisce alternanza stretta.
 *
 * Carrier-sense: PRIMA DI OGNI byte controlla che lo slave non stia parlando.
 * Se inizia mid-trasmissione si interrompe e aspetta che finisca, poi riprende. */
void fpga_uart_send_pattern(int first_bit, int length) {
    cs_wait_quiet();

    for (int k = 0; k < EOF_BURST; k++) {
        cs_wait_quiet();
        Serial2.write((uint8_t)'c');
        cs_pace(EMIT_PACE_MS);
    }

    for (int i = 0; i < length; i++) {
        cs_wait_quiet();
        int bit = first_bit ^ (i & 1);
        Serial2.write((uint8_t)(bit ? 'b' : 'a'));
        cs_pace(EMIT_PACE_MS);
    }

    for (int k = 0; k < EOF_BURST; k++) {
        cs_wait_quiet();
        Serial2.write((uint8_t)'c');
        cs_pace(EMIT_PACE_MS);
    }
}
