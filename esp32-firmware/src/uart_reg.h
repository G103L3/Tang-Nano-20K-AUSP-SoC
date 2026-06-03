#ifndef UART_REG_DRIVER_H
#define UART_REG_DRIVER_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define UART_REG_FLASH 1
#define UART_REG_FPGA  2

void     uart_reg_init(int uart_num, int rx_pin, int tx_pin, uint32_t baud);
int      uart_reg_available(int uart_num);
int      uart_reg_read(int uart_num);
int      uart_reg_read_bytes(int uart_num, uint8_t *buf, int n, uint32_t timeout_us);
void     uart_reg_write_byte(int uart_num, uint8_t b);
void     uart_reg_write(int uart_num, const uint8_t *buf, int n);
void     uart_reg_flush_rx(int uart_num);

void     hw_timer_init(void);
uint64_t hw_timer_us(void);

#ifdef __cplusplus
}
#endif

#endif
