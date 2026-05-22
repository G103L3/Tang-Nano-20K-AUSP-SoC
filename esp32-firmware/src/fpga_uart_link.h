/*! \file fpga_uart_link.h
 * \brief Driver UART verso FPGA. Riceve i char emessi dal decoder audio
 * (audio_decoder.vhd) e li converte in struct_tone_bits per il bit packer.
 * Inviera' anche char alla FPGA per il path TX (verra' usato dall'output
 * packer / emit_tones nel prossimo step).
 *
 * Cablaggio:
 *   FPGA uart_ext_tx -> ESP32 pin FPGA_UART_RX_PIN (Serial2 RX)
 *   FPGA uart_ext_rx <- ESP32 pin FPGA_UART_TX_PIN (Serial2 TX)
 */
#ifndef FPGA_UART_LINK_H
#define FPGA_UART_LINK_H

#include "global_parameters.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Inizializza Serial2 con i pin/baud definiti in platformio.ini. */
void fpga_uart_init(void);

/* Processa eventuali byte ricevuti dalla FPGA. Da chiamare nel loop().
 * Per ogni byte riconosciuto come char di protocollo (a..q / A..Q):
 *   - decodifica in (signal code, canale)
 *   - costruisce struct_tone_bits e chiama process_tone_bits()
 * I byte non riconosciuti (ASCII di boot banner, spazi, ecc.) vengono
 * inoltrati su Serial (USB) per debug.
 */
void fpga_uart_tick(void);

/* Invia un char alla FPGA (interpretato dall'UART RX FPGA come "emit tone
 * pair"). Non bloccante se la TX queue non e' piena.
 */
void fpga_uart_send_char(char c);

/* Invia una sequenza di signal code alla FPGA come char, uno alla volta, con
 * pausa fissa tra l'uno e l'altro (la FPGA emette ogni tono per ~30 ms + ~60 ms
 * di silenzio). role: 0=master, 2=config (1=slave non supportato nella mappa
 * giocattolo). I code non mappabili (incluso slave) vengono saltati.
 */
void fpga_uart_emit_codes(const uint8_t *codes, size_t count, int role);

/* Conversione char ricevuto -> (signal code, canale).
 *   Ritorna true se valido, popola *code (0..17, escluso 9) e *is_config.
 *   Ritorna false se il char non e' nel set del protocollo.
 */
bool fpga_uart_char_to_code(char c, int *code, bool *is_config);

/* Conversione inversa: (signal code, canale) -> char da inviare alla FPGA.
 *   role: 0=master, 1=slave (non usato), 2=config.
 *   Ritorna 0 (NUL) se il code e' fuori range o role non supportato.
 */
char fpga_uart_code_to_char(int code, int role);

#ifdef __cplusplus
}
#endif

#endif /* FPGA_UART_LINK_H */
