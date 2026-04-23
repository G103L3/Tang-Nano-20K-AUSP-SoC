#include <string.h>
#include <stdint.h>
#include "../include/periphs.h"
#include "global_parameters.h"
#include "complex_g3.h"
#include "decoder.h"
#include "bit_freq_codec.h"
#include "bit_input_packer.h"
#include "bit_output_packer.h"
#include "char_packet_router.h"

#define CLK_HZ           27000000UL
#define BAUD             115200UL
#define FFT_RESULT_BASE  ((volatile uint32_t *)0x10004C00u)

static volatile uint32_t fft_ready = 0;

void __attribute__((interrupt("machine"))) irq_handler(void) {
    fft_ready = 1;
}

void uart_tx_string(const char *s) { uartext_puts(s); }
void uart_tx_char(char c)          { uartext_putchar(c); }

static void delay_cycles(uint32_t n) {
    uint32_t start, cur;
    asm volatile("rdcycle %0" : "=r"(start));
    do { asm volatile("rdcycle %0" : "=r"(cur)); } while ((cur - start) < n);
}

static uint8_t sc_to_pwm4_duty(int sc) {
    if (sc < 0)              return 0;
    if (sc <= 8)             return (uint8_t)sc;
    if (sc >= 10 && sc <= 18) return (uint8_t)(7 + (sc - 10));
    return 0;
}

static void pwm10_play_tone_hz(uint32_t freq_hz) {
    if (freq_hz == 0) { pwm10_stop(); return; }
    uint32_t period = CLK_HZ / freq_hz;
    if (period > 1023) period = 1023;
    if (period < 1)    period = 1;
    pwm10_start((uint16_t)period, (uint16_t)(period / 2));
}

static void process_fft_data(void) {
    static complex_g3_t bins[G_ARRAY_SIZE];

    for (int i = 0; i < G_ARRAY_SIZE; i++) {
        bins[i].re = (double)(int16_t)(FFT_RESULT_BASE[i] & 0xFFFFu);
        bins[i].im = 0.0;
    }

    struct_tone_frequencies freqs = decode_ausp(bins);
    struct_tone_bits        tbits = bit_coder(freqs);

    uint8_t duty = sc_to_pwm4_duty(tbits.master);
    pwm4_start(15, duty);

    process_tone_bits(tbits);

    char buffer[ASCII_PACKET_SIZE];

    if (master_ascii_ready) {
        size_t idx = 0;
        for (size_t i = 0; i < ASCII_NUM_ARRAYS; i++)
            for (size_t j = 0; j < ASCII_ARRAY_SIZE && master_ascii_arrays[i][j]; j++)
                buffer[idx++] = master_ascii_arrays[i][j];
        buffer[idx] = '\0';
        char_packet_router_route(CHANNEL_MASTER, buffer);
        master_ascii_ready = false;
    }

    if (slave_ascii_ready) {
        size_t idx = 0;
        for (size_t i = 0; i < ASCII_NUM_ARRAYS; i++)
            for (size_t j = 0; j < ASCII_ARRAY_SIZE && slave_ascii_arrays[i][j]; j++)
                buffer[idx++] = slave_ascii_arrays[i][j];
        buffer[idx] = '\0';
        char_packet_router_route(CHANNEL_SLAVE, buffer);
        slave_ascii_ready = false;
    }

    if (config_ascii_ready) {
        size_t idx = 0;
        for (size_t i = 0; i < ASCII_NUM_ARRAYS; i++)
            for (size_t j = 0; j < ASCII_ARRAY_SIZE && config_ascii_arrays[i][j]; j++)
                buffer[idx++] = config_ascii_arrays[i][j];
        buffer[idx] = '\0';
        char_packet_router_route(CHANNEL_CONFIG, buffer);
        config_ascii_ready = false;
    }
}

static void transmit_via_pwm10(const char *text) {
    BitOutputPacker packer;
    bit_output_packer_init(&packer);

    if (!bit_output_packer_compress(&packer, text)) {
        bit_output_packer_free(&packer);
        return;
    }
    if (!bit_output_packer_convert(&packer, 0)) {
        bit_output_packer_free(&packer);
        return;
    }

    for (size_t i = 0; i < packer.pair_count; i++) {
        int t0 = packer.pairs[i].tones[0];
        int t1 = packer.pairs[i].tones[1];
        if (t0 == 0 && t1 == 0) {
            pwm10_stop();
            delay_cycles((CLK_HZ / 1000) * 80);
        } else {
            pwm10_play_tone_hz((uint32_t)(t0 > 0 ? t0 : 0));
            delay_cycles((CLK_HZ / 1000) * 24);
            pwm10_play_tone_hz((uint32_t)(t1 > 0 ? t1 : 0));
            delay_cycles((CLK_HZ / 1000) * 24);
        }
    }

    pwm10_stop();
    bit_output_packer_free(&packer);
}

static void handle_uart_rx(void) {
    static char   rx_buf[256];
    static size_t rx_len = 0;

    int c = uartext_getchar_nb();
    if (c < 0) return;

    if ((char)c == '\n') {
        if (rx_len > 0) {
            rx_buf[rx_len] = '\0';
            transmit_via_pwm10(rx_buf);
            rx_len = 0;
        }
    } else if ((char)c == '\r') {
        ;
    } else if (rx_len < 255) {
        rx_buf[rx_len++] = (char)c;
    }
}

int main(void) {
    gpio_set(1);

    uartext_init(CLK_HZ, BAUD, UARTEXT_CFG_PARITY_NONE | UARTEXT_CFG_BITS(8));

    char_packet_router_init();

    DMA_SETBASE = 0;
    DMA_START   = 1;

    while (1) {
        if (fft_ready) {
            fft_ready = 0;
            process_fft_data();
        }
        handle_uart_rx();
    }

    return 0;
}
