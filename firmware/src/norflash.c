/*
 * EFES - NOR flash W25Q64 dalla CPU. Porting di flash_ctrl.vhd.
 * Legge i comandi dall'UART NOR (S7) ed esegue le sequenze SPI sul
 * spi_master_generic (S8). Vedi norflash.h per il protocollo.
 */
#include <stdint.h>
#include "norflash.h"
#include "emit_tone.h"
#include "display_manager.h"
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
static int g_chip_locked = 0;          /* 1 se BP/SRP ancora attivi dopo l'unlock */
static uint32_t g_log_epoch = 0;       /* cambia a ogni append/clear: il display rilegge */

volatile int g_nor_debug = 0;          /* settings b[19]: gating dump diagnostici */

/* colori (b[20..28], default = tema dashboard) e view flags (b[29]) per il display */
static uint8_t  g_cols[9] = { 0x4F, 0x9D, 0xFF,  0xE6, 0xED, 0xF3,  0x0E, 0x11, 0x16 };
static uint8_t  g_views = 0x7F;
static uint32_t g_set_epoch = 0;       /* incrementa a ogni apply: il display ridisegna */

int nor_present(void)        { return g_flash_present; }
int nor_locked(void)         { return g_chip_locked; }
int nor_head(void)           { return g_head; }
uint32_t nor_log_epoch(void) { return g_log_epoch; }

const uint8_t *nor_colors(void)       { return g_cols; }
uint8_t        nor_views(void)        { return g_views; }
uint32_t       nor_settings_epoch(void) { return g_set_epoch; }

/* applica i campi dei settings che comandano il firmware (solo blob v2 valido) */
static void settings_apply(const uint8_t *b) {
    if (b[0] != 0xA5u || b[30] != 0x5Au) return;
    g_nor_debug = b[19] & 1;
    for (int i = 0; i < 9; i++) g_cols[i] = b[20 + i];
    g_views = b[29] & 0x7Fu;
    g_set_epoch++;
}

/* =================== livello SPI (spi_master_generic, S8) =================== */
static uint32_t g_spi_to = 0;            /* transfer SPI andati in timeout (diag) */

static inline void nor_cs(int assert) { NORSPI_CTRL = assert ? 1u : 0u; } /* 1=CS basso */

/* done e' PERSISTENTE (si azzera solo al TXDATA successivo): una lettura OPEN WB
 * sporca del registro STATUS non lo perde piu', si limita a far ripetere il poll.
 * Timeout a TEMPO (2 ms >> 13 us di un transfer a 633 kHz), non a iterazioni:
 * se lo SPI e' morto il boot resta dell'ordine dei secondi, non delle ore. */
static uint8_t nor_xfer(uint8_t b) {
    uint32_t t0 = rdcycle32();
    NORSPI_TXDATA = b;
    while (!(NORSPI_STATUS & 0x2u)) {
        if ((uint32_t)(rdcycle32() - t0) > ms_to_cycles(2)) { g_spi_to++; break; }
    }
    return (uint8_t)(NORSPI_RXDATA & 0xFFu);
}

static void w_enable(void) { nor_cs(1); nor_xfer(CMD_WE); nor_cs(0); }

static uint8_t rdsr1(void) {
    uint8_t r; nor_cs(1); nor_xfer(CMD_RDSR1); r = nor_xfer(0); nor_cs(0); return r;
}

/* poll WIP (bit0) finche' 0, max 700 ms (sector erase reale ~400 ms, come il
 * POLL_MAX di flash_ctrl). Molla subito se il chip e' assente o lo SPI e' morto. */
