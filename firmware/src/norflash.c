/*
 * EFES - NOR flash W25Q64 dalla CPU. Porting di flash_ctrl.vhd.
 * Legge i comandi dall'UART NOR (S7) ed esegue le sequenze SPI sul
 * spi_master_generic (S8). Vedi norflash.h per il protocollo.
 */
#include <stdint.h>
#include "norflash.h"
#include "../include/periphs.h"

/* ---- mappa memoria (come flash_ctrl) ---- */
#define SET_ADDR   0x000000u           /* settore 0: settings (32 B)        */
#define LOG_ADDR   0x001000u           /* settori 1-2: log, slot 0..511      */
#define REC_LEN    16u                 /* record = 16 B                      */
#define SET_LEN    32u                 /* settings = 32 B                    */
#define N_SLOTS    512
#define SECT_MASK  (~0xFFFu)           /* base settore 4 KB                  */

/* ---- comandi W25Q ---- */
#define CMD_WE     0x06u
#define CMD_WRSR   0x01u
#define CMD_RDSR1  0x05u
#define CMD_READ   0x03u
#define CMD_PP     0x02u
#define CMD_SE     0x20u
#define CMD_GBU    0x98u
#define CMD_JEDEC  0x9Fu

static int g_head;                     /* prossimo slot da scrivere (0..511) */
static int g_flash_present = 0;        /* 1 se il W25Q risponde al JEDEC (id[0]=0xEF) */

/* =================== livello SPI (spi_master_generic, S8) =================== */
static inline void nor_cs(int assert) { NORSPI_CTRL = assert ? 1u : 0u; } /* 1=CS basso */
static uint8_t nor_xfer(uint8_t b) {
    uint32_t guard = 100000u;                /* >> 512 cicli di un transfer: evita hang infinito */
    NORSPI_TXDATA = b;                       /* avvia il trasferimento di 1 byte   */
    while (!(NORSPI_STATUS & 0x2u) && guard) guard--;  /* attendi done (bit1) con timeout */
    return (uint8_t)(NORSPI_RXDATA & 0xFFu);
}

static void w_enable(void) { nor_cs(1); nor_xfer(CMD_WE); nor_cs(0); }

static uint8_t rdsr1(void) {
    uint8_t r; nor_cs(1); nor_xfer(CMD_RDSR1); r = nor_xfer(0); nor_cs(0); return r;
}

/* poll WIP (bit0) finche' 0. guard ~60k iter (ogni iter ~1 ms con 2 transfer SPI) ->
 * ~1.5 s: copre un sector-erase reale (~400 ms) ma molla in fretta se il chip non
 * risponde (WIP bloccato a 1), invece di ~10 min che congelavano emit e nor_poll. */
static void wait_wip(void) {
    uint32_t guard = 60000u;
    if (!g_flash_present) return;        /* chip assente: non spinnare */
    while ((rdsr1() & 0x01u) && guard) guard--;
}

static void send_addr(uint32_t a) { nor_xfer(a >> 16); nor_xfer(a >> 8); nor_xfer(a); }

static void sector_erase(uint32_t a) {
    w_enable();
    nor_cs(1); nor_xfer(CMD_SE); send_addr(a & SECT_MASK); nor_cs(0);
    wait_wip();
}

static void page_program(uint32_t a, const uint8_t *d, int n) {
    w_enable();
    nor_cs(1); nor_xfer(CMD_PP); send_addr(a);
    for (int i = 0; i < n; i++) nor_xfer(d[i]);
    nor_cs(0);
    wait_wip();
}

static void read_bytes(uint32_t a, uint8_t *d, int n) {
    nor_cs(1); nor_xfer(CMD_READ); send_addr(a);
    for (int i = 0; i < n; i++) d[i] = nor_xfer(0);
    nor_cs(0);
}

/* =================== UART comandi NOR (S7) =================== */
static int noruart_getc_nb(void) {
    uint32_t d = NORUART_DATA;               /* [8]=rx_valid, [7:0]=byte (lettura azzera) */
    return (d & (1u << 8)) ? (int)(d & 0xFFu) : -1;
}
static int noruart_getc(void) { int c; do { c = noruart_getc_nb(); } while (c < 0); return c; }
static void noruart_putc(uint8_t c) {
    while (NORUART_STATUS & 0x1u) { }        /* attendi tx non busy */
    NORUART_DATA = c;
}

