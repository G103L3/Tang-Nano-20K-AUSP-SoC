# Makefile per firmware PicoRV32 - GowinPicoSoC
# Toolchain: mingw-w64-x86_64-riscv64-unknown-elf-gcc (MSYS2 MINGW64)

CROSS   = riscv64-elf
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
LDFLAGS = $(ARCH) -nostdlib -T link.ld
LDLIBS  = -lgcc

SRCS    = src/crt0.S \
          src/main.c \
          src/emit_tone.c \
          src/decoder.c \
          src/read_sdram.c
TARGET  = firmware

# ITCM size = 32 KB -> 8192 parole da 32 bit
ITCM_WORDS = 8192

all: $(TARGET).hex $(TARGET).bin $(TARGET).dump ram32.hex

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

# ram32.hex = formato ITCM Initialization File del Gowin PicoRV32 (flat, 1 parola/riga).
# QUESTO va dato all'IP come "ITCM Initialization File" (NON firmware.hex Intel-HEX).
ram32.hex: $(TARGET).bin
	python3 makehex.py $(TARGET).bin $(ITCM_WORDS)

clean:
	rm -f $(TARGET).elf $(TARGET).hex $(TARGET).bin $(TARGET).dump ram32.hex

.PHONY: all clean
