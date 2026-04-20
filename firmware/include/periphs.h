#pragma once
#include <stdint.h>

// ============================================================
// Mappa periferiche di sistema
// ============================================================
// CPU memory map:
//   0x01000000  DTCM  - data RAM (stack, variabili)
//   0x02000000  ITCM  - istruzioni (firmware caricato via JTAG)
//   0x04000004  UART  - divisore baud rate
//   0x04000008  UART  - dato TX/RX
// WB esterno (attivo per addr[31:28]>0 e bit31=0):
//   0x10000000  S0    - SDRAM
//   0x30000000  S5    - DMA control
//   0x40000000  S1    - SPI Master
//   0x50000000  S2    - PWM 10-bit
//   0x60000000  S3    - PWM 4-bit
//   0x70000000  S4    - GPIO 1-bit
// ============================================================

// --- UART simpleuart (interno al GowinPicoSoC) ---
// INNER_PERIPH_BASE = 0x04000000
#define UART_DIV_REG    (*(volatile uint32_t*)0x04000004)
#define UART_DATA_REG   (*(volatile uint32_t*)0x04000008)
// Scrittura UART_DATA_REG = trasmetti byte
// Lettura  UART_DATA_REG: bit[8]=0 → dato valido in bit[7:0]; bit[8]=1 → nessun dato

static inline void uart_init(uint32_t clk_hz, uint32_t baud) {
    UART_DIV_REG = clk_hz / baud;
}
static inline void uart_putchar(char c) {
    // aspetta TX pronto (bit8=0 = TX buffer libero)
    while (UART_DATA_REG & (1u << 8)) {}
    UART_DATA_REG = (uint8_t)c;
}
static inline int uart_getchar_nb(void) {
    uint32_t v = UART_DATA_REG;
    return (v & (1u << 8)) ? -1 : (int)(v & 0xFF);
}
static inline char uart_getchar(void) {
    int c;
    do { c = uart_getchar_nb(); } while (c < 0);
    return (char)c;
}
static inline void uart_puts(const char *s) {
    while (*s) uart_putchar(*s++);
}

// --- SPI Master (0x40000000) ---
// 0x00 RD: 32-bit dato MISO (ack solo se data_ready=1)
// 0x01 WR: avvia lettura SPI (start)
// 0x02 WR: ferma lettura SPI (stop)
// 0x03 WR: azzera data_ready flag
#define SPI_BASE        0x40000000u
#define SPI_DATA        (*(volatile uint32_t*)(SPI_BASE + 0x00))
#define SPI_START       (*(volatile uint32_t*)(SPI_BASE + 0x01))
#define SPI_STOP        (*(volatile uint32_t*)(SPI_BASE + 0x02))
#define SPI_CLR_READY   (*(volatile uint32_t*)(SPI_BASE + 0x03))

static inline uint32_t spi_read32(void) {
    SPI_START = 1;
    // aspetta data_ready (il WB rimane in stall finché non c'è dato)
    uint32_t d = SPI_DATA;
    SPI_STOP = 1;
    SPI_CLR_READY = 1;
    return d;
}

// --- PWM 10-bit (0x50000000) ---
// adr=0x01 WR: dat[19:10]=duty, dat[9:0]=period → avvia
// adr=0x02 WR: ferma (start deve essere =0 prima di riconfigurare)
#define PWM10_BASE      0x50000000u
#define PWM10_START_REG (*(volatile uint32_t*)(PWM10_BASE + 0x01))
#define PWM10_STOP_REG  (*(volatile uint32_t*)(PWM10_BASE + 0x02))

static inline void pwm10_start(uint16_t period_10b, uint16_t duty_10b) {
    PWM10_STOP_REG  = 1;
    PWM10_START_REG = ((uint32_t)(duty_10b & 0x3FF) << 10) | (period_10b & 0x3FF);
}
static inline void pwm10_stop(void) { PWM10_STOP_REG = 1; }

// --- PWM 4-bit (0x60000000) ---
// adr=0x01 WR: dat[7:4]=duty, dat[3:0]=period → avvia
// adr=0x02 WR: ferma
#define PWM4_BASE       0x60000000u
#define PWM4_START_REG  (*(volatile uint32_t*)(PWM4_BASE + 0x01))
#define PWM4_STOP_REG   (*(volatile uint32_t*)(PWM4_BASE + 0x02))

static inline void pwm4_start(uint8_t period_4b, uint8_t duty_4b) {
    PWM4_STOP_REG  = 1;
    PWM4_START_REG = ((uint32_t)(duty_4b & 0xF) << 4) | (period_4b & 0xF);
}
static inline void pwm4_stop(void) { PWM4_STOP_REG = 1; }

// --- GPIO 1-bit (0x70000000) ---
// WR: dat[0] = gpio_1_o
// RD: dat[0] = gpio_in (attualmente fissato a 0 nel top)
#define GPIO_BASE       0x70000000u
#define GPIO_REG        (*(volatile uint32_t*)(GPIO_BASE))

static inline void gpio_set(uint32_t val) { GPIO_REG = val & 1u; }

// --- DMA SPI→SDRAM (0x30000000) ---
// +0x01 WR: start   — avvia acquisizione continua SPI→SDRAM
// +0x02 WR: stop    — ferma acquisizione
// +0x03 WR: base    — imposta indirizzo base SDRAM (bit[20:0] = word address 21-bit)
// IRQ ogni 512 parole SDRAM scritte (256 letture SPI da 32-bit → 2×16-bit);
// dopo 1024 parole il DMA torna automaticamente a base.
#define DMA_BASE        0x30000000u
#define DMA_START       (*(volatile uint32_t*)(DMA_BASE + 0x01))
#define DMA_STOP        (*(volatile uint32_t*)(DMA_BASE + 0x02))
#define DMA_SETBASE     (*(volatile uint32_t*)(DMA_BASE + 0x03))

// --- SDRAM (0x10000000) - dopo fix VHDL in wb_interconnect ---
#define SDRAM_BASE      ((volatile uint32_t*)0x10000000u)
