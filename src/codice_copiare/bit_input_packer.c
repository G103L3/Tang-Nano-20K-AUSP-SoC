/*! \file bit_input_packer.c
 * \author Gioele Giunta
 * \version 1.5
 * \since 2025
 * \brief Implementazione del modulo bit input packer
 */

/* Librerie */
#include <stdio.h>
#include <string.h>
#include <time.h>            // <-- per clock_gettime

/* Headers specifici */
#include "serial_bridge.h"
#include "bit_input_packer.h"

#ifdef __cplusplus
extern "C" {
#endif


#define TOTAL_BITS (MAX_ARRAY_SIZE * NUM_ARRAYS * 7)

/* ------------------------ Nuove utility: tempo & filtro ASCII ------------------------ */
/**
 * @brief Funzione now_ms.
 * @return Valore di ritorno.
 */

static uint64_t now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000ULL + (uint64_t)(ts.tv_nsec / 1000000ULL);
}
/**
 * @brief Funzione is_allowed_ascii_char.
 * @param c Parametro c.
 * @return Valore di ritorno.
 */

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
/**
 * @brief Funzione is_clean_ascii.
 * @param s Parametro s.
 * @return Valore di ritorno.
 */

static bool is_clean_ascii(const char* s) {
    /* scarta stringhe con controlli (NUL, DEL, ecc.) o caratteri non ammessi */
    for (const unsigned char* p = (const unsigned char*)s; *p; ++p) {
        if (!is_allowed_ascii_char(*p)) {
            return false;
        }
    }
    return true;
}

/* ------------------------------------------------------------------------------------- */

BitPacker master_packer = {0};
BitPacker slave_packer = {0};
BitPacker config_packer = {0};

static bool noise_flag_master = false;
static bool noise_flag_slave = false;
static bool noise_flag_config = false;

char master_ascii_arrays[ASCII_NUM_ARRAYS][ASCII_ARRAY_SIZE] = {0};
char slave_ascii_arrays[ASCII_NUM_ARRAYS][ASCII_ARRAY_SIZE] = {0};
char config_ascii_arrays[ASCII_NUM_ARRAYS][ASCII_ARRAY_SIZE] = {0};

bool master_ascii_ready = false;
bool slave_ascii_ready = false;
bool config_ascii_ready = false;

int test_count = 0;

/* ------------------------ Stato timeout per canale (1s) ------------------------------ */
static uint64_t last_bit_ms_master  = 0;
static uint64_t last_bit_ms_slave   = 0;
static uint64_t last_bit_ms_config  = 0;

static bool timeout_armed_master    = false;
static bool timeout_armed_slave     = false;
static bool timeout_armed_config    = false;

#define TIMEOUT_MS 1000
/* ------------------------------------------------------------------------------------- */

static char (*ascii_for_packer(BitPacker* packer))[ASCII_ARRAY_SIZE] {
    if (packer == &master_packer) return master_ascii_arrays;
    if (packer == &slave_packer) return slave_ascii_arrays;
    return config_ascii_arrays;
}
/**
 * @brief Funzione update_packet.
 * @param packer_ Parametro packer_.
 * @param label_ Parametro label_.
 * @return Valore di ritorno.
 */

bool update_packet(BitPacker* packer_, char* label_){
    packer_->bit_position++;
    if (packer_->bit_position >= MAX_ARRAY_SIZE) {
        packer_->bit_position = 0;
        packer_->array_index++;
    }
    if (packer_->array_index >= NUM_ARRAYS) {
        printf("Warning: %s arrays full. Auto flush.\n", label_);
        return true;
    }else{
        return false;
    }
}
/**
 * @brief Funzione flush_and_convert_to_ascii.
 * @param packer Parametro packer.
 * @param label Parametro label.
 * @return Valore di ritorno.
 */

