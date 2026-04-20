# Makefile per firmware PicoRV32 - GowinPicoSoC
#
# Toolchain richiesta: riscv32-unknown-elf-gcc  (o riscv64-unknown-elf-gcc)
# Su Windows con MSYS2:
#   pacman -S mingw-w64-x86_64-riscv32-unknown-elf-gcc
# Oppure: xPack RISC-V GCC da https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases
# In quel caso usa CROSS = riscv-none-elf

CROSS   = riscv32-unknown-elf
CC      = $(CROSS)-gcc
OBJCOPY = $(CROSS)-objcopy
OBJDUMP = $(CROSS)-objdump
SIZE    = $(CROSS)-size

ARCH    = -march=rv32imc -mabi=ilp32
CFLAGS  = $(ARCH) -O1 -g -nostdlib -ffreestanding -Wall -Wextra \
          -Isrc -Iinclude
LDFLAGS = $(ARCH) -nostdlib -T link.ld -lgcc

SRCS    = src/crt0.S src/main.c
TARGET  = firmware

all: $(TARGET).hex $(TARGET).bin $(TARGET).dump

$(TARGET).elf: $(SRCS) link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRCS)
	$(SIZE) $@

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O ihex $< $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -d -S $< > $@

clean:
	rm -f $(TARGET).elf $(TARGET).hex $(TARGET).bin $(TARGET).dump

# Carica via OpenOCD (JTAG)
# Modifica il file di config OpenOCD per il tuo programmatore
flash: $(TARGET).elf
	openocd -f openocd.cfg \
	  -c "program $(TARGET).elf verify reset exit"

.PHONY: all clean flash
