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

/* Boot: sblocca il chip (WRSR clear BP/SRP + QE, Global Block Unlock) e fa lo scan
 * per trovare head. Da chiamare una volta dopo l'init delle UART. */
void nor_init(void);

/* Da chiamare nel loop principale: se c'e' un comando sull'UART NOR lo esegue. */
void nor_poll(void);

#endif
