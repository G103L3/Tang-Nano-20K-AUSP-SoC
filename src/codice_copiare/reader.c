/*! \file reader.c
 * \author Gioele Giunta
 * \version 2.1
 * \since 2025
 * \brief Implementazione del modulo reader
 */

/* Librerie */
#include <string.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <driver/adc.h>
#include <esp_system.h>
#include <esp_log.h>

/* Headers specifici */
#include "reader.h"

 #ifdef __cplusplus
 extern "C" {
 #endif
 
 
 /* Buffer declarations */
 static complex_g3_t main_array[ARRAY_ELEMENTS];
 static complex_g3_t secondary_array[ARRAY_ELEMENTS];
 static complex_g3_t *current_data;
 
 complex_g3_t *array_ready;
 volatile int data_ready = 0;
 volatile int status_flag = 1;
 static int counter = 0;
 
 /* Task handle */
 static TaskHandle_t reader_task_handle = NULL;
 
 static const char *TAG = "reader";
/**
 * @brief Funzione swap_array.
 * @return Valore di ritorno.
 */
 
 static void swap_array(void) {
     array_ready = current_data;
     current_data = (current_data == main_array) ? secondary_array : main_array;
 }
/**
 * @brief Funzione reader_task.
 * @param param Parametro param.
 * @return Valore di ritorno.
 */
 
 static void reader_task(void *param) {
    size_t bytes_read;
    int32_t dma_buffer[DMA_BUFFER_SIZE / 4]; /* 4 bytes per sample (24-bit left-justified) */

    /* DC estimator */
    static float dc_mean = 0.0f;
    const float alpha = 1.0f / 1024.0f; /* time constant ~1024 samples */
 
     while (1) {
        i2s_read(I2S_PORT, (void*)dma_buffer, DMA_BUFFER_SIZE, &bytes_read, portMAX_DELAY);
        int samples = bytes_read / 4;

        for (int i = 0; i < samples; i++) {
            int32_t s32 = dma_buffer[i] >> 8; /* convert from 32-bit aligned to 24-bit sample */
            float x = (float)(s32 >> 12);      /* scale to approx 12-bit range */

            /* DC estimation */
            dc_mean += alpha * (x - dc_mean);

            float val = x - dc_mean;  /* centered sample */

            current_data[counter].re = (double)val;
            current_data[counter].im = 0.0;
            counter++;

            if (counter >= ARRAY_ELEMENTS) {
                data_ready = 1;
                swap_array();
                counter = 0;
            }
        }
    }
}
/**
 * @brief Funzione reader_init.
 */
 

void reader_init(void) {
    serial_init(115200);

    /* --------------------------- */
    /* I2S configuration for INMP441 microphone */
    /* --------------------------- */
    i2s_config_t i2s_config = {
        .mode = I2S_MODE_MASTER | I2S_MODE_RX,
        .sample_rate = SAMPLE_RATE, /* 48000 Hz */
        .bits_per_sample = I2S_BITS_PER_SAMPLE_32BIT,
        .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
        .communication_format = I2S_COMM_FORMAT_STAND_I2S,
        .intr_alloc_flags = 0,
        .dma_buf_count = DMA_BUFFERS,
        .dma_buf_len = DMA_BUFFER_SIZE / 4,
        .use_apll = false,
        .tx_desc_auto_clear = true,
    };

    i2s_driver_install(I2S_PORT, &i2s_config, 0, NULL);

    i2s_pin_config_t pin_config = {
        .bck_io_num = I2S_MIC_BCK_PIN,
        .ws_io_num = I2S_MIC_WS_PIN,
        .data_out_num = I2S_PIN_NO_CHANGE,
        .data_in_num = I2S_MIC_SD_PIN
    };
    i2s_set_pin(I2S_PORT, &pin_config);

    /* Explicit clock configuration */
    i2s_set_clk(I2S_PORT, SAMPLE_RATE, I2S_BITS_PER_SAMPLE_32BIT, I2S_CHANNEL_MONO);

    /* Warm-up: discard a few buffers */
    {
        size_t br;
        int32_t dumpbuf[DMA_BUFFER_SIZE / 4];
        for (int k = 0; k < 5; k++) {
            i2s_read(I2S_PORT, (void*)dumpbuf, DMA_BUFFER_SIZE, &br, portMAX_DELAY);
        }
    }

    /* --------------------------- */
    /* Prepare structures and task */
    /* --------------------------- */
    current_data = main_array;
    array_ready = NULL;
    data_ready = 0;
    counter = 0;
 
    xTaskCreate(reader_task, "reader_task", 4096, NULL, 5, &reader_task_handle);
 
    ESP_LOGI(TAG, "reader_init complete (SR=%d Hz, I2S microphone)", SAMPLE_RATE);
}
 
 #ifdef __cplusplus
 }
 #endif
 
