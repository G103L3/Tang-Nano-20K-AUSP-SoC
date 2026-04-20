/*
 * Linker script per PicoRV32 - GowinPicoSoC
 *
 * ITCM: 0x02000000 - codice e constanti (caricato via JTAG)
 * DTCM: 0x01000000 - dati, BSS, stack
 *
 * IMPORTANTE: verifica le dimensioni ITCM/DTCM che hai scelto
 * nel Gowin IP Generator (default: ITCM=64K, DTCM=16K).
 * Modifica LENGTH qui se hai configurato valori diversi.
 */

MEMORY {
    ITCM (rx)  : ORIGIN = 0x02000000, LENGTH = 64K
    DTCM (rwx) : ORIGIN = 0x01000000, LENGTH = 16K
}

SECTIONS {
    .text : {
        *(.text.reset)      /* crt0.S deve stare prima di tutto */
        *(.text*)
        *(.rodata*)
    } > ITCM

    /* .data vive in DTCM a runtime, ma è salvato in ITCM nel binario */
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

    /* Stack cresce verso il basso dalla fine del DTCM */
    _stack_top = ORIGIN(DTCM) + LENGTH(DTCM);
}
