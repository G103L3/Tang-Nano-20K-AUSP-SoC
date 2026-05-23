/*! \file bit_input_packer.cpp
 * \brief Porting del bit_input_packer dal reference C, adattato ad Arduino/ESP32.
 *   - now_ms() -> millis()
 *   - printf di debug -> BIP_LOG (definisci BIP_VERBOSE per riattivarli)
 * La logica di accumulo bit / run-length / flush ASCII e' invariata.
 */
#include <Arduino.h>
#include <string.h>
#include <stdlib.h>

#include "bit_input_packer.h"

#ifdef BIP_VERBOSE
#define BIP_LOG(...) Serial.printf(__VA_ARGS__)
#else
#define BIP_LOG(...)
#endif

#define TOTAL_BITS (MAX_ARRAY_SIZE * NUM_ARRAYS * 7)
#define TIMEOUT_MS 1000

static uint64_t now_ms(void) {
    return (uint64_t)millis();
}

static bool is_allowed_ascii_char(unsigned char c) {
    if ((c >= '0' && c <= '9') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= 'a' && c <= 'z'))
        return true;
    switch (c) {
        case '{': case '}': case '[': case ']':
        case '(': case ')': case ':': case ';':
            return true;
        default:
            return false;
    }
}

static bool is_clean_ascii(const char* s) {
    for (const unsigned char* p = (const unsigned char*)s; *p; ++p) {
        if (!is_allowed_ascii_char(*p)) return false;
    }
    return true;
}

BitPacker master_packer = {};
BitPacker slave_packer  = {};
BitPacker config_packer = {};

static bool noise_flag_master = false;
static bool noise_flag_slave  = false;
static bool noise_flag_config = false;

char master_ascii_arrays[ASCII_NUM_ARRAYS][ASCII_ARRAY_SIZE] = {};
char slave_ascii_arrays [ASCII_NUM_ARRAYS][ASCII_ARRAY_SIZE] = {};
char config_ascii_arrays[ASCII_NUM_ARRAYS][ASCII_ARRAY_SIZE] = {};

bool master_ascii_ready = false;
bool slave_ascii_ready  = false;
bool config_ascii_ready = false;

static uint64_t last_bit_ms_master = 0;
static uint64_t last_bit_ms_slave  = 0;
static uint64_t last_bit_ms_config = 0;

static bool timeout_armed_master = false;
static bool timeout_armed_slave  = false;
static bool timeout_armed_config = false;

static char (*ascii_for_packer(BitPacker* packer))[ASCII_ARRAY_SIZE] {
    if (packer == &master_packer) return master_ascii_arrays;
    if (packer == &slave_packer)  return slave_ascii_arrays;
    return config_ascii_arrays;
}

bool update_packet(BitPacker* packer_, char* label_) {
    packer_->bit_position++;
    if (packer_->bit_position >= MAX_ARRAY_SIZE) {
        packer_->bit_position = 0;
        packer_->array_index++;
    }
    if (packer_->array_index >= NUM_ARRAYS) {
        BIP_LOG("Warning: %s arrays full. Auto flush.\n", label_);
        return true;
    }
    return false;
}

bool flush_and_convert_to_ascii(BitPacker* packer, const char* label) {
    size_t total_bits = 0;
    if (packer->bit_position == 0) {
        total_bits = packer->array_index * MAX_ARRAY_SIZE;
    } else if (packer->array_index > 0) {
        total_bits = packer->array_index * packer->bit_position;
    } else if (packer->array_index == 0 && packer->bit_position > 0) {
        total_bits = packer->bit_position;
    }
    size_t total_bytes = total_bits / 7;

    BIP_LOG("Info: Flushing %s packer with %u bits (%u bytes)\n",
            label, (unsigned)packer->bit_position, (unsigned)total_bytes);

    char temp[ASCII_PACKET_SIZE] = {};
    size_t array_index = 0;
    size_t byte_index = 0;
    size_t buf_idx = 0;
    for (size_t i = 0; i < total_bytes && buf_idx < ASCII_PACKET_SIZE - 1; i++) {
        if (byte_index + 7 > MAX_ARRAY_SIZE) {
            byte_index = 0;
            array_index++;
        }
        char bits[8] = {};
        for (size_t j = 0; j < 7; j++) {
            bits[j] = packer->arrays[array_index][byte_index + j] ? '1' : '0';
        }
        unsigned long value = strtoul(bits, NULL, 2);
        temp[buf_idx++] = (char)value;
        byte_index += 7;
        if (byte_index >= MAX_ARRAY_SIZE) {
            byte_index = 0;
            array_index++;
        }
    }
    temp[buf_idx] = '\0';

    /* DEBUG bring-up: byte grezzi ricostruiti (hex + printable) PRIMA del filtro. */
    Serial.printf("\n[FLUSH %s %u byte] hex:", label, (unsigned)buf_idx);
    for (size_t i = 0; i < buf_idx; i++) Serial.printf(" %02X", (unsigned char)temp[i]);
    Serial.print("  txt:\"");
    for (size_t i = 0; i < buf_idx; i++) {
        char c = temp[i];
        Serial.write((c >= 32 && c < 127) ? c : '.');
    }
    Serial.println("\"");

    if (temp[0] && !is_clean_ascii(temp)) {
        BIP_LOG("%s: flush scartato (caratteri non ammessi).\n", label);
        packer->array_index = 0;
        packer->bit_position = 0;
        memset(packer->arrays, 0, sizeof(packer->arrays));
        return false;
    }

    char (*ascii_dest)[ASCII_ARRAY_SIZE] = ascii_for_packer(packer);
    for (size_t i = 0; i < ASCII_NUM_ARRAYS; i++) {
        memset(ascii_dest[i], 0, ASCII_ARRAY_SIZE);
    }
    packer->ascii_array_index = 0;
    packer->ascii_char_index = 0;
    for (size_t i = 0; i < buf_idx; i++) {
        ascii_dest[packer->ascii_array_index][packer->ascii_char_index++] = temp[i];
        if (packer->ascii_char_index >= ASCII_ARRAY_SIZE) {
            packer->ascii_char_index = 0;
            packer->ascii_array_index++;
            if (packer->ascii_array_index >= ASCII_NUM_ARRAYS) {
                BIP_LOG("Warning: %s ASCII arrays full.\n", label);
                break;
            }
        }
    }
    if (packer->ascii_array_index < ASCII_NUM_ARRAYS && packer->ascii_char_index < ASCII_ARRAY_SIZE) {
        ascii_dest[packer->ascii_array_index][packer->ascii_char_index] = '\0';
    }

    packer->array_index = 0;
    packer->bit_position = 0;
    memset(packer->arrays, 0, sizeof(packer->arrays));
    if (packer == &master_packer)      master_ascii_ready = true;
    else if (packer == &slave_packer)  slave_ascii_ready = true;
    else if (packer == &config_packer) config_ascii_ready = true;
    return true;
}