bool flush_and_convert_to_ascii(BitPacker* packer, const char* label) {
    size_t total_bits = 0;
    if (packer->bit_position == 0){
        total_bits = packer->array_index * MAX_ARRAY_SIZE;
    } else if (packer->array_index > 0){
        total_bits = packer->array_index * packer->bit_position;
    } else if (packer->array_index == 0 && packer->bit_position > 0){
        total_bits = packer->bit_position;
    }
    size_t total_bytes = total_bits / 7;

    serial_write_formatted("Info: Flushing %s packer with %zu bits (%zu bytes)\n",
                           label, packer->bit_position, total_bytes);

    char temp[ASCII_PACKET_SIZE] = {0};
    size_t array_index = 0;
    size_t byte_index = 0;
    size_t buf_idx = 0;
    printf("Info: Converting %zu bits to ASCII\n", total_bits);
    for (size_t i = 0; i < total_bytes && buf_idx < ASCII_PACKET_SIZE - 1; i++) {
        if (byte_index + 7 > MAX_ARRAY_SIZE) {
            byte_index = 0;
            array_index++;
        }
        char bits[8] = {0}; /* <-- assicurati che sia terminato a NUL */
        for (size_t j = 0; j < 7; j++) {
            bits[j] = packer->arrays[array_index][byte_index + j] ? '1' : '0';
        }

        unsigned long value = strtoul(bits, NULL, 2);
        temp[buf_idx++] = (char)value;
        printf("-> %c \n", (char)value);

        byte_index += 7;
        if (byte_index >= MAX_ARRAY_SIZE) {
            byte_index = 0;
            array_index++;
        }
    }
    temp[buf_idx] = '\0';

    if (temp[0] && !is_clean_ascii(temp)) {
        printf("%s: flush scartato (caratteri non ammessi). Considerato sporcizia.\n", label);
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
                printf("Warning: %s ASCII arrays full.\n", label);
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
    if (packer == &master_packer) master_ascii_ready = true;
    else if (packer == &slave_packer) slave_ascii_ready = true;
    else if (packer == &config_packer) config_ascii_ready = true;
    return true;
}

/* ------------------------ Flush condizionato da timeout + validazione ---------------- */
/**
 * @brief Funzione timeout_flush_if_needed.
 * @param packer Parametro packer.
 * @param label Parametro label.
 * @param timeout_armed Parametro timeout_armed.
 * @param last_bit_ms Parametro last_bit_ms.
 * @param no_new_bit_this_tick Parametro no_new_bit_this_tick.
 * @return Valore di ritorno.
 */
static bool timeout_flush_if_needed(BitPacker* packer,
                                     const char* label,
                                     bool* timeout_armed,
                                     uint64_t last_bit_ms,
                                     bool no_new_bit_this_tick)
{
    if (!*timeout_armed) return false;
    if (!no_new_bit_this_tick) return false; /* è arrivato un bit ora: non flussare */

    uint64_t tnow = now_ms();
    if ((tnow - last_bit_ms) < TIMEOUT_MS) return false;

    bool ok = flush_and_convert_to_ascii(packer, label);
    *timeout_armed = false; /* finestra chiusa */
    return ok;
}
/* ------------------------------------------------------------------------------------- */
/**
 * @brief Funzione add_bit.
 * @param packer Parametro packer.
 * @param signal_code Parametro signal_code.
 * @param label Parametro label.
 * @return Valore di ritorno.
 */

bool add_bit(BitPacker* packer, uint8_t signal_code, const char* label) {
    size_t array_index_ = packer->array_index;
    size_t bit_index = packer->bit_position;

    serial_write_formatted("Info: Array_index: %d\n", array_index_);

    if (signal_code <= 9) {
        if(signal_code <= 6){
            for(int i = 0; i < signal_code+1; i++){
                packer->arrays[array_index_][bit_index] = 0;
                if(update_packet(packer, (char*)label)){
                    return flush_and_convert_to_ascii(packer, label);
                }
                array_index_ = packer->array_index;
                bit_index = packer->bit_position;
            }
        }
        if(signal_code == 8){
            /* Code 8 = 21 zeri (flush immediato) */
            printf("%s: %d consecutive 1s (code 8). Auto flush.\n", label, MAX_CONSECUTIVE_ZEROS);
            return flush_and_convert_to_ascii(packer, label);
        }
    } else {
        if(signal_code <= 19){
            signal_code = signal_code%10;
            for(int i = 0; i < signal_code+1; i++){
                packer->arrays[array_index_][bit_index] = 1;
                if(update_packet(packer, (char*)label)){
                    return flush_and_convert_to_ascii(packer, label);
                }
                array_index_ = packer->array_index;
                bit_index = packer->bit_position;
            }
        }
    }

    return false;
}
/**
 * @brief Funzione process_tone_bits.
 * @param input Parametro input.
 * @return Valore di ritorno.
 */

bool process_tone_bits(struct_tone_bits input) {
    bool has_tone_master = (input.master >= 0);
    bool has_tone_slave  = (input.slave >= 0);
    bool has_tone_config = (input.configuration >= 0);

    bool packet_ready = false;

    /* Mantieni la logica "noise" esistente */
    if (!has_tone_master) noise_flag_master = true;
    if (!has_tone_slave)  noise_flag_slave  = true;
    if (!has_tone_config) noise_flag_config = true;

    if (!noise_flag_master && !noise_flag_slave && !noise_flag_config) {
        /* Nessun canale in rumore ⇒ nulla da fare */
        return false;
    }

    /* 1) Prima: gestisci timeout (se in questa "tick" non è arrivato un nuovo bit per quel canale) */
    packet_ready |= timeout_flush_if_needed(&master_packer, "MASTER", &timeout_armed_master, last_bit_ms_master, !has_tone_master);
    packet_ready |= timeout_flush_if_needed(&slave_packer,  "SLAVE",  &timeout_armed_slave,  last_bit_ms_slave,  !has_tone_slave);
    packet_ready |= timeout_flush_if_needed(&config_packer, "CONFIG", &timeout_armed_config, last_bit_ms_config, !has_tone_config);

    uint64_t tnow = now_ms();

    /* 2) Poi: processa eventuali nuovi bit */
    if (has_tone_master && noise_flag_master) {
        printf(" %d- ", input.master);

        /* Se è code 8, flush immediato e disarma timeout */
        if (input.master == 8) {
            if(add_bit(&master_packer, input.master, "MASTER")) packet_ready = true;
            timeout_armed_master = false;
        } else {
            if(add_bit(&master_packer, input.master, "MASTER")) packet_ready = true;
            /* arma la finestra di 1s in attesa del prossimo bit o di code 8 */
            timeout_armed_master = true;
            last_bit_ms_master = tnow;
        }
        noise_flag_master = false;
    }

    if (has_tone_slave && noise_flag_slave) {
        if (input.slave == 8) {
            if(add_bit(&slave_packer, input.slave, "SLAVE")) packet_ready = true;
            timeout_armed_slave = false;
        } else {
            if(add_bit(&slave_packer, input.slave, "SLAVE")) packet_ready = true;
            timeout_armed_slave = true;
            last_bit_ms_slave = tnow;
        }
        noise_flag_slave = false;
    }

    if (has_tone_config && noise_flag_config) {
        if (input.configuration == 8) {
            if(add_bit(&config_packer, input.configuration, "CONFIG")) packet_ready = true;
            timeout_armed_config = false;
        } else {
            if(add_bit(&config_packer, input.configuration, "CONFIG")) packet_ready = true;
            timeout_armed_config = true;
            last_bit_ms_config = tnow;
        }
        noise_flag_config = false;
    }

    return packet_ready;
}

#ifdef __cplusplus
}
#endif
