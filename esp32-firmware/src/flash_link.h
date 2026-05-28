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

typedef struct {
    char     name[16];
    uint16_t auto_presence_s;
    uint8_t  presence_tries;
} flash_settings_t;

void flash_link_init(void);
bool flash_read_id(uint8_t id[3]);
bool flash_read_sr(uint8_t *sr);
int  flash_log_head(void);
bool flash_log_append(uint8_t type, uint32_t t_sec, uint8_t val, const char *text);
int  flash_log_read(int slot, int n, uint8_t *out);
bool flash_log_clear(void);
bool flash_get_settings(flash_settings_t *s);
bool flash_set_settings(const flash_settings_t *s);

#ifdef __cplusplus
}
#endif
#endif
