/*! \file fpga_uart_link.h
 * \brief Link layer verso la FPGA. CODEBOOK A BIT ALTERNATI: ogni messaggio e'
 *        un pattern di bit STRETTAMENTE alternati (mai due simboli uguali di
 *        fila), identificato da (primo_bit, lunghezza). L'alternanza garantisce
 *        che ogni simbolo sia un CAMBIO di frequenza: il riverbero del tono
 *        precedente non puo' piu' fondere due simboli uguali.
 *
 * Char dalla FPGA (decoder): MAIUSCOLE A/B/C = carrier SLAVE (bit0/bit1/EOF),
 *   minuscole a/b/c = carrier MASTER (= TX del master in loopback, ignorato).
 * Il master TRASMETTE sempre sul carrier master -> invia minuscole a/b/c.
 *
 * RX: rileva i simboli per CAMBIO di char (un char ripetuto = riverbero ->
 *     ignorato). Tra due EOF (C) raccoglie il pattern -> (primo_bit, lunghezza,
 *     alternato?) -> protocol_on_pattern(CH_SLAVE, ...).
 * TX: fpga_uart_send_pattern(primo_bit, lunghezza) -> EOF + bit alternati + EOF.
 */
#ifndef FPGA_UART_LINK_H
#define FPGA_UART_LINK_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

void fpga_uart_init(void);
void fpga_uart_tick(void);                              /* RX */
void fpga_uart_send_pattern(int first_bit, int length); /* TX */

/* Callback per le righe diagnostiche "$...\n" della FPGA: riceve la riga
 * completa SENZA '$' ne' '\n' (es. "HLT m=1FF adc=1 ..."). Usata da web_link
 * per inoltrare la salute del SoC alla dashboard. */
typedef void (*fpga_diag_cb_t)(const char *line);
void fpga_uart_set_diag_cb(fpga_diag_cb_t cb);

#ifdef __cplusplus
}
#endif

#endif /* FPGA_UART_LINK_H */