/* =================== boot + scan =================== */
void nor_init(void) {
    /* abilita la UART comandi NOR (S7): baud 27e6/115200 lato ESP32 -> stesso clk_sdram
     * 40.5 MHz qui, div = 40_500_000/115200 = 351, 8N1 */
    NORUART_STOP  = 1;
    NORUART_DIV   = 40500000u / 115200u;
    NORUART_CFG   = UARTEXT_CFG_PARITY_NONE | UARTEXT_CFG_BITS(8);
    NORUART_START = 1;

    /* unlock PRIMA DI TUTTO (come flash_ctrl.vhd "Works"): WRSR con SR2=0x02 (QE=1).
     * Su questa board /HOLD# e /WP# del W25Q sono SCOLLEGATI/flottanti: senza QE=1
     * ogni fronte SCK accoppia /HOLD# -> il chip va in pausa, MISO flotta e ogni
     * lettura (anche il JEDEC!) torna 0xFF. Quindi NON si puo' leggere il JEDEC prima:
     * va settata QE per prima, a 633 kHz (SCK lento) cosi' il comando passa. */
    g_flash_present = 1;                  /* abilita wait_wip durante l'unlock */
    w_enable();
    nor_cs(1); nor_xfer(CMD_WRSR); nor_xfer(0x00); nor_xfer(0x02); nor_cs(0);
    wait_wip();
    w_enable();
    nor_cs(1); nor_xfer(CMD_GBU); nor_cs(0);
    wait_wip();

    /* ORA il chip ignora /HOLD#,/WP# e risponde: JEDEC per confermare la presenza. */
    nor_cs(1); nor_xfer(CMD_JEDEC);
    { uint8_t j0 = nor_xfer(0); (void)nor_xfer(0); (void)nor_xfer(0);
      g_flash_present = (j0 == 0xEFu) ? 1 : 0; }
    nor_cs(0);
    if (!g_flash_present) { g_head = 0; return; }

    /* scan: byte 2 (type) di ogni slot; valido se in {B,R,P,N,E}; head = ultimo+1 */
    int last = -1;
    for (int s = 0; s < N_SLOTS; s++) {
        uint8_t t;
        read_bytes(LOG_ADDR + (uint32_t)s * REC_LEN + 2u, &t, 1);
        if (t == 'B' || t == 'R' || t == 'P' || t == 'N' || t == 'E') last = s;
    }
    g_head = (last + 1) % N_SLOTS;
}

/* append: probe slot; se sporco o inizio settore -> erase; page program; head++ */
static void append_record(const uint8_t *rec) {
    uint32_t a = LOG_ADDR + (uint32_t)g_head * REC_LEN;
    uint8_t b0;
    read_bytes(a, &b0, 1);
    if (b0 != 0xFF || g_head == 0 || g_head == 256) sector_erase(a);
    page_program(a, rec, REC_LEN);
    g_head = (g_head + 1) % N_SLOTS;
}

/* =================== dispatch comandi =================== */
void nor_poll(void) {
    int c = noruart_getc_nb();
    if (c < 0) return;

    switch (c) {
        case 'L': {                                  /* append 16 B */
            uint8_t rec[REC_LEN];
            for (unsigned i = 0; i < REC_LEN; i++) rec[i] = (uint8_t)noruart_getc();
            if (!g_flash_present) { noruart_putc('E'); break; }   /* fail veloce, no blocco */
            append_record(rec);
            noruart_putc('K');
            break;
        }
        case 'S': {                                  /* settings 32 B nel settore 0 */
            uint8_t s[SET_LEN];
            for (unsigned i = 0; i < SET_LEN; i++) s[i] = (uint8_t)noruart_getc();
            if (!g_flash_present) { noruart_putc('E'); break; }
            sector_erase(SET_ADDR);
            page_program(SET_ADDR, s, SET_LEN);
            noruart_putc('K');
            break;
        }
        case 'Q': {                                  /* read settings */
            uint8_t s[SET_LEN];
            read_bytes(SET_ADDR, s, SET_LEN);
            for (unsigned i = 0; i < SET_LEN; i++) noruart_putc(s[i]);
            break;
        }
        case 'G': {                                  /* read: slot(2) + n(1) -> n*16 B */
            int shi = noruart_getc(), slo = noruart_getc(), n = noruart_getc();
            int slot = (shi << 8) | slo;
            for (int k = 0; k < n; k++) {
                uint8_t rec[REC_LEN];
                read_bytes(LOG_ADDR + (uint32_t)((slot + k) % N_SLOTS) * REC_LEN, rec, REC_LEN);
                for (unsigned i = 0; i < REC_LEN; i++) noruart_putc(rec[i]);
            }
            break;
        }
        case 'H':                                    /* read head (2 B) */
            noruart_putc((uint8_t)(g_head >> 8));
            noruart_putc((uint8_t)(g_head & 0xFF));
            break;
        case 'C':                                    /* clear log */
            if (!g_flash_present) { g_head = 0; noruart_putc('E'); break; }
            sector_erase(LOG_ADDR);
            sector_erase(LOG_ADDR + 0x1000u);
            g_head = 0;
            noruart_putc('K');
            break;
        case 'I': {                                  /* JEDEC id (3 B) */
            nor_cs(1); nor_xfer(CMD_JEDEC);
            for (int i = 0; i < 3; i++) noruart_putc(nor_xfer(0));
            nor_cs(0);
            break;
        }
        case 'T':                                    /* status register 1 */
            noruart_putc(rdsr1());
            break;
        default:
            break;
    }
}
