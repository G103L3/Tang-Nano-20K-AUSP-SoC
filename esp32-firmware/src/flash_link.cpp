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

#define FLASH_CACHE_N    60

static flash_cache_rec_t s_cache[FLASH_CACHE_N];
static int  s_cache_head  = 0;
static int  s_cache_count = 0;
static bool s_chip_locked = false;

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

static void cache_push(const uint8_t *rec) {
    flash_cache_rec_t *c = &s_cache[s_cache_head];
    c->seq   = ((uint16_t)rec[0] << 8) | rec[1];
    c->type  = rec[2];
    c->t_sec = ((uint32_t)rec[3] << 24) | ((uint32_t)rec[4] << 16) |
               ((uint32_t)rec[5] << 8)  |  (uint32_t)rec[6];
    c->val   = rec[7];
    memcpy(c->text, &rec[8], 8);
    c->text[8] = 0;
    s_cache_head = (s_cache_head + 1) % FLASH_CACHE_N;
    if (s_cache_count < FLASH_CACHE_N) s_cache_count++;
}

static void print_sr_decoded(const char *tag, uint8_t sr) {
    Serial.printf("[flash] %s SR = 0x%02X  (SRP=%u  BP=%u%u%u  WEL=%u  WIP=%u)\n",
                  tag, sr,
                  (sr >> 7) & 1,
                  (sr >> 4) & 1, (sr >> 3) & 1, (sr >> 2) & 1,
                  (sr >> 1) & 1, (sr >> 0) & 1);
}

static void consume_boot_sr_report(void) {
    /* La FSM FPGA, dopo WRSR+POLL, manda 2 byte: 'S' + sr_byte. Pero' lo fa
     * MOLTO prima che la Serial1 dell'ESP32 sia accesa (boot ESP32 ~700 ms,
     * boot FPGA ms), quindi quasi sempre i byte sono persi. Faccio solo una
     * controllata rapida (50 ms) nel caso in cui per qualche motivo il
     * messaggio arrivi tardi; altrimenti pazienza, flash_read_sr() qui sotto
     * mi dara' comunque il SR via opcode 'T'. */
    unsigned long t0 = millis();
    while (millis() - t0 < 50) {
        if (Serial1.available()) {
            uint8_t b = (uint8_t)Serial1.read();
            if (b == 'S') {
                uint8_t sr = 0xFF;
                if (read_bytes(&sr, 1, 80) == 1) {
                    print_sr_decoded("boot", sr);
                    if ((sr & 0x9C) != 0) {
                        s_chip_locked = true;
                        Serial.println("[flash] CHIP LOCKED (SR mostra BP/SRP set)");
                    }
                }
                return;
            }
        }
    }
}

