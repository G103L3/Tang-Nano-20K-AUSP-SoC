/*
 * EFES - gestione NOR flash W25Q64 dalla CPU (porting di flash_ctrl.vhd).
 *
 * Catena: ESP32 -> UART comandi NOR (S7, NORUART) -> la CPU legge il comando ->
 * esegue la sequenza SPI W25Q sullo spi_master_generic (S8, NORSPI) -> chip NOR.
 *
 * Comandi (1 char dall'ESP32, come flash_ctrl):
 *   'L' + 16 B  : append record nel log (ring 512 slot)        -> risponde 'K'
 *   'S' + 32 B  : salva settings (settore 0x0000)              -> 'K'
 *   'C'         : clear log (erase settori 0x1000 e 0x2000)    -> 'K'
 *   'G' s_hi s_lo n : leggi n record (16 B) dallo slot s       -> n*16 B
 *   'H'         : leggi head                                   -> 2 B (hi,lo)
 *   'Q'         : leggi settings                               -> 32 B
 *   'I'         : JEDEC id                                     -> 3 B
 *   'T'         : status register 1                            -> 1 B
 */
#ifndef NORFLASH_H
#define NORFLASH_H

/* Settings (32 B, settore 0): b[0]=0xA5 magic, b[1..15]=name, b[16..17]=auto_s,
 * b[18]=tries, b[19]=debug_log, b[20..28]=colori main/text/bg RGB,
 * b[29]=view flags (bit0 wave..bit6 txpkt), b[30]=0x5A marker v2. */

/* Boot: sblocca il chip (WRSR clear BP/SRP + QE, Global Block Unlock) e fa lo scan
 * per trovare head. Da chiamare una volta dopo l'init delle UART. */
void nor_init(void);

/* Da chiamare nel loop principale: se c'e' un comando sull'UART NOR lo esegue. */
void nor_poll(void);

/* debug log on/off: viene dai settings in NOR (b[19]), aggiornato live quando la
 * dashboard salva. main.c lo usa per gating dei dump diagnostici $...\n. */
extern volatile int g_nor_debug;

/* accessori per health.c */
int nor_present(void);
int nor_locked(void);
int nor_head(void);

/* record del log persistente (16 B: seq[2] type[1] t_sec[4] val[1] text[8]):
 * back=0 e' il piu' recente; ritorna 1 se il tipo e' valido {B,R,P,N,E}.
 * nor_log_epoch cambia a ogni append/clear: il display rilegge solo allora. */
int nor_log_get(int back, uint8_t rec[16]);
uint32_t nor_log_epoch(void);

/* accessori per display_manager.c: colori RGB (main/text/bg, 3 byte l'uno),
 * view flags (bit0 wave..bit6 txpkt) ed epoch (cambia a ogni save -> ridisegno) */
#include <stdint.h>
const uint8_t *nor_colors(void);
uint8_t        nor_views(void);
uint32_t       nor_settings_epoch(void);

#endif
