#pragma once
#include <stdint.h>

// ============================================================
// Mappa periferiche di sistema
// ============================================================
// CPU memory map:
//   0x01000000  DTCM  - data RAM (stack, variabili)
//   0x02000000  ITCM  - istruzioni (firmware caricato via JTAG)
// WB esterno (attivo per addr[31:28]>0 e bit31=0):
//   0x10000000  S0    - SDRAM
//   0x20000000  S6    - UART_GENERIC esterno
//   0x30000000  S5    - DMA control
//   0x40000000  S1    - SPI Master
//   0x50000000  S2    - PWM 10-bit
//   0x60000000  S3    - PWM 4-bit
//   0x70000000  S4    - GPIO 1-bit
// ============================================================

// --- UART_GENERIC esterno (0x20000000) ---
// +0x00 RD: bit[8]=rx_valid, bit[7:0]=dato RX (lettura azzera rx_valid)
// +0x00 WR: trasmetti byte (ignorato se tx_busy=1 o enabled=0)
// +0x01 WR: abilita UART (start)
// +0x02 WR: disabilita UART (stop)
// +0x03 WR: dat[15:0] = baud_div = clk_hz / baud_rate  (default 234 = 27MHz/115200)
// +0x04 WR: dat[1:0]=parity(00=none,01=even,10=odd), dat[2]=stop_bits(0=1,1=2),
//           dat[6:3]=data_bits-5 (0=5bit … 3=8bit … 4=9bit)
// +0x05 RD: dat[1]=rx_valid, dat[0]=tx_busy
#define UARTEXT_BASE        0x20000000u
#define UARTEXT_DATA        (*(volatile uint32_t*)(UARTEXT_BASE + 0x00))
#define UARTEXT_START       (*(volatile uint32_t*)(UARTEXT_BASE + 0x01))
#define UARTEXT_STOP        (*(volatile uint32_t*)(UARTEXT_BASE + 0x02))
#define UARTEXT_DIV         (*(volatile uint32_t*)(UARTEXT_BASE + 0x03))
#define UARTEXT_CFG         (*(volatile uint32_t*)(UARTEXT_BASE + 0x04))
#define UARTEXT_STATUS      (*(volatile uint32_t*)(UARTEXT_BASE + 0x05))

#define UARTEXT_CFG_PARITY_NONE  0x00u
#define UARTEXT_CFG_PARITY_EVEN  0x01u
#define UARTEXT_CFG_PARITY_ODD   0x02u
#define UARTEXT_CFG_STOP2        0x04u
#define UARTEXT_CFG_BITS(n)      (((uint32_t)((n)-5) & 0xFu) << 3)

static inline void uartext_init(uint32_t clk_hz, uint32_t baud, uint32_t cfg) {
    UARTEXT_STOP  = 1;
    UARTEXT_DIV   = clk_hz / baud;
    UARTEXT_CFG   = cfg;
    UARTEXT_START = 1;
}
static inline void uartext_putchar(char c) {
    while (UARTEXT_STATUS & 0x1u) {}
    UARTEXT_DATA = (uint8_t)c;
}
static inline int uartext_getchar_nb(void) {
    uint32_t d = UARTEXT_DATA;
    return (d & (1u << 8)) ? (int)(d & 0xFF) : -1;
}
static inline void uartext_puts(const char *s) {
    while (*s) uartext_putchar(*s++);
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

// --- SDRAM (0x10000000) 
#define SDRAM_BASE      ((volatile uint32_t*)0x10000000u)
