.section .text.reset, "ax"
.global _start
.global irq_handler

_start:
    j   _reset

.org 0x10
_irq_vec:
    j   irq_handler

_reset:
    la      sp, _stack_top

    la      t0, _bss_start
    la      t1, _bss_end
.zero_bss:
    bge     t0, t1, .bss_done
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       .zero_bss
.bss_done:

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
    j       .hang
