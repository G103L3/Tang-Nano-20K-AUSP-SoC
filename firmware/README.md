# Firmware — AUSP Acoustic Modem

The FPGA acts as a pure physical-layer acoustic modem bridged to an ESP32 via UART.

- **RX path**: MCP3201 ADC → SPI → DMA → FFT (512 pt, 48 kHz) → decode tone pair → send ASCII char to ESP32
- **TX path**: receive ASCII char from ESP32 → drive PWM10 (f_data tone) + PWM4 (LED brightness)

## Encoding table

Every symbol is a pair of simultaneous tones: a **data frequency** (f_data, 1000–7800 Hz) and a
**carrier frequency** (f_carrier) that identifies the logical channel.

```
char      = '@' + channel * 18 + code
f_data    = 1000 + code    * 400   Hz
f_carrier = 8200 + channel * 400   Hz
```

Special symbol: `'.'` = 80 ms silence (no tones emitted).

### Master channel — f_carrier = 8200 Hz

| Char | ASCII | Code | f_data (Hz) |
|------|-------|------|-------------|
| `@`  |  64   |  0   |    1000     |
| `A`  |  65   |  1   |    1400     |
| `B`  |  66   |  2   |    1800     |
| `C`  |  67   |  3   |    2200     |
| `D`  |  68   |  4   |    2600     |
| `E`  |  69   |  5   |    3000     |
| `F`  |  70   |  6   |    3400     |
| `G`  |  71   |  7   |    3800     |
| `H`  |  72   |  8   |    4200     |
| `I`  |  73   |  9   |    4600     |
| `J`  |  74   | 10   |    5000     |
| `K`  |  75   | 11   |    5400     |
| `L`  |  76   | 12   |    5800     |
| `M`  |  77   | 13   |    6200     |
| `N`  |  78   | 14   |    6600     |
| `O`  |  79   | 15   |    7000     |
| `P`  |  80   | 16   |    7400     |
| `Q`  |  81   | 17   |    7800     |

### Config channel — f_carrier = 8600 Hz

| Char | ASCII | Code | f_data (Hz) |
|------|-------|------|-------------|
| `R`  |  82   |  0   |    1000     |
| `S`  |  83   |  1   |    1400     |
| `T`  |  84   |  2   |    1800     |
| `U`  |  85   |  3   |    2200     |
| `V`  |  86   |  4   |    2600     |
| `W`  |  87   |  5   |    3000     |
| `X`  |  88   |  6   |    3400     |
| `Y`  |  89   |  7   |    3800     |
| `Z`  |  90   |  8   |    4200     |
| `[`  |  91   |  9   |    4600     |
| `\`  |  92   | 10   |    5000     |
| `]`  |  93   | 11   |    5400     |
| `^`  |  94   | 12   |    5800     |
| `_`  |  95   | 13   |    6200     |
| `` ` `` | 96 | 14  |    6600     |
| `a`  |  97   | 15   |    7000     |
| `b`  |  98   | 16   |    7400     |
| `c`  |  99   | 17   |    7800     |

### Slave channel — f_carrier = 9000 Hz

| Char | ASCII | Code | f_data (Hz) |
|------|-------|------|-------------|
| `d`  | 100   |  0   |    1000     |
| `e`  | 101   |  1   |    1400     |
| `f`  | 102   |  2   |    1800     |
| `g`  | 103   |  3   |    2200     |
| `h`  | 104   |  4   |    2600     |
| `i`  | 105   |  5   |    3000     |
| `j`  | 106   |  6   |    3400     |
| `k`  | 107   |  7   |    3800     |
| `l`  | 108   |  8   |    4200     |
| `m`  | 109   |  9   |    4600     |
| `n`  | 110   | 10   |    5000     |
| `o`  | 111   | 11   |    5400     |
| `p`  | 112   | 12   |    5800     |
| `q`  | 113   | 13   |    6200     |
| `r`  | 114   | 14   |    6600     |
| `s`  | 115   | 15   |    7000     |
| `t`  | 116   | 16   |    7400     |
| `u`  | 117   | 17   |    7800     |

## Hardware map