static bool timeout_flush_if_needed(BitPacker* packer,
                                    const char* label,
                                    bool* timeout_armed,
                                    uint64_t last_bit_ms,
                                    bool no_new_bit_this_tick) {
    if (!*timeout_armed) return false;
    if (!no_new_bit_this_tick) return false;
    uint64_t tnow = now_ms();
    if ((tnow - last_bit_ms) < TIMEOUT_MS) return false;
    bool ok = flush_and_convert_to_ascii(packer, label);
    *timeout_armed = false;
    return ok;
}

// Schema BINARIO {1,2,4} (vedi DIARIO 2026-05-22):
//   code 0/1/2  = 1/2/4 ZERI (pesi binari 2^0,2^1,2^2)
//   code 10/11/12 = 1/2/4 UNI
//   code 8      = EOP (flush)
// I run > 4 (o non-potenza-di-2) arrivano come codici consecutivi dello stesso
// bit, separati da silenzio: append accumulato => somma automatica del run.
bool add_bit(BitPacker* packer, uint8_t signal_code, const char* label) {
    size_t array_index_ = packer->array_index;
    size_t bit_index = packer->bit_position;

    if (signal_code == 8) {                 // EOP
        BIP_LOG("%s: EOP. Auto flush.\n", label);
        return flush_and_convert_to_ascii(packer, label);
    }

    uint8_t bit_value  = (signal_code < 10) ? 0 : 1;  // 0..2 = zeri, 10..12 = uni
    uint8_t weight_idx = signal_code % 10;            // 0,1,2
    int     count      = 1 << weight_idx;             // 1,2,4

    for (int i = 0; i < count; i++) {
        packer->arrays[array_index_][bit_index] = bit_value;
        if (update_packet(packer, (char*)label)) {
            return flush_and_convert_to_ascii(packer, label);
        }
        array_index_ = packer->array_index;
        bit_index = packer->bit_position;
    }
    return false;
}

bool process_tone_bits(struct_tone_bits input) {
    bool has_tone_master = (input.master >= 0);
    bool has_tone_slave  = (input.slave >= 0);
    bool has_tone_config = (input.configuration >= 0);

    bool packet_ready = false;

    if (!has_tone_master) noise_flag_master = true;
    if (!has_tone_slave)  noise_flag_slave  = true;
    if (!has_tone_config) noise_flag_config = true;

    if (!noise_flag_master && !noise_flag_slave && !noise_flag_config) {
        return false;
    }

    packet_ready |= timeout_flush_if_needed(&master_packer, "MASTER", &timeout_armed_master, last_bit_ms_master, !has_tone_master);
    packet_ready |= timeout_flush_if_needed(&slave_packer,  "SLAVE",  &timeout_armed_slave,  last_bit_ms_slave,  !has_tone_slave);
    packet_ready |= timeout_flush_if_needed(&config_packer, "CONFIG", &timeout_armed_config, last_bit_ms_config, !has_tone_config);

    uint64_t tnow = now_ms();

    if (has_tone_master && noise_flag_master) {
        Serial.printf("[M %d]", input.master);   /* code accettato (deduplicato) */
        if (input.master == 8) {
            if (add_bit(&master_packer, input.master, "MASTER")) packet_ready = true;
            timeout_armed_master = false;
        } else {
            if (add_bit(&master_packer, input.master, "MASTER")) packet_ready = true;
            timeout_armed_master = true;
            last_bit_ms_master = tnow;
        }
        noise_flag_master = false;
    }

    if (has_tone_slave && noise_flag_slave) {
        Serial.printf("[S %d]", input.slave);    /* code accettato (deduplicato) */
        if (input.slave == 8) {
            if (add_bit(&slave_packer, input.slave, "SLAVE")) packet_ready = true;
            timeout_armed_slave = false;
        } else {
            if (add_bit(&slave_packer, input.slave, "SLAVE")) packet_ready = true;
            timeout_armed_slave = true;
            last_bit_ms_slave = tnow;
        }
        noise_flag_slave = false;
    }

    if (has_tone_config && noise_flag_config) {
        Serial.printf("[C %d]", input.configuration);  /* code accettato (deduplicato) */
        if (input.configuration == 8) {
            if (add_bit(&config_packer, input.configuration, "CONFIG")) packet_ready = true;
            timeout_armed_config = false;
        } else {
            if (add_bit(&config_packer, input.configuration, "CONFIG")) packet_ready = true;
            timeout_armed_config = true;
            last_bit_ms_config = tnow;
        }
        noise_flag_config = false;
    }

    return packet_ready;
}
