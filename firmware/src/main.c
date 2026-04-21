#include "../include/periphs.h"

#define CLK_HZ   27000000UL
#define BAUD     115200

// FFT results: 512 bins of xk_re at SDRAM word address 0x1300
// Byte address: 0x10000000 + 0x1300*4 = 0x10004C00
#define FFT_RESULT_BASE  ((volatile uint32_t*)0x10004C00u)
#define FFT_BINS         512

// DMA/FFT done flag set by IRQ handler
static volatile uint32_t fft_ready = 0;

// PicoRV32 IRQ handler – placed at the interrupt vector (0x00000010 by linker).
// IRQ bit 20 = DMA/FFT done.
// The gowin_picorv32_top routes irq_in[20] to PicoRV32 irq[20].
// PicoRV32 saves return address to x3 and jumps here.
void __attribute__((interrupt, section(".irq"))) irq_handler(void)
{
    // bit 20: DMA FFT-done IRQ
    fft_ready = 1;
}

static void delay_cycles(volatile uint32_t n) {
    while (n--) {}
}

// Print a decimal uint32
static void print_u32(uint32_t v) {
    char buf[12];
    int i = 11;
    buf[11] = '\0';
    if (v == 0) { uartext_putchar('0'); return; }
    while (v && i > 0) { buf[--i] = '0' + (v % 10); v /= 10; }
    uartext_puts(buf + i);
}

int main(void) {
    uartext_init(CLK_HZ, BAUD, UARTEXT_CFG_PARITY_NONE | UARTEXT_CFG_BITS(8));
    uartext_puts("PicoRV32 online\r\n");

    // Configure DMA: base SDRAM address = 0 (word address), then start.
    // The DMA will auto-start the SPI and sample at ~46.875 kHz.
    // Every 512 samples the FFT fires; IRQ 20 fires when results are ready
    // at SDRAM word address 0x1300 (FFT_RESULT_BASE).
    DMA_SETBASE = 0;
    DMA_START   = 1;
    uartext_puts("DMA+FFT avviato\r\n");

    uint32_t fft_count = 0;

    while (1) {
        // Poll fft_ready (set by IRQ handler or spin-wait if IRQs not wired)
        if (fft_ready) {
            fft_ready = 0;
            fft_count++;

            uartext_puts("FFT #");
            print_u32(fft_count);
            uartext_puts(": bin[0]=");
            // Read DC component (bin 0, real part)
            print_u32(FFT_RESULT_BASE[0] & 0xFFFFu);
            uartext_puts(" bin[1]=");
            print_u32(FFT_RESULT_BASE[1] & 0xFFFFu);
            uartext_puts("\r\n");
        }

        // Toggle GPIO to show liveness
        gpio_set(fft_count & 1u);

        delay_cycles(CLK_HZ / 100);
    }

    return 0;
}
