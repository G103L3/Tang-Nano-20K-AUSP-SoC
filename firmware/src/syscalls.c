/*
 * Stub syscalls minimi per newlib bare-metal (PicoRV32).
 * _sbrk: gestisce lo heap dinamico oltre la fine del BSS.
 * Tutti gli altri syscall restituiscono ENOSYS (già forniti da nosys.specs).
 */
#include <sys/types.h>
#include <errno.h>
#include <stdint.h>

/* _end è definito nel linker script dopo il BSS */
extern char _end;

void *_sbrk(ptrdiff_t incr) {
    static char *heap_ptr = &_end;
    char        *prev     = heap_ptr;

    /* Limite superiore: top dello stack (fine DTCM a 0x01010000 per 64K) */
    extern char _stack_top;
    if (heap_ptr + incr > &_stack_top - 512) {
        errno = ENOMEM;
        return (void *)-1;
    }

    heap_ptr += incr;
    return (void *)prev;
}
