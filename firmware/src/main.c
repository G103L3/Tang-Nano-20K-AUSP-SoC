#include "../include/periphs.h"

// Clock: 27 MHz
#define CLK_HZ   27000000UL
#define BAUD     115200

static void delay_cycles(volatile uint32_t n) {
    while (n--) {}
}

int main(void) {
    // Inizializzazione UART
    uart_init(CLK_HZ, BAUD);
    uart_puts("PicoRV32 online\r\n");

    // Configurazione PWM 10-bit
    // period=1023 (max), duty=512 (50%) → segnale al 50%
    pwm10_start(1023, 512);
    uart_puts("PWM10 avviato (50%)\r\n");

    // Configurazione PWM 4-bit
    // period=15 (max), duty=8 (~53%)
    pwm4_start(15, 8);
    uart_puts("PWM4 avviato\r\n");

    uint32_t count = 0;
    //TEST
    while (1) {
        gpio_set(1);
        delay_cycles(CLK_HZ / 4);   // ~250 ms ON

        gpio_set(0);
        delay_cycles(CLK_HZ / 4);   // ~250 ms OFF

        count++;

        // Stampa counter ogni secondo
        uart_puts("tick ");
        // Stampa decimale semplice
        char buf[12];
        int i = 10;
        buf[11] = '\0';
        buf[10] = '\r';
        uint32_t v = count;
        do {
            buf[--i] = '0' + (v % 10);
            v /= 10;
        } while (v && i > 0);
        uart_puts(buf + i);
        uart_putchar('\n');

        // Lettura UART (non bloccante)
        int c = uart_getchar_nb();
        if (c == 'p') {
            uart_puts("PWM10 stop\r\n");
            pwm10_stop();
        } else if (c == 'r') {
            uart_puts("PWM10 restart\r\n");
            pwm10_start(1023, 512);
        }
    }

    return 0;
}
