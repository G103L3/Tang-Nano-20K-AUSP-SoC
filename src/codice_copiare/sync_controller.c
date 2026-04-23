/*! \file sync_controller.c
 * \author Gioele Giunta
 * \version 1.7
 * \since 2025
 * \brief Implementazione del modulo sync controller
 */

/* Librerie */
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

/* Headers specifici */
#include "decoder.h"
#include "fft.h"
#include "leds.h"
#include "reading_queue.h"
#include "sync_controller.h"
#include "serial_bridge.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#ifdef __cplusplus
extern "C" {
#endif




#define PAIR_COUNT 5
#define SHIFT_AMOUNT 248

double const freq_tolerance_ = (double)G_SAMPLE_RATE / (double)G_ARRAY_SIZE;
int sync_freq[] = {5200, 3700, 7200, 4200, 6700, 3200, 7700, 5700, 4700, 6200};

int start_point;
int range;
int temp_counter;
int last_valid_pair_index = -1;
int active_freq_flags[10] = {0};  /* 1 se la frequenza è stata trovata nella finestra */
complex_g3_t window_cut[WINDOW_SIZE];

static uint64_t next_slot_us = 0;
static const uint64_t SLOT_US = 10000ULL * 1000ULL;

/* Inizializza il controller di sincronizzazione */
/**
 * @brief Funzione sync_controller_init.
 */
void sync_controller_init() {
    start_point = 0;
    range = G_ARRAY_SIZE;
    temp_counter = 0;
    last_valid_pair_index = -1;
}
/**
 * @brief Funzione sync_time_init.
 */

void sync_time_init(void) {
    uint64_t now = esp_timer_get_time();
    next_slot_us = ((now / SLOT_US) + 1) * SLOT_US;
}
/**
 * @brief Funzione wait_for_next_slot.
 */

void wait_for_next_slot(void) {
    uint64_t now = esp_timer_get_time();
    if (now >= next_slot_us) {
        next_slot_us = ((now / SLOT_US) + 1) * SLOT_US;
    }
    uint64_t diff = next_slot_us - now;
    vTaskDelay(diff / 1000 / portTICK_PERIOD_MS);
    next_slot_us += SLOT_US;
}
/**
 * @brief Funzione resync_time.
 */

void resync_time(void) {
    uint64_t now = esp_timer_get_time();
    next_slot_us = ((now / SLOT_US) + 1) * SLOT_US;
}
/**
 * @brief Funzione analyze_sync_with_pair_tracking.
 */


void analyze_sync_with_pair_tracking() {
    int active_pairs[PAIR_COUNT] = {0};
    int active_pair_count = 0;

    /* Cerca le coppie simmetriche attive */
    for (int i = 0; i < PAIR_COUNT; i++) {
        int a = i;
        int b = 9 - i;

        if (active_freq_flags[a] && active_freq_flags[b]) {
            active_pairs[i] = 1;
            active_pair_count++;
        }
    }

    if (active_pair_count == 0) {
        serial_write_string("Nessuna coppia trovata → slittamento\n");
        start_point += SHIFT_AMOUNT;
        return;
    }

    if (active_pair_count > 1) {
        serial_write_string("Più coppie trovate → slittamento\n");
        start_point += SHIFT_AMOUNT;
        return;
    }

    /* Una sola coppia trovata: individua quale */
    int detected_pair = -1;
    for (int i = 0; i < PAIR_COUNT; i++) {
        if (active_pairs[i]) {
            detected_pair = i;
            break;
        }
    }

    if (detected_pair > last_valid_pair_index) {
        serial_write_formatted("Coppia %d rilevata (attesa >= %d) → OK, aggiornamento\n",
                               detected_pair, last_valid_pair_index + 1);
        last_valid_pair_index = detected_pair;
    } else {
        serial_write_formatted("Coppia %d rilevata ma non avanzata (attesa > %d) → ignorata\n",
                               detected_pair, last_valid_pair_index);
        /* Nessuno slittamento */
    }
}

/**
 * @file sync_controller.c
 * @brief Main function for sync analysis.
 * 
 * This file contains the implementation of the primary synchronization 
 * analysis function. It is part of the Project01Giunta project developed 
 * using PlatformIO.
 * 
 * @author Gioele Giunta
 * @date YYYY-MM-DD
 * @version 1.0
 * 
 * @note Ensure that all dependencies are correctly configured before 
 *       using this module.
 */
/**
 * @brief Funzione sync_ausp.
 * @param data Parametro data.
 */
void sync_ausp(complex_g3_t *data) {


    /* Reset flags */
    for (int i = 0; i < 10; i++) active_freq_flags[i] = 0;

    /* FFT */
    complex_g3_t *out = FFT_simple(data, WINDOW_SIZE);


    struct_tone_frequencies tone_frequencies = decode_ausp(out);


    double noise_floor = estimate_noise_floor(out, WINDOW_SIZE);

    /* Analisi frequenze */
    for (int i = 0; i < 10; i++) {
        turn_off();
        int bin = (int)floor(sync_freq[i] / freq_tolerance_);
        int range_start = bin;
        int range_end = bin + 1;

        struct_interpolated_frequency f = check_active_frequencies(out, range_start, range_end, i, noise_floor);

        if (f.work &&
            fabs(f.frequency - sync_freq[i]) <= freq_tolerance_ &&
            f.estimated_amplitude > f.dynamic_amplitude_threshold) {

            active_freq_flags[i] = 1;

            turn_blue(1);
            serial_write_formatted("Frequenza %d trovata (%f Hz)\n", i, f.frequency);
        }
    }

    /*analyze_sync_with_pair_tracking(); */
}

/* Funzione di chiamata generale */
/**
 * @brief Funzione detect_tones.
 * @return Valore di ritorno.
 */
bool detect_tones() {
    if (!reading_queue_range(start_point, range, window_cut)) {
        serial_write_string("Errore lettura campioni da coda\n");
        return false;
    }

    sync_ausp(window_cut);
    return true;
}
/**
 * @brief Funzione is_channel_free.
 * @return Valore di ritorno.
 */

bool is_channel_free() {
    if (!detect_tones()) {
        return false;
    }
    for (int i = 0; i < 10; i++) {
        if (active_freq_flags[i]) {
            return false;
        }
    }
    return true;
}

#ifdef __cplusplus
}
#endif
