#include <string.h>
#include "bit_input_packer.h"

#define TIMEOUT_MS 1000u

static uint32_t now_ms(void) {
    uint32_t c;
    asm volatile("rdcycle %0" : "=r"(c));
    return c / 27000u;
}

static bool is_allowed_ascii_char(unsigned char c) {
    if ((c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z'))
        return true;
    switch (c) {
        case '{': case '}': case '[': case ']':
        case '(': case ')': case ':': case ';':
            return true;
        default:
            return false;
    }
}

static bool is_clean_ascii(const char *s) {
    for (const unsigned char *p = (const unsigned char *)s; *p; ++p) {
        if (!is_allowed_ascii_char(*p)) return false;
    }
    return true;
}

BitPacker master_packer = {0};
BitPacker slave_packer  = {0};
BitPacker config_packer = {0};

static bool noise_flag_master = false;
static bool noise_flag_slave  = false;
static bool noise_flag_config = false;

char master_ascii_arrays[ASCII_NUM_ARRAYS][ASCII_ARRAY_SIZE] = {0};
char slave_ascii_arrays[ASCII_NUM_ARRAYS][ASCII_ARRAY_SIZE]  = {0};
char config_ascii_arrays[ASCII_NUM_ARRAYS][ASCII_ARRAY_SIZE] = {0};

bool master_ascii_ready = false;
bool slave_ascii_ready  = false;
bool config_ascii_ready = false;

static uint32_t last_bit_ms_master = 0;
static uint32_t last_bit_ms_slave  = 0;
static uint32_t last_bit_ms_config = 0;

static bool timeout_armed_master = false;
static bool timeout_armed_slave  = false;
static bool timeout_armed_config = false;

static char (*ascii_for_packer(BitPacker *packer))[ASCII_ARRAY_SIZE] {
    if (packer == &master_packer) return master_ascii_arrays;
    if (packer == &slave_packer)  return slave_ascii_arrays;
    return config_ascii_arrays;
}

static bool update_packet(BitPacker *packer) {
    packer->bit_position++;
    if (packer->bit_position >= MAX_ARRAY_SIZE) {
        packer->bit_position = 0;
        packer->array_index++;
    }
    return packer->array_index >= NUM_ARRAYS;
}

static unsigned long bits7_to_byte(const char *bits) {
    unsigned long v = 0;
    for (int i = 0; i < 7; i++) v = (v << 1) | (bits[i] == '1' ? 1u : 0u);
    return v;
}

bool flush_and_convert_to_ascii(BitPacker *packer, const char *label) {
    (void)label;
    size_t total_bits;
    if (packer->bit_position == 0)
        total_bits = packer->array_index * MAX_ARRAY_SIZE;
    else if (packer->array_index > 0)
        total_bits = packer->array_index * packer->bit_position;
    else
        total_bits = packer->bit_position;
    size_t total_bytes = total_bits / 7;

    char temp[ASCII_PACKET_SIZE] = {0};
    size_t array_index = 0;
    size_t byte_index  = 0;
    size_t buf_idx     = 0;

    for (size_t i = 0; i < total_bytes && buf_idx < ASCII_PACKET_SIZE - 1; i++) {
        if (byte_index + 7 > MAX_ARRAY_SIZE) {
            byte_index = 0;
            array_index++;
        }
        char bits[8] = {0};
        for (size_t j = 0; j < 7; j++) {
            bits[j] = packer->arrays[array_index][byte_index + j] ? '1' : '0';
        }
        temp[buf_idx++] = (char)bits7_to_byte(bits);
        byte_index += 7;
        if (byte_index >= MAX_ARRAY_SIZE) {
            byte_index = 0;
            array_index++;
        }
    }
    temp[buf_idx] = '\0';

    if (temp[0] && !is_clean_ascii(temp)) {
        packer->array_index  = 0;
        packer->bit_position = 0;
        memset(packer->arrays, 0, sizeof(packer->arrays));
        return false;
    }

    char (*ascii_dest)[ASCII_ARRAY_SIZE] = ascii_for_packer(packer);
    for (size_t i = 0; i < ASCII_NUM_ARRAYS; i++) memset(ascii_dest[i], 0, ASCII_ARRAY_SIZE);
    packer->ascii_array_index = 0;
    packer->ascii_char_index  = 0;
    for (size_t i = 0; i < buf_idx; i++) {
        ascii_dest[packer->ascii_array_index][packer->ascii_char_index++] = temp[i];
        if (packer->ascii_char_index >= ASCII_ARRAY_SIZE) {
            packer->ascii_char_index = 0;
            packer->ascii_array_index++;
            if (packer->ascii_array_index >= ASCII_NUM_ARRAYS) break;
        }
    }
    if (packer->ascii_array_index < ASCII_NUM_ARRAYS && packer->ascii_char_index < ASCII_ARRAY_SIZE)
        ascii_dest[packer->ascii_array_index][packer->ascii_char_index] = '\0';

    packer->array_index  = 0;
    packer->bit_position = 0;
    memset(packer->arrays, 0, sizeof(packer->arrays));

    if (packer == &master_packer) master_ascii_ready = true;
    else if (packer == &slave_packer) slave_ascii_ready = true;
    else if (packer == &config_packer) config_ascii_ready = true;
    return true;
}

static bool timeout_flush_if_needed(BitPacker *packer, bool *timeout_armed, uint32_t last_bit_ms, bool no_new_bit) {
    if (!*timeout_armed || !no_new_bit) return false;
    if ((now_ms() - last_bit_ms) < TIMEOUT_MS) return false;
    bool ok = flush_and_convert_to_ascii(packer, "");
    *timeout_armed = false;
    return ok;
}

bool add_bit(BitPacker *packer, uint8_t signal_code, const char *label) {
    (void)label;
    size_t array_index_ = packer->array_index;
    size_t bit_index    = packer->bit_position;

    if (signal_code <= 9) {
        if (signal_code <= 6) {
            for (int i = 0; i <= (int)signal_code; i++) {
                packer->arrays[array_index_][bit_index] = 0;
                if (update_packet(packer)) return flush_and_convert_to_ascii(packer, "");
                array_index_ = packer->array_index;
                bit_index    = packer->bit_position;
            }
        }
        if (signal_code == 8)
            return flush_and_convert_to_ascii(packer, "");
    } else {
        if (signal_code <= 19) {
            uint8_t sc = signal_code % 10;
            for (int i = 0; i <= (int)sc; i++) {
                packer->arrays[array_index_][bit_index] = 1;
                if (update_packet(packer)) return flush_and_convert_to_ascii(packer, "");
                array_index_ = packer->array_index;
                bit_index    = packer->bit_position;
            }
        }
    }
    return false;
}

bool process_tone_bits(struct_tone_bits input) {
    bool has_tone_master = (input.master >= 0);
    bool has_tone_slave  = (input.slave  >= 0);
    bool has_tone_config = (input.configuration >= 0);

    bool packet_ready = false;

    if (!has_tone_master) noise_flag_master = true;
    if (!has_tone_slave)  noise_flag_slave  = true;
    if (!has_tone_config) noise_flag_config = true;

    if (!noise_flag_master && !noise_flag_slave && !noise_flag_config) return false;

    packet_ready |= timeout_flush_if_needed(&master_packer, &timeout_armed_master, last_bit_ms_master, !has_tone_master);
    packet_ready |= timeout_flush_if_needed(&slave_packer,  &timeout_armed_slave,  last_bit_ms_slave,  !has_tone_slave);
    packet_ready |= timeout_flush_if_needed(&config_packer, &timeout_armed_config, last_bit_ms_config, !has_tone_config);

    uint32_t tnow = now_ms();

    if (has_tone_master && noise_flag_master) {
        if (input.master == 8) {
            if (add_bit(&master_packer, (uint8_t)input.master, "")) packet_ready = true;
            timeout_armed_master = false;
        } else {
            if (add_bit(&master_packer, (uint8_t)input.master, "")) packet_ready = true;
            timeout_armed_master = true;
            last_bit_ms_master   = tnow;
        }
        noise_flag_master = false;
    }

    if (has_tone_slave && noise_flag_slave) {
        if (input.slave == 8) {
            if (add_bit(&slave_packer, (uint8_t)input.slave, "")) packet_ready = true;
            timeout_armed_slave = false;
        } else {
            if (add_bit(&slave_packer, (uint8_t)input.slave, "")) packet_ready = true;
            timeout_armed_slave = true;
            last_bit_ms_slave   = tnow;
        }
        noise_flag_slave = false;
    }

    if (has_tone_config && noise_flag_config) {
        if (input.configuration == 8) {
            if (add_bit(&config_packer, (uint8_t)input.configuration, "")) packet_ready = true;
            timeout_armed_config = false;
        } else {
            if (add_bit(&config_packer, (uint8_t)input.configuration, "")) packet_ready = true;
            timeout_armed_config = true;
            last_bit_ms_config   = tnow;
        }
        noise_flag_config = false;
    }

    return packet_ready;
}
