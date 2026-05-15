/*
 * Linker script per PicoRV32 - GowinPicoSoC
 *
 * ITCM: 0x02000000  64K  codice + rodata (pre-caricato nel bitstream)
 * DTCM: 0x01000000  64K  dati, BSS, heap, stack
 *
 * DTCM configurato a 64K in pico_define.vh (D_MEM_K_BYTE 64).
 */

MEMORY {
    ITCM (rx)  : ORIGIN = 0x02000000, LENGTH = 64K
    DTCM (rwx) : ORIGIN = 0x01000000, LENGTH = 16K
}

SECTIONS {
    .text : {
        *(.text.reset)
        *(.text*)
        *(.rodata*)
    } > ITCM

    .data : {
        _data_start = .;
        *(.data*)
        _data_end = .;
    } > DTCM AT > ITCM

    _data_lma = LOADADDR(.data);

    .bss : {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > DTCM

    /* _end: inizio heap (usato da _sbrk in syscalls.c) */
    _end = .;

    /* Stack cresce verso il basso dalla fine del DTCM */
    _stack_top = ORIGIN(DTCM) + LENGTH(DTCM);
}
