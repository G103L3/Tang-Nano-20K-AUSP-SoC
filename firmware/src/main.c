#include "../include/periphs.h"

#define CLK_HZ   27000000UL
#define BAUD     115200

static void delay_cycles(volatile uint32_t n) {
    while (n--) {}
}

int main(void) {
    uartext_init(CLK_HZ, BAUD, UARTEXT_CFG_PARITY_NONE | UARTEXT_CFG_BITS(8));
    uartext_puts("PicoRV32 online\r\n");

    pwm10_start(1023, 512);
    uartext_puts("PWM10 avviato (50%)\r\n");

    pwm4_start(15, 8);
    uartext_puts("PWM4 avviato\r\n");

    uint32_t count = 0;
    while (1) {
        gpio_set(1);
        delay_cycles(CLK_HZ / 4);

        gpio_set(0);
        delay_cycles(CLK_HZ / 4);

        count++;

        uartext_puts("tick ");
        char buf[12];
        int i = 10;
        buf[11] = '\0';
        buf[10] = '\r';
        uint32_t v = count;
        do {
            buf[--i] = '0' + (v % 10);
            v /= 10;
        } while (v && i > 0);
        uartext_puts(buf + i);
        uartext_putchar('\n');

        int c = uartext_getchar_nb();
        if (c == 'p') {
            uartext_puts("PWM10 stop\r\n");
            pwm10_stop();
        } else if (c == 'r') {
            uartext_puts("PWM10 restart\r\n");
            pwm10_start(1023, 512);
        }
    }

    return 0;
}