void flash_link_init(void) {
    Serial1.begin(FLASH_UART_BAUD, SERIAL_8N1, FLASH_UART_RX_PIN, FLASH_UART_TX_PIN);
    delay(50);
    consume_boot_sr_report();
    flush_in();

    uint8_t id[3] = { 0, 0, 0 };
    if (flash_read_id(id)) {
        Serial.printf("[flash] JEDEC = %02X %02X %02X\n", id[0], id[1], id[2]);
    } else {
        Serial.println("[flash] JEDEC read timeout (chip non risponde?)");
    }

    /* Leggo SR via opcode 'T' come fonte canonica (il boot report dell'FPGA
     * di solito ce lo perdiamo perche' la nostra Serial1 non e' ancora
     * accesa). Aggiorno s_chip_locked di conseguenza. */
    uint8_t sr = 0;
    if (flash_read_sr(&sr)) {
        print_sr_decoded("post-boot", sr);
        if ((sr & 0x9C) != 0) {
            s_chip_locked = true;
            Serial.println("[flash] CHIP LOCKED (SR mostra BP/SRP set)");
        }
    } else {
        Serial.println("[flash] Status Reg read timeout");
    }

    /* Solo dopo aver capito SR loggo "boot" e "J:..." (cosi' se il chip e'
     * lockato non spammiamo decine di VERIFY FAIL inutili). */
    if (id[0] != 0 || id[1] != 0 || id[2] != 0) {
        char j[9];
        snprintf(j, sizeof(j), "J:%02X%02X%02X", id[0], id[1], id[2]);
        flash_log_append(LOG_EVT, millis() / 1000, 0, j);
    }

    flash_log_dump_diagnostic();
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
    uint16_t this_seq = seq;
    seq++;

    /* Retry loop: signal integrity sui filini volanti puo' far fallire il
     * page program randomicamente. Ogni retry usa lo slot successivo (head
     * della FSM e' gia' avanzato dopo un fallimento). Gli slot falliti
     * restano "garbage" ma con lo SCAN che ora valida byte 2 ∈ {B,R,P,N,E}
     * vengono ignorati al boot successivo. */
    const int MAX_RETRIES = 5;
    uint8_t rb[FLASH_REC_BYTES];

    for (int attempt = 1; attempt <= MAX_RETRIES; attempt++) {
        flush_in();
        Serial1.write((uint8_t)'L');
        Serial1.write(rec, FLASH_REC_BYTES);
        uint8_t ack;
        int n = read_bytes(&ack, 1, FLASH_TIMEOUT_MS);
        if (n != 1) {
            Serial.printf("[flash] att.%d/%d: timeout (seq=%u)\n", attempt, MAX_RETRIES, this_seq);
            continue;
        }
        if (ack == 'E') {
            Serial.printf("[flash] att.%d/%d: ack='E' (FSM rifiuta)\n", attempt, MAX_RETRIES);
            cache_push(rec);
            return false;
        }
        if (ack != 'K') {
            Serial.printf("[flash] att.%d/%d: ack=0x%02X (atteso K)\n", attempt, MAX_RETRIES, ack);
            continue;
        }

        int head = flash_log_head();
        if (head < 0) {
            Serial.printf("[flash] att.%d/%d: head read fail\n", attempt, MAX_RETRIES);
            continue;
        }
        int verify_slot = (head - 1 + FLASH_N_SLOTS) % FLASH_N_SLOTS;
        if (flash_log_read(verify_slot, 1, rb) != FLASH_REC_BYTES) {
            Serial.printf("[flash] att.%d/%d: verify read fail slot=%d\n", attempt, MAX_RETRIES, verify_slot);
            continue;
        }
        int bad_off = -1;
        for (int i = 0; i < FLASH_REC_BYTES; i++) {
            if (rb[i] != rec[i]) { bad_off = i; break; }
        }
        if (bad_off >= 0) {
            Serial.printf("[flash] att.%d/%d: VERIFY FAIL slot=%d byte[%d] atteso 0x%02X letto 0x%02X\n",
                          attempt, MAX_RETRIES, verify_slot, bad_off, rec[bad_off], rb[bad_off]);
            continue;
        }

        Serial.printf("[flash] head=%d (write OK att.%d/%d type=%c seq=%u)\n",
                      head, attempt, MAX_RETRIES, (char)type, this_seq);
        cache_push(rec);
        return true;
    }

    Serial.printf("[flash] FAIL definitivo dopo %d retry (type=%c seq=%u)\n",
                  MAX_RETRIES, (char)type, this_seq);
    cache_push(rec);
    return false;
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
    bool ok = read_bytes(&ack, 1, 2000) == 1 && ack == 'K';
    if (ok) {
        s_cache_head = 0;
        s_cache_count = 0;
    }
    return ok;
}

