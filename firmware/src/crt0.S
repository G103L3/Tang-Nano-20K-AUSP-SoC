// Startup code per PicoRV32 (Gowin GowinPicoSoC)
//
// Layout ITCM (0x02000000):
//   +0x00  reset vector  → salta a _reset
//   +0x10  IRQ vector    → PROGADDR_IRQ = 0x02000010
//   ...
//   _reset: setup stack, zero BSS, copia .data, chiama main

.section .text.reset, "ax"
.global _start
.global _irq_handler

_start:
    j   _reset                  // 0x00: jump al reset handler

.org 0x10                       // IRQ vector (PROGADDR_IRQ)
_irq_handler:
    // Handler IRQ minimo: ritorna immediatamente
    // Espandi qui per gestire DMA_done (irq[20]), ecc.
    picorv32_retirq             // istruzione speciale PicoRV32

// ---- Reset handler ----
_reset:
    // Carica stack pointer = fine DTCM (da link.ld)
    la      sp, _stack_top

    // Azzera sezione BSS
    la      t0, _bss_start
    la      t1, _bss_end
.zero_bss:
    bge     t0, t1, .bss_done
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       .zero_bss
.bss_done:

    // Copia .data da ITCM (LMA) a DTCM (VMA)
    la      t0, _data_lma
    la      t1, _data_start
    la      t2, _data_end
.copy_data:
    bge     t1, t2, .data_done
    lw      t3, 0(t0)
    sw      t3, 0(t1)
    addi    t0, t0, 4
    addi    t1, t1, 4
    j       .copy_data
.data_done:

    call    main

.hang:
    j       .hang               // loop infinito se main() ritorna