static void wait_wip(void) {
    uint32_t t0 = rdcycle32();
    if (!g_flash_present) return;
    while (rdsr1() & 0x01u) {
        if ((uint32_t)(rdcycle32() - t0) > ms_to_cycles(700)) return;
        if (g_spi_to > 16) return;
    }
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
/* lettura gated su STATUS (non distruttiva): la lettura di DATA consuma il byte
 * e sul bus OPEN WB puo' tornare sporca, quindi si fa solo a rx_valid certo */
static int noruart_getc_nb(void) {
    if (!(NORUART_STATUS & 0x2u)) return -1;     /* bit1 = rx_valid, non consuma */
    return (int)(NORUART_DATA & 0xFFu);          /* bit8 race -> ignorato */
}
/* attende un byte di payload max ~200 ms; -1 su timeout (comando troncato) */
static int noruart_getc_to(void) {
    uint32_t t0 = rdcycle32();
    for (;;) {
        int c = noruart_getc_nb();
        if (c >= 0) return c;
        if ((uint32_t)(rdcycle32() - t0) > ms_to_cycles(200)) return -1;
    }
}
static void noruart_putc(uint8_t c) {
    uint32_t t0 = rdcycle32();
    while (NORUART_STATUS & 0x1u) {          /* attendi tx non busy, max 5 ms */
        if ((uint32_t)(rdcycle32() - t0) > ms_to_cycles(5)) break;
    }
    NORUART_DATA = c;
}

/* diag di boot sul canale $...\n della UART caratteri (S6): visibile come
 * "[FPGA] NOR ..." sulla console USB dell'ESP32 */
static void diag_u32(uint32_t v) {
    char b[10]; int i = 0;
    if (v == 0) { uartext_putchar('0'); return; }
    while (v) { b[i++] = (char)('0' + (v % 10u)); v /= 10u; }
    while (i) uartext_putchar(b[--i]);
}
static void diag_hh(uint8_t b) {
    static const char H[] = "0123456789ABCDEF";
    uartext_putchar(H[(b >> 4) & 0xF]); uartext_putchar(H[b & 0xF]);
}

/* =================== boot + scan =================== */
void nor_init(void) {
    /* abilita la UART comandi NOR (S7): baud 27e6/115200 lato ESP32 -> stesso clk_sdram
     * 40.5 MHz qui, div = 40_500_000/115200 = 351, 8N1 */
    NORUART_STOP  = 1;
    NORUART_DIV   = 40500000u / 115200u;
    NORUART_CFG   = UARTEXT_CFG_PARITY_NONE | UARTEXT_CFG_BITS(8);
    NORUART_START = 1;

    uartext_puts("$NOR init\n");

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

    /* boot report 'S'+SR come flash_ctrl (l'ESP32 lo cerca in consume_boot_sr_report;
     * se lo perde rilegge SR col comando 'T'). BP/SRP ancora set -> chip locked. */
    {
        uint8_t sr = rdsr1();
        g_chip_locked = ((sr & 0x9Cu) != 0);
        noruart_putc('S'); noruart_putc(sr);
    }

    /* ORA il chip ignora /HOLD#,/WP# e risponde: JEDEC per confermare la presenza. */
    uint8_t j0;
    nor_cs(1); nor_xfer(CMD_JEDEC);
    j0 = nor_xfer(0); (void)nor_xfer(0); (void)nor_xfer(0);
    g_flash_present = (j0 == 0xEFu) ? 1 : 0;
    nor_cs(0);
    if (!g_flash_present) {
        g_head = 0;
        uartext_puts("$NOR ko id="); diag_hh(j0);
        uartext_puts(" to="); diag_u32(g_spi_to); uartext_putchar('\n');
        dm_log("NOR ASSENTE");
        return;
    }

    /* scan: byte 2 (type) di ogni slot; valido se in {B,R,P,N,E}; head = ultimo+1 */
    int last = -1;
    for (int s = 0; s < N_SLOTS; s++) {
        uint8_t t;
        read_bytes(LOG_ADDR + (uint32_t)s * REC_LEN + 2u, &t, 1);
        if (t == 'B' || t == 'R' || t == 'P' || t == 'N' || t == 'E') last = s;
    }
    g_head = (last + 1) % N_SLOTS;

    /* settings persistiti -> applica subito il debug flag (b[19]) */
    {
        uint8_t s[SET_LEN];
        read_bytes(SET_ADDR, s, SET_LEN);
        settings_apply(s);
    }

    uartext_puts("$NOR ok id="); diag_hh(j0);
    uartext_puts(" hd=");  diag_u32((uint32_t)g_head);
    uartext_puts(" lk=");  diag_u32((uint32_t)g_chip_locked);
    uartext_puts(" to=");  diag_u32(g_spi_to);
    uartext_puts(" dbg="); diag_u32((uint32_t)g_nor_debug);
    uartext_putchar('\n');
    dm_log("NOR PRONTA");
}

/* legge il record 'back' posizioni dietro head (0 = piu' recente); 1 se valido.
 * Usato dal display per mostrare la memoria persistente senza passare dall'ESP32. */
int nor_log_get(int back, uint8_t rec[16]) {
    if (!g_flash_present) return 0;
    int slot = (g_head - 1 - back + 2 * N_SLOTS) % N_SLOTS;
    read_bytes(LOG_ADDR + (uint32_t)slot * REC_LEN, rec, REC_LEN);
    uint8_t t = rec[2];
    return (t == 'B' || t == 'R' || t == 'P' || t == 'N' || t == 'E');
}

/* append: probe slot; se sporco o inizio settore -> erase; page program; head++ */
static void append_record(const uint8_t *rec) {
    uint32_t a = LOG_ADDR + (uint32_t)g_head * REC_LEN;
    uint8_t b0;
    read_bytes(a, &b0, 1);
    if (b0 != 0xFF || g_head == 0 || g_head == 256) sector_erase(a);
    page_program(a, rec, REC_LEN);
    g_head = (g_head + 1) % N_SLOTS;
    g_log_epoch++;
}

/* =================== dispatch comandi =================== */
void nor_poll(void) {
    int c = noruart_getc_nb();
    if (c < 0) return;

    switch (c) {
        case 'L': {                                  /* append 16 B */
            uint8_t rec[REC_LEN];
            for (unsigned i = 0; i < REC_LEN; i++) {
                int b = noruart_getc_to();
                if (b < 0) return;                   /* payload troncato: niente ack, l'ESP32 ritenta */
                rec[i] = (uint8_t)b;
            }
            if (!g_flash_present || g_chip_locked) { noruart_putc('E'); break; }   /* fail veloce */
            append_record(rec);
            noruart_putc('K');
            dm_log("NOR APPEND");
            break;
        }
        case 'S': {                                  /* settings 32 B nel settore 0 */
            uint8_t s[SET_LEN];
            for (unsigned i = 0; i < SET_LEN; i++) {
                int b = noruart_getc_to();
                if (b < 0) return;
                s[i] = (uint8_t)b;
            }
            if (!g_flash_present || g_chip_locked) { noruart_putc('E'); break; }
            sector_erase(SET_ADDR);
            page_program(SET_ADDR, s, SET_LEN);
            settings_apply(s);                       /* debug flag live, senza reboot */
            noruart_putc('K');
            dm_log("NOR SETTINGS");
            break;
        }
        case 'Q': {                                  /* read settings */
            uint8_t s[SET_LEN];
            read_bytes(SET_ADDR, s, SET_LEN);
            for (unsigned i = 0; i < SET_LEN; i++) noruart_putc(s[i]);
            break;
        }
        case 'G': {                                  /* read: slot(2) + n(1) -> n*16 B */
            int shi = noruart_getc_to(), slo = noruart_getc_to(), n = noruart_getc_to();
            if (shi < 0 || slo < 0 || n < 0) return;
            if (n > 4) n = 4;                        /* come flash_ctrl: gn max 4 */
            int slot = ((shi << 8) | slo) % N_SLOTS;
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
            g_log_epoch++;
            noruart_putc('K');
            dm_log("NOR CLEAR");
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
