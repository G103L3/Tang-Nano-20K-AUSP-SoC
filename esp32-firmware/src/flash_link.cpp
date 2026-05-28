#include <Arduino.h>
#include <string.h>
#include "flash_link.h"

#ifndef FLASH_UART_RX_PIN
#define FLASH_UART_RX_PIN 32
#endif
#ifndef FLASH_UART_TX_PIN
#define FLASH_UART_TX_PIN 33
#endif
#ifndef FLASH_UART_BAUD
#define FLASH_UART_BAUD 115200
#endif

#define FLASH_TIMEOUT_MS 800

static void flush_in(void) {
    while (Serial1.available()) Serial1.read();
}

static int read_bytes(uint8_t *out, int n, unsigned long to_ms) {
    int got = 0;
    unsigned long t0 = millis();
    while (got < n) {
        if (Serial1.available()) {
            out[got++] = (uint8_t)Serial1.read();
            t0 = millis();
        } else if (millis() - t0 > to_ms) {
            break;
        }
    }
    return got;
}

void flash_link_init(void) {
    Serial1.begin(FLASH_UART_BAUD, SERIAL_8N1, FLASH_UART_RX_PIN, FLASH_UART_TX_PIN);
    delay(50);
    flush_in();
    uint8_t id[3] = { 0, 0, 0 };
    if (flash_read_id(id)) {
        Serial.printf("[flash] JEDEC = %02X %02X %02X\n", id[0], id[1], id[2]);
        char j[9];
        snprintf(j, sizeof(j), "J:%02X%02X%02X", id[0], id[1], id[2]);
        flash_log_append(LOG_EVT, millis() / 1000, 0, j);
    } else {
        Serial.println("[flash] JEDEC read timeout (chip non risponde?)");
    }
    uint8_t sr = 0;
    if (flash_read_sr(&sr)) {
        Serial.printf("[flash] Status Reg = 0x%02X  (BP=%u%u%u  WIP=%u  WEL=%u)\n",
                      sr,
                      (sr >> 4) & 1, (sr >> 3) & 1, (sr >> 2) & 1,
                      (sr >> 0) & 1, (sr >> 1) & 1);
    } else {
        Serial.println("[flash] Status Reg read timeout");
    }
}

bool flash_read_id(uint8_t id[3]) {
    flush_in();
    Serial1.write((uint8_t)'I');
    return read_bytes(id, 3, FLASH_TIMEOUT_MS) == 3;
}

bool flash_read_sr(uint8_t *sr) {
    flush_in();
    Serial1.write((uint8_t)'T');
    return read_bytes(sr, 1, FLASH_TIMEOUT_MS) == 1;
}

int flash_log_head(void) {
    flush_in();
    Serial1.write((uint8_t)'H');
    uint8_t b[2];
    if (read_bytes(b, 2, FLASH_TIMEOUT_MS) != 2) return -1;
    return ((int)b[0] << 8) | b[1];
}

bool flash_log_append(uint8_t type, uint32_t t_sec, uint8_t val, const char *text) {
    static uint16_t seq = 0;
    uint8_t rec[FLASH_REC_BYTES];
    memset(rec, 0, sizeof(rec));
    rec[0] = (uint8_t)(seq >> 8);
    rec[1] = (uint8_t)(seq & 0xFF);
    rec[2] = type;
    rec[3] = (uint8_t)(t_sec >> 24);
    rec[4] = (uint8_t)(t_sec >> 16);
    rec[5] = (uint8_t)(t_sec >> 8);
    rec[6] = (uint8_t)(t_sec);
    rec[7] = val;
    if (text) {
        for (int i = 0; i < 8 && text[i]; i++) rec[8 + i] = (uint8_t)text[i];
    }
    seq++;

    flush_in();
    Serial1.write((uint8_t)'L');
    Serial1.write(rec, FLASH_REC_BYTES);
    uint8_t ack;
    return read_bytes(&ack, 1, FLASH_TIMEOUT_MS) == 1 && ack == 'K';
}

int flash_log_read(int slot, int n, uint8_t *out) {
    if (n < 1 || n > 4) return -1;
    flush_in();
    Serial1.write((uint8_t)'G');
    Serial1.write((uint8_t)((slot >> 8) & 0xFF));
    Serial1.write((uint8_t)(slot & 0xFF));
    Serial1.write((uint8_t)n);
    return read_bytes(out, n * FLASH_REC_BYTES, FLASH_TIMEOUT_MS);
}

bool flash_log_clear(void) {
    flush_in();
    Serial1.write((uint8_t)'C');
    uint8_t ack;
    return read_bytes(&ack, 1, 2000) == 1 && ack == 'K';
}

bool flash_get_settings(flash_settings_t *s) {
    flush_in();
    Serial1.write((uint8_t)'Q');
    uint8_t b[FLASH_SET_BYTES];
    if (read_bytes(b, FLASH_SET_BYTES, FLASH_TIMEOUT_MS) != FLASH_SET_BYTES) return false;
    if (b[0] != 0xA5) {
        memset(s, 0, sizeof(*s));
        strcpy(s->name, "Master EFES");
        s->auto_presence_s = 0;
        s->presence_tries  = 6;
        return true;
    }
    memset(s, 0, sizeof(*s));
    memcpy(s->name, &b[1], 15);
    s->name[15] = 0;
    s->auto_presence_s = ((uint16_t)b[16] << 8) | b[17];
    s->presence_tries  = b[18];
    return true;
}

bool flash_set_settings(const flash_settings_t *s) {
    uint8_t b[FLASH_SET_BYTES];
    memset(b, 0, sizeof(b));
    b[0] = 0xA5;
    for (int i = 0; i < 15 && s->name[i]; i++) b[1 + i] = (uint8_t)s->name[i];
    b[16] = (uint8_t)(s->auto_presence_s >> 8);
    b[17] = (uint8_t)(s->auto_presence_s & 0xFF);
    b[18] = s->presence_tries;

    flush_in();
    Serial1.write((uint8_t)'S');
    Serial1.write(b, FLASH_SET_BYTES);
    uint8_t ack;
    return read_bytes(&ack, 1, 2000) == 1 && ack == 'K';
}