| Peripheral | Base addr  | Role                                       |
|------------|------------|--------------------------------------------|
| UART ext   | 0x20000000 | UART ↔ ESP32/debug, 115200 8N1            |
| DMA        | 0x30000000 | SPI → SDRAM, triggers FFT every 512 smp   |
| SPI master | 0x40000000 | MCP3201 ADC input at ~46.9 kHz            |
| PWM10      | 0x50000000 | Audio TX — f_data tone (15-bit, 27 MHz)   |
| PWM4       | 0x60000000 | LED — 4-bit (16 levels), pin 77            |
| GPIO       | 0x70000000 | 1-bit output (low-side driver), pin 80     |
| SDRAM      | 0x10000000 | FFT input buffer; results at 0x10004C00   |

> **Note on register offsets:** all offsets below are **word-aligned** (multiples of 4).
> The VHDL peripherals always read `dat_i[7:0]`, so writes must generate a `sw` instruction
> (word store) to place data in the correct byte lane.

### UART ext — 0x20000000

| Offset | Dir | Description |
|--------|-----|-------------|
| +0x00  | R   | `bit[8]`=rx_valid, `bit[7:0]`=RX data (read clears rx_valid) |
| +0x00  | W   | TX data `dat[7:0]` (ignored if tx_busy or disabled) |
| +0x04  | W   | Enable UART (start) |
| +0x08  | W   | Disable UART (stop) |
| +0x0C  | W   | `dat[15:0]` = baud_div = clk_hz / baud_rate (default 234 = 27 MHz/115200) |
| +0x10  | W   | `dat[1:0]`=parity (00=none,01=even,10=odd), `dat[2]`=stop bits (0=1,1=2), `dat[6:3]`=data_bits−5 |
| +0x14  | R   | `dat[1]`=rx_valid, `dat[0]`=tx_busy |

### DMA — 0x30000000

| Offset | Dir | Description |
|--------|-----|-------------|
| +0x04  | W   | Start — begin continuous MCP3201 acquisition (~46.9 kHz) |
| +0x08  | W   | Stop  — halt acquisition |
| +0x0C  | W   | `dat[20:0]` = SDRAM base word address for ping-pong buffers |

FFT results written to SDRAM word address 0x1300 (byte 0x10004C00). IRQ bit 20 raised on completion.

### SPI master — 0x40000000

| Offset | Dir | Description |
|--------|-----|-------------|
| +0x00  | R   | `dat[11:0]` = 12-bit MCP3201 sample (valid when data_ready) |
| +0x04  | W   | Start SPI read |
| +0x08  | W   | Stop SPI read |
| +0x0C  | W   | Clear data_ready flag |

### PWM10 — 0x50000000 (15-bit, audio output)

| Offset | Dir | Description |
|--------|-----|-------------|
| +0x04  | W   | `dat[29:15]`=duty, `dat[14:0]`=period → start PWM |
| +0x08  | W   | Stop PWM |

`period = 27_000_000 / freq_hz`. For 1 kHz: period = 27000 (fits in 15 bits, max 32767).

### PWM4 — 0x60000000 (4-bit, LED)

| Offset | Dir | Description |
|--------|-----|-------------|
| +0x04  | W   | `dat[7:4]`=duty, `dat[3:0]`=period → start PWM |
| +0x08  | W   | Stop PWM |

LED ON: `gpio_set(1)` (enables low-side driver, pin 80) + `pwm4_start(period, duty)` (pin 77).

### GPIO — 0x70000000

| Offset | Dir | Description |
|--------|-----|-------------|
| +0x00  | W   | `dat[0]` = gpio_1_o (pin 80, low-side driver enable) |
| +0x00  | R   | `dat[0]` = gpio_in (fixed 0) |

## Building

Open **MSYS2 MINGW64** shell (not PowerShell):

```bash
pacman -S make mingw-w64-x86_64-riscv64-unknown-elf-gcc   # first time only
cd "C:/Gowin/.../efes_project_s360501/firmware"
make
```

`firmware.bin` is embedded into the bitstream via `SW_BIN_PATH` in `pico_define.vh`.
One USB programming step loads both FPGA fabric and CPU firmware.

## Memory map

| Address    | Region | Size |
|------------|--------|------|
| 0x02000000 | ITCM   | 64 KB (code + rodata) |
| 0x01000000 | DTCM   | 64 KB (data, BSS, heap, stack) |
