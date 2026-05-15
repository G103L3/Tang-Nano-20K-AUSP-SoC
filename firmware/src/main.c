#include <stdint.h>
#include "../include/periphs.h"

#define CLK_HZ  27000000UL
#define BAUD    115200UL

static void delay_ms(uint32_t ms) {
    volatile uint32_t i;
    while (ms--) for (i = 0; i < 9000u; i++) {}
}

void __attribute__((interrupt("machine"))) irq_handler(void) {}

int main(void) {
    uartext_init(CLK_HZ, BAUD, UARTEXT_CFG_PARITY_NONE | UARTEXT_CFG_BITS(8));
    uartext_puts("\r\n[BOOT] ok\r\n");

    gpio_set(1);  /* transistor ON: circuito LED attivo */

    while (1) {
        pwm4_start(15, 15);  /* LED acceso */
        delay_ms(500);
        pwm4_stop();         /* LED spento */
        delay_ms(500);
    }
}
