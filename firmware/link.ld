/*
 * Linker script per PicoRV32 - Gowin PicoRV32 IP (efes_project_s360501).
 *
 * ITCM: 0x02000000  32K  codice + rodata (pre-caricato nel bitstream via .hex)
 * DTCM: 0x01000000  16K  dati, BSS, heap, stack
 *
 * Dimensioni allineate a pico_define.vh: I_MEM_K_BYTE 32, D_MEM_K_BYTE 16.
 */

MEMORY {
    ITCM (rx)  : ORIGIN = 0x02000000, LENGTH = 32K
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
