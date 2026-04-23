/*! \file reader_test.c
 * \author Gioele Giunta
 * \version 2.5
 * \since 2025
 * \brief Implementazione del modulo reader test
 */

/* Librerie */
#include <string.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <esp_adc_cal.h>

/* Headers specifici */
#include "reader_test.h"

 #ifdef __cplusplus
 extern "C" {
 #endif
 
 
 /* Task handle */
 static TaskHandle_t reader_test_task_handle = NULL;
 static double bias = 0.0;
/**
 * @brief Funzione reader_test_task.
 * @param param Parametro param.
 * @return Valore di ritorno.
 */
 
 static void reader_test_task(void *param) {
    size_t bytes_read;
    uint16_t dma_buffer[1024]; /* 1024 campioni = 2048 bytes */

    /* Una sola lettura: 1024 campioni (2048 bytes) */
    i2s_read(I2S_PORT, (void*)dma_buffer, 2048, &bytes_read, portMAX_DELAY);

    int samples = bytes_read / 2;
    for (int i = 0; i < samples; i++) {
        double val = ((double)dma_buffer[i] - bias) * 2.0;

        complex_g3_t sample;
        sample.re = val;
        sample.im = 0.0;
        reading_queue_enqueue(&sample);
    }

    serial_write_formatted("Test completato: %d campioni acquisiti.\n", samples);

    i2s_adc_disable(I2S_PORT);
    vTaskDelete(NULL);
}
/**
 * @brief Funzione reader_test_init.
 */
 
 void reader_test_init(void) {
     serial_init(115200);
 
     /* ADC calibration */
     uint32_t sum = 0;
     for (int i = 0; i < 1024; i++) {
         sum += adc1_get_raw(AUDIO_PIN);
         ets_delay_us(10);
     }
     bias = sum / 1024.0;
 
     esp_adc_cal_characteristics_t adc_chars;
     esp_adc_cal_characterize(ADC_UNIT_1, ADC_ATTEN_DB_11, ADC_WIDTH_BIT_12, 1100, &adc_chars);
 
     /* I2S configuration */
     i2s_config_t i2s_config = {
         .mode = I2S_MODE_MASTER | I2S_MODE_RX | I2S_MODE_ADC_BUILT_IN,
         .sample_rate = SAMPLE_RATE,
         .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
         .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
         .communication_format = I2S_COMM_FORMAT_STAND_I2S,
         .intr_alloc_flags = 0,
         .dma_buf_count = DMA_BUFFERS,
         .dma_buf_len = DMA_BUFFER_SIZE / 2,
         .use_apll = false,
         .tx_desc_auto_clear = true,
     };
 
     i2s_driver_install(I2S_PORT, &i2s_config, 0, NULL);
     i2s_set_adc_mode(ADC_UNIT_1, AUDIO_PIN);
 
     /* Enable ADC in I2S mode */
     i2s_adc_enable(I2S_PORT);
 
     /* Launch test reader task */
     xTaskCreate(reader_test_task, "reader_test_task", 4096, NULL, 5, &reader_test_task_handle);
 }
 
 #ifdef __cplusplus
 }
 #endif
 
