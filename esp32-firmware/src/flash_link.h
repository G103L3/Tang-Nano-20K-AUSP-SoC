#ifndef FLASH_LINK_H
#define FLASH_LINK_H
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#define FLASH_REC_BYTES 16
#define FLASH_SET_BYTES 32
#define FLASH_N_SLOTS   512

#define LOG_BOOT 'B'
#define LOG_REG  'R'
#define LOG_PRES 'P'
#define LOG_NOTE 'N'
#define LOG_EVT  'E'

#ifdef __cplusplus
extern "C" {
#endif

/* view_flags: bit0=onda audio, bit1=logs, bit2=stato slaves, bit3=irq dma,
 * bit4=peaks bin, bit5=pacchetto ricevuto, bit6=pacchetto in emissione */
typedef struct {
    char     name[16];
    uint16_t auto_presence_s;
    uint8_t  presence_tries;
    uint8_t  debug_log;          /* dump diagnostici FPGA on/off (b[19]) */
    uint8_t  col_main[3];        /* colore principale RGB (b[20..22]) */
    uint8_t  col_text[3];        /* colore testo RGB (b[23..25]) */
    uint8_t  col_bg[3];          /* colore sfondo RGB (b[26..28]) */
    uint8_t  view_flags;         /* b[29], default tutti on (0x7F) */
} flash_settings_t;

typedef struct {
    uint16_t seq;
    uint8_t  type;
    uint32_t t_sec;
    uint8_t  val;
    char     text[9];
} flash_cache_rec_t;

void flash_link_init(void);
bool flash_read_id(uint8_t id[3]);
bool flash_read_sr(uint8_t *sr);
int  flash_log_head(void);
bool flash_log_append(uint8_t type, uint32_t t_sec, uint8_t val, const char *text);
int  flash_log_read(int slot, int n, uint8_t *out);
bool flash_log_clear(void);
bool flash_get_settings(flash_settings_t *s);
bool flash_set_settings(const flash_settings_t *s);

int  flash_cache_get(flash_cache_rec_t *out, int max);
void flash_log_dump_diagnostic(void);
bool flash_is_chip_locked(void);

#ifdef __cplusplus
}
#endif
#endif
