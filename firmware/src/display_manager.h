/*
 * EFES - display TFT GMT020-02-7P (ST7789, 240x320) su spi_display (S9).
 * Mini-dashboard a 4 zone (sinistra, alto-centro, basso-centro, destra);
 * cosa mostra ogni zona viene dai view flags dei settings in NOR (b[29]),
 * i colori dal tema salvato (b[20..28]). Tutto NON bloccante: display_tick()
 * disegna a piccoli blocchi per non affamare emit/decode/nor_poll.
 *
 * Zone fisse (un solo contenuto attivo per zona, in ordine di priorita'):
 *   SINISTRA     : stato slaves (bit2)  | pacchetto in emissione (bit6)
 *   ALTO-CENTRO  : onda audio (bit0)    | peaks bin (bit4)
 *   BASSO-CENTRO : logs (bit1)
 *   DESTRA       : pacchetto ricevuto (bit5) | IRQ del DMA (bit3)
 * "Onda audio" = spettro dei bin analizzati (16..55) a rettangolini, altezza =
 * magnitude (bin di protocollo in colore principale); "peaks bin" = coppia di
 * picchi piu' alta con frequenza in Hz e simbolo decodificato.
 */
#ifndef DISPLAY_MANAGER_H
#define DISPLAY_MANAGER_H

/* Da chiamare nel loop principale: gestisce reset/init del pannello e il
 * ridisegno incrementale (budget ~128 byte SPI per chiamata). */
void display_tick(void);

/* eventi per le zone RX/LOGS: ultimo char decodificato e righe di log brevi */
void dm_note_rx(char c);
void dm_log(const char *s);

#endif
