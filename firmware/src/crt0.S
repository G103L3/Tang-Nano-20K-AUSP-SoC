.section .text.reset, "ax"
.global _start
.global irq_handler

/* ============================================================
 * picorv32 custom instructions (opcode custom-0 = 0x0B).
 * Funzionano con ENABLE_IRQ a prescindere dai q-registers, perche'
 * usiamo solo retirq (ritorno) e maskirq (set maschera).
 *   retirq         : PC <- PC salvato dall'IP, riabilita gli IRQ
 *   maskirq rd, rs : irq_mask <- rs  (bit a 1 = IRQ MASCHERATO),
 *                    rd <- vecchia maschera
 * ============================================================ */
.macro RETIRQ
    .insn r 0x0b, 0, 2, x0, x0, x0
.endm
.macro MASKIRQ rd, rs
    .insn r 0x0b, 6, 3, \rd, \rs, x0
.endm

_start:
    j   _reset

/* Vettore IRQ: l'IP (PROGADDR_IRQ = 0x10) salta qui quando arriva un IRQ.
 * Qui c'e' solo un salto alla ISR vera (sotto). */
.org 0x10
_irq_vec:
    j   _irq

_reset:
    la      sp, _stack_top

    /* azzera .bss */
    la      t0, _bss_start
    la      t1, _bss_end
.zero_bss:
    bge     t0, t1, .bss_done
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       .zero_bss
.bss_done:

    /* copia .data (LMA -> VMA) */
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

    /* Smaschera SOLO il bit 20 (FFT done): serve al decode. Gli altri IRQ restano
     * mascherati. La ISR chiama irq_handler() (alza g_frame_ready). Emit: 0xFFFFFFFF. */
    li      t0, 0xFFEFFFFF
    MASKIRQ x0, t0

    call    main

.hang:
    j       .hang

/* ============================================================
 * ISR vera. L'IRQ puo' arrivare fra una qualsiasi coppia di istruzioni,
 * quindi salviamo TUTTI i registri caller-saved sullo stack (i callee-saved
 * li preserva irq_handler per ABI). Il PC di ritorno lo tiene l'IP e lo
 * ripristina retirq, quindi non va salvato. picorv32 blocca gli IRQ annidati
 * finche' non si fa retirq, percio' la ISR non e' rientrante (ok).
 * ============================================================ */
_irq:
    addi    sp, sp, -64
    sw      ra,  0(sp)
    sw      t0,  4(sp)
    sw      t1,  8(sp)
    sw      t2, 12(sp)
    sw      a0, 16(sp)
    sw      a1, 20(sp)
    sw      a2, 24(sp)
    sw      a3, 28(sp)
    sw      a4, 32(sp)
    sw      a5, 36(sp)
    sw      a6, 40(sp)
    sw      a7, 44(sp)
    sw      t3, 48(sp)
    sw      t4, 52(sp)
    sw      t5, 56(sp)
    sw      t6, 60(sp)

    jal     irq_handler          /* void irq_handler(void) -> setta g_frame_ready */

    lw      ra,  0(sp)
    lw      t0,  4(sp)
    lw      t1,  8(sp)
    lw      t2, 12(sp)
    lw      a0, 16(sp)
    lw      a1, 20(sp)
    lw      a2, 24(sp)
    lw      a3, 28(sp)
    lw      a4, 32(sp)
    lw      a5, 36(sp)
    lw      a6, 40(sp)
    lw      a7, 44(sp)
    lw      t3, 48(sp)
    lw      t4, 52(sp)
    lw      t5, 56(sp)
    lw      t6, 60(sp)
    addi    sp, sp, 64

    RETIRQ
