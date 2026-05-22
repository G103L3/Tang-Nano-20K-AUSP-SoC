/*! \file fpga_uart_link.cpp
 * \brief Implementazione driver UART verso FPGA.
 */
#include <Arduino.h>
#include "fpga_uart_link.h"
#include "bit_input_packer.h"

#ifndef FPGA_UART_BAUD
#define FPGA_UART_BAUD   115200
#endif
#ifndef FPGA_UART_RX_PIN
#define FPGA_UART_RX_PIN 27
#endif
#ifndef FPGA_UART_TX_PIN
#define FPGA_UART_TX_PIN 14
#endif

/* Timeout di silenzio: se dopo questo tempo non sono arrivati nuovi char,
 * inviamo a process_tone_bits un evento di "silenzio totale" per resettare
 * i noise_flag e armare il prossimo tono. Valore scelto: > durata di un
 * burst di 3 char ripetuti dall'output packer (~72 ms a 24 ms/char) NON
 * va bene, ma il decoder FPGA fa scattare il char solo 1-2 volte per tono
 * (FFT window 10.7 ms su 24 ms di tono). Mettiamo 35 ms come buon
 * compromesso: piu' lungo della finestra FFT, piu' corto del gap silenzio
 * inter-pacchetto (80 ms).
 */
static const unsigned long SILENCE_TIMEOUT_MS = 35;

static unsigned long last_rx_ms = 0;
static bool          silence_fired = true;

void fpga_uart_init(void) {
    Serial2.begin(FPGA_UART_BAUD, SERIAL_8N1, FPGA_UART_RX_PIN, FPGA_UART_TX_PIN);
}

bool fpga_uart_char_to_code(char c, int *code, bool *is_config) {
    if (!code || !is_config) return false;

    /* master: 'a'..'h' = 0..7, 'i' = 8 (EOP), 'j'..'q' = 10..17 */
    if (c >= 'a' && c <= 'q') {
        int off = c - 'a';
        if (off <= 8)      *code = off;        /* a..i  -> 0..8  */
        else               *code = off + 1;    /* j..q  -> 10..17 */
        *is_config = false;
        return true;
    }
    /* config: idem ma uppercase */
    if (c >= 'A' && c <= 'Q') {
        int off = c - 'A';
        if (off <= 8)      *code = off;
        else               *code = off + 1;
        *is_config = true;
        return true;
    }
    return false;
}

char fpga_uart_code_to_char(int code, int role) {
    /* role: 0 = master, 2 = config (1 = slave non supportato) */
    if (code < 0 || code > 17 || code == 9) return '\0';
    char base;
    if      (role == 0) base = CHAR_MASTER_BASE;
    else if (role == 2) base = CHAR_CONFIG_BASE;
    else                return '\0';

    /* code 0..8 -> base..base+8 ; code 10..17 -> base+9..base+16 */
    if (code <= 8) return (char)(base + code);
    else           return (char)(base + code - 1);
}

void fpga_uart_send_char(char c) {
    Serial2.write((uint8_t)c);
}

/* Tempo di un tono (FPGA TONE_CYCLES ~30 ms) + silenzio (SIL_CYCLES ~60 ms)
 * = ~90 ms; aggiungo margine. Cosi' la FPGA finisce di emettere un tono prima
 * che arrivi il char successivo (altrimenti la FSM TX, occupata, lo scarta). */
static const unsigned long EMIT_PACE_MS = 100;

void fpga_uart_emit_codes(const uint8_t *codes, size_t count, int role) {
    for (size_t i = 0; i < count; i++) {
        char c = fpga_uart_code_to_char((int)codes[i], role);
        if (c != '\0') {
            fpga_uart_send_char(c);
            delay(EMIT_PACE_MS);
        }
    }
}

void fpga_uart_tick(void) {
    /* Drain RX buffer */
    while (Serial2.available()) {
        char c = (char)Serial2.read();
        int  code;
        bool is_config;

        if (fpga_uart_char_to_code(c, &code, &is_config)) {
            last_rx_ms     = millis();
            silence_fired  = false;

            struct_tone_bits tb;
            tb.master        = -1;
            tb.slave         = -1;
            tb.configuration = -1;
            if (is_config) tb.configuration = code;
            else           tb.master        = code;
            (void)process_tone_bits(tb);
        } else {
            /* Char fuori protocollo: probabilmente boot banner della FPGA
             * o garbage. Lo inoltro su USB per debug, non rovino lo stato
             * del packer. */
            Serial.write((uint8_t)c);
        }
    }

    /* Timeout silenzio: faccio scattare process_tone_bits con tutto a -1
     * per resettare i noise_flag (permette al prossimo char di non essere
     * considerato duplicato del precedente). */
    if (!silence_fired && (millis() - last_rx_ms) > SILENCE_TIMEOUT_MS) {
        struct_tone_bits silent;
        silent.master        = -1;
        silent.slave         = -1;
        silent.configuration = -1;
        (void)process_tone_bits(silent);
        silence_fired = true;
    }
}
