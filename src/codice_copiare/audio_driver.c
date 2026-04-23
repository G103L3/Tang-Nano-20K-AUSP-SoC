/*! \file audio_driver.c
 * \author Gioele Giunta
 * \version 3.2
 * \since 2025
 * \brief Implementazione del modulo audio driver
 */

/* Librerie */
#include <math.h>
#include <string.h>

/* Headers specifici */
#include "audio_driver.h"

#ifdef __cplusplus
extern "C" {
#endif




/**
 * @brief Initializes the I2S peripheral for audio playback.
 *
 * Here I configure the ESP32's I2S driver to operate in master transmit mode.
 * The sample rate is set to 44100 Hz, data width to 16-bit, and communication format to standard I2S MSB.
 * Pin numbers for BCLK, WS, and DATA are set according to my hardware setup.
 * DMA buffer configuration is also defined to manage audio stream transfer.
 */
/**
 * @brief Funzione audio_init.
 */
void audio_init() {
    i2s_config_t i2s_config = {
        .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX),
        .sample_rate = G_SAMPLE_RATE,
        .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
        .channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT,  /* stereo mode */
        .communication_format = I2S_COMM_FORMAT_I2S_MSB,
        .intr_alloc_flags = 0,
        .dma_buf_count = 8,
        .dma_buf_len = 64,
        .use_apll = false,
        .tx_desc_auto_clear = true,
        .fixed_mclk = 0
    };

    i2s_pin_config_t pin_config = {
        .bck_io_num = I2S_BCK_PIN,
        .ws_io_num = I2S_WS_PIN,
        .data_out_num = I2S_DATA_PIN,
        .data_in_num = I2S_PIN_NO_CHANGE
    };

    i2s_driver_install(I2S_NUM, &i2s_config, 0, NULL);
    i2s_set_pin(I2S_NUM, &pin_config);
}
/**
 * @brief Funzione play_two_tones.
 * @param freq1 Parametro freq1.
 * @param freq2 Parametro freq2.
 */



void play_two_tones(int freq1, int freq2) {
    if(freq1 == 0 && freq2 == 0){
        delay(80);
    }else{
    const float tone_duration = 0.024f;
    const int tone_samples = (int)(G_SAMPLE_RATE * tone_duration);
    /*printf("Debug: Tone samples: %d\n", tone_samples); */
    const int tone_buffer_size = tone_samples * 2;  /* Stereo */

    int16_t tone_buffer[tone_buffer_size];

    static float phase1 = 0.0f;
    static float phase2 = 0.0f;
    const float inc1 = 2.0f * PI * freq1 / G_SAMPLE_RATE;
    const float inc2 = 2.0f * PI * freq2 / G_SAMPLE_RATE;


    for (int i = 0; i < tone_samples; i++) {
        float mixed = sinf(phase1) + sinf(phase2);

        /* Normalizza per evitare saturazione (somma max: 2.0) */
        int16_t sample = (int16_t)(3000 * (mixed / 2.0f));

        tone_buffer[2 * i] = sample;       /* Left */
        tone_buffer[2 * i + 1] = sample;   /* Right */

        phase1 += inc1;
        if (phase1 >= 2.0f * PI) phase1 -= 2.0f * PI;
        phase2 += inc2;
        if (phase2 >= 2.0f * PI) phase2 -= 2.0f * PI;
    }

    size_t bytes_written = 0;
    i2s_write(I2S_NUM, tone_buffer, sizeof(tone_buffer), &bytes_written, portMAX_DELAY);
    }


}

/*Linear Regression Configuration purpose */
/**
 * @brief Funzione play_nine_tones.
 * @param freqs[9] Parametro freqs[9].
 */
void play_nine_tones(const int freqs[9]) {
    const float tone_duration = 0.03f; /* ~30ms */
    const int tone_samples = (int)(G_SAMPLE_RATE * tone_duration);
    printf("Debug: Tone samples: %d\n", tone_samples);

    const int tone_buffer_size = tone_samples * 2;  /* Stereo: L,R */
    int16_t tone_buffer[tone_buffer_size];

    /* Fasi persistenti per ogni oscillatore */
    static float phases[9] = {0};

    float inc[9];
    unsigned char active_mask[9];
    int num_active = 0;

    /* Prepara gli incrementi e conta i toni attivi */
    for (int k = 0; k < 9; ++k) {
        if (freqs[k] > 0) {
            inc[k] = 2.0f * (float)PI * (float)freqs[k] / (float)G_SAMPLE_RATE;
            active_mask[k] = 1;
            ++num_active;
        } else {
            inc[k] = 0.0f;
            active_mask[k] = 0;
        }
    }

    /* Se nessuna frequenza è valida, esci silenziosamente */
    if (num_active == 0) {
        return;
    }

    /* Mix e normalizzazione (headroom con fattore 3000 come nel tuo codice) */
    for (int i = 0; i < tone_samples; ++i) {
        float mixed = 0.0f;

        /* Somma dei sinusoidi */
        for (int k = 0; k < 9; ++k) {
            if (!active_mask[k]) continue;
            mixed += sinf(phases[k]);

            phases[k] += inc[k];
            if (phases[k] >= 2.0f * (float)PI) phases[k] -= 2.0f * (float)PI;
            /* opzionale: if (phases[k] < 0.0f) phases[k] += 2.0f * (float)PI; */
        }

        /* Normalizza per il numero di toni attivi per evitare saturazione */
        /* (somma max teorica ~ num_active) */
        float normalized = mixed / (float)num_active;

        /* Headroom: 3000 come nel tuo esempio (sotto a 32767) */
        int16_t sample = (int16_t)(3000.0f * normalized);

        tone_buffer[2 * i]     = sample; /* Left */
        tone_buffer[2 * i + 1] = sample; /* Right */
    }

    size_t bytes_written = 0;
    i2s_write(I2S_NUM, tone_buffer, sizeof(tone_buffer), &bytes_written, portMAX_DELAY);
}

#ifdef __cplusplus
}
#endif
