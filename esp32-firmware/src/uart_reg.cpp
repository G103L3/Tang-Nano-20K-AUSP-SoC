#include "uart_reg.h"

#include <Arduino.h>
#include "soc/uart_reg.h"
#include "soc/dport_reg.h"
#include "soc/gpio_reg.h"
#include "soc/gpio_sig_map.h"
#include "soc/timer_group_reg.h"
#include "esp32/rom/gpio.h"

static bool s_hw_timer_started = false;

static inline uint32_t uart_rx_count(int n) {
    return (READ_PERI_REG(UART_STATUS_REG(n)) >> UART_RXFIFO_CNT_S) & UART_RXFIFO_CNT_V;
}

static inline uint32_t uart_tx_count(int n) {
    return (READ_PERI_REG(UART_STATUS_REG(n)) >> UART_TXFIFO_CNT_S) & UART_TXFIFO_CNT_V;
}

void hw_timer_init(void) {
    if (s_hw_timer_started) return;
    WRITE_PERI_REG(TIMG_T0CONFIG_REG(0), 0);
    WRITE_PERI_REG(TIMG_T0LOADLO_REG(0), 0);
    WRITE_PERI_REG(TIMG_T0LOADHI_REG(0), 0);
    WRITE_PERI_REG(TIMG_T0LOAD_REG(0), 1);
    WRITE_PERI_REG(TIMG_T0CONFIG_REG(0),
        (80u << TIMG_T0_DIVIDER_S) |
        (0u  << TIMG_T0_AUTORELOAD_S) |
        (1u  << TIMG_T0_INCREASE_S) |
        (0u  << TIMG_T0_ALARM_EN_S) |
        TIMG_T0_EN);
    s_hw_timer_started = true;
}

uint64_t hw_timer_us(void) {
    WRITE_PERI_REG(TIMG_T0UPDATE_REG(0), 1);
    uint32_t lo = READ_PERI_REG(TIMG_T0LO_REG(0));
    uint32_t hi = READ_PERI_REG(TIMG_T0HI_REG(0));
    return ((uint64_t)hi << 32) | lo;
}

static void uart_enable_clock(int n) {
    if (n == 0) {
        DPORT_REG_SET_BIT(DPORT_PERIP_CLK_EN_REG, DPORT_UART_CLK_EN);
        DPORT_REG_CLR_BIT(DPORT_PERIP_RST_EN_REG, DPORT_UART_CLK_EN);
    } else if (n == 1) {
        DPORT_REG_SET_BIT(DPORT_PERIP_CLK_EN_REG, DPORT_UART1_CLK_EN);
        DPORT_REG_CLR_BIT(DPORT_PERIP_RST_EN_REG, DPORT_UART1_CLK_EN);
    } else {
        DPORT_REG_SET_BIT(DPORT_PERIP_CLK_EN_REG, DPORT_UART2_CLK_EN);
        DPORT_REG_CLR_BIT(DPORT_PERIP_RST_EN_REG, DPORT_UART2_CLK_EN);
    }
}

static int uart_tx_signal(int n) {
    if (n == 0) return U0TXD_OUT_IDX;
    if (n == 1) return U1TXD_OUT_IDX;
    return U2TXD_OUT_IDX;
}

static int uart_rx_signal(int n) {
    if (n == 0) return U0RXD_IN_IDX;
    if (n == 1) return U1RXD_IN_IDX;
    return U2RXD_IN_IDX;
}

void uart_reg_init(int uart_num, int rx_pin, int tx_pin, uint32_t baud) {
    hw_timer_init();
    uart_enable_clock(uart_num);

    uint32_t clk = 80000000u;
    uint32_t integer = clk / baud;
    uint32_t frac = (clk * 16u / baud) & 0xFu;
    WRITE_PERI_REG(UART_CLKDIV_REG(uart_num), integer | (frac << UART_CLKDIV_FRAG_S));

    WRITE_PERI_REG(UART_CONF0_REG(uart_num),
        (3u << UART_BIT_NUM_S) |
        (1u << UART_STOP_BIT_NUM_S) |
        UART_TICK_REF_ALWAYS_ON);

    SET_PERI_REG_MASK(UART_CONF0_REG(uart_num), UART_RXFIFO_RST | UART_TXFIFO_RST);
    CLEAR_PERI_REG_MASK(UART_CONF0_REG(uart_num), UART_RXFIFO_RST | UART_TXFIFO_RST);

    WRITE_PERI_REG(UART_CONF1_REG(uart_num),
        (1u  << UART_RXFIFO_FULL_THRHD_S) |
        (1u  << UART_TXFIFO_EMPTY_THRHD_S));

    WRITE_PERI_REG(UART_INT_CLR_REG(uart_num), 0xFFFFFFFFu);

    pinMode(tx_pin, OUTPUT);
    gpio_matrix_out(tx_pin, uart_tx_signal(uart_num), false, false);

    pinMode(rx_pin, INPUT);
    gpio_matrix_in(rx_pin, uart_rx_signal(uart_num), false);
}

int uart_reg_available(int uart_num) {
    return (int)uart_rx_count(uart_num);
}

int uart_reg_read(int uart_num) {
    if (uart_rx_count(uart_num) == 0) return -1;
    return (int)(READ_PERI_REG(UART_FIFO_REG(uart_num)) & 0xFFu);
}

int uart_reg_read_bytes(int uart_num, uint8_t *buf, int n, uint32_t timeout_us) {
    int got = 0;
    uint64_t t0 = hw_timer_us();
    while (got < n) {
        if (uart_rx_count(uart_num) > 0) {
            buf[got++] = (uint8_t)(READ_PERI_REG(UART_FIFO_REG(uart_num)) & 0xFFu);
            t0 = hw_timer_us();
        } else if ((hw_timer_us() - t0) > (uint64_t)timeout_us) {
            break;
        }
    }
    return got;
}

void uart_reg_write_byte(int uart_num, uint8_t b) {
    while (uart_tx_count(uart_num) >= 127u) { }
    WRITE_PERI_REG(UART_FIFO_REG(uart_num), (uint32_t)b);
}

void uart_reg_write(int uart_num, const uint8_t *buf, int n) {
    for (int i = 0; i < n; i++) {
        while (uart_tx_count(uart_num) >= 127u) { }
        WRITE_PERI_REG(UART_FIFO_REG(uart_num), (uint32_t)buf[i]);
    }
}

void uart_reg_flush_rx(int uart_num) {
    while (uart_rx_count(uart_num) > 0) {
        (void)READ_PERI_REG(UART_FIFO_REG(uart_num));
    }
}
