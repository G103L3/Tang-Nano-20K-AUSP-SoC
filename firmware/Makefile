# Makefile per firmware PicoRV32 - GowinPicoSoC
# Toolchain: mingw-w64-x86_64-riscv64-unknown-elf-gcc (MSYS2 MINGW64)

CROSS   = riscv64-unknown-elf
CC      = $(CROSS)-gcc
OBJCOPY = $(CROSS)-objcopy
OBJDUMP = $(CROSS)-objdump
SIZE    = $(CROSS)-size

ARCH    = -march=rv32imc -mabi=ilp32

# -nostartfiles: usa crt0.S custom, ma linka ancora libc/libm/libgcc
# -ffreestanding: non assume che esista main() OS-style
CFLAGS  = $(ARCH) -O1 -g -nostartfiles -ffreestanding -Wall -Wextra \
          -Isrc -Iinclude

# Le librerie DEVONO venire DOPO i file oggetto (ordine linker)
# --specs=nosys.specs: stub per syscall OS (write, read, exit, ...)
# -lm: funzioni matematiche (sin, cos, sqrt, log10)
# -lc: funzioni stringa (memset, strlen, strcmp, ...)
# -lgcc: runtime compilatore (float software: __muldf3, __adddf3, ...)
LDFLAGS = $(ARCH) -nostartfiles -T link.ld
LDLIBS  = --specs=nosys.specs -lm -lc -lgcc

SRCS    = src/crt0.S \
          src/syscalls.c \
          src/main.c
TARGET  = firmware

all: $(TARGET).hex $(TARGET).bin $(TARGET).dump

# Librerie in coda ai sorgenti (risolve riferimenti in avanti)
$(TARGET).elf: $(SRCS) link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRCS) $(LDLIBS)
	$(SIZE) $@

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O ihex $< $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -d -S $< > $@

clean:
	rm -f $(TARGET).elf $(TARGET).hex $(TARGET).bin $(TARGET).dump

.PHONY: all clean