bool flash_get_settings(flash_settings_t *s) {
    flush_in();
    Serial1.write((uint8_t)'Q');
    uint8_t b[FLASH_SET_BYTES];
    if (read_bytes(b, FLASH_SET_BYTES, FLASH_TIMEOUT_MS) != FLASH_SET_BYTES) return false;

    /* Default sentinel: magic mancante OPPURE partial-write garbage (es.
     * tries=255, name pieno di 0xFF) -> ritorno default sicuri. */
    bool valid = (b[0] == 0xA5);
    if (valid) {
        /* tries deve essere 1..30 (campo presence_tries e' uint8 ma valori
         * realistici sono pochi); 0 e 255 sono sintomo di write parziale. */
        if (b[18] == 0 || b[18] > 30) valid = false;
    }
    if (valid) {
        /* name deve avere solo char stampabili o 0x00 di terminazione.
         * Bytes 0xFF -> partial-write -> reject. */
        for (int i = 0; i < 15; i++) {
            uint8_t c = b[1 + i];
            if (c == 0x00) break;
            if (c < 0x20 || c > 0x7E) { valid = false; break; }
        }
    }
    if (!valid) {
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

    /* Retry+verify identico a flash_log_append: il page program della pagina
     * settings ha gli stessi disturbi di SI delle write di log, e senza
     * verify si finisce con magic byte assente / nome 0xFF / tries=255. */
    const int MAX_RETRIES = 5;
    uint8_t rb[FLASH_SET_BYTES];

    for (int attempt = 1; attempt <= MAX_RETRIES; attempt++) {
        flush_in();
        Serial1.write((uint8_t)'S');
        Serial1.write(b, FLASH_SET_BYTES);
        uint8_t ack;
        int n = read_bytes(&ack, 1, 2000);
        if (n != 1) {
            Serial.printf("[flash] settings att.%d/%d: timeout\n", attempt, MAX_RETRIES);
            continue;
        }
        if (ack == 'E') {
            Serial.printf("[flash] settings att.%d/%d: ack='E' (FSM rifiuta)\n", attempt, MAX_RETRIES);
            return false;
        }
        if (ack != 'K') {
            Serial.printf("[flash] settings att.%d/%d: ack=0x%02X\n", attempt, MAX_RETRIES, ack);
            continue;
        }

        flush_in();
        Serial1.write((uint8_t)'Q');
        if (read_bytes(rb, FLASH_SET_BYTES, FLASH_TIMEOUT_MS) != FLASH_SET_BYTES) {
            Serial.printf("[flash] settings att.%d/%d: verify read fail\n", attempt, MAX_RETRIES);
            continue;
        }
        int bad_off = -1;
        for (int i = 0; i < FLASH_SET_BYTES; i++) {
            if (rb[i] != b[i]) { bad_off = i; break; }
        }
        if (bad_off >= 0) {
            Serial.printf("[flash] settings att.%d/%d: VERIFY FAIL byte[%d] atteso 0x%02X letto 0x%02X\n",
                          attempt, MAX_RETRIES, bad_off, b[bad_off], rb[bad_off]);
            continue;
        }

        int head = flash_log_head();
        Serial.printf("[flash] settings OK att.%d/%d  head=%d\n", attempt, MAX_RETRIES, head);
        return true;
    }

    Serial.printf("[flash] settings FAIL definitivo dopo %d retry\n", MAX_RETRIES);
    return false;
}

int flash_cache_get(flash_cache_rec_t *out, int max) {
    int n = (s_cache_count < max) ? s_cache_count : max;
    for (int i = 0; i < n; i++) {
        int idx = (s_cache_head - 1 - i + FLASH_CACHE_N) % FLASH_CACHE_N;
        out[i] = s_cache[idx];
    }
    return n;
}

void flash_log_dump_diagnostic(void) {
    uint8_t sr = 0;
    if (flash_read_sr(&sr)) {
        print_sr_decoded("diag", sr);
    } else {
        Serial.println("[flash] diag: SR read timeout");
    }
    int head = flash_log_head();
    Serial.printf("[flash] diag: head=%d  chip_locked(sw)=%d\n", head, s_chip_locked ? 1 : 0);
    Serial.println("[flash] diag: primi 10 slot:");
    uint8_t rec[FLASH_REC_BYTES];
    for (int i = 0; i < 10 && i < FLASH_N_SLOTS; i++) {
        if (flash_log_read(i, 1, rec) != FLASH_REC_BYTES) {
            Serial.printf("  slot %d: read fail\n", i);
            continue;
        }
        if (rec[2] == 0xFF) {
            Serial.printf("  slot %d: ERASED\n", i);
        } else {
            char txt[9]; memcpy(txt, &rec[8], 8); txt[8] = 0;
            Serial.printf("  slot %d: seq=%u type=%c val=%u text='%s'\n",
                          i, ((unsigned)rec[0] << 8) | rec[1], (char)rec[2], rec[7], txt);
        }
    }
}

bool flash_is_chip_locked(void) { return s_chip_locked; }
