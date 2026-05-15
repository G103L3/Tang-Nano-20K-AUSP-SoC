# efes_project_s360501 — GowinPicoSoC FPGA System

Sistema embedded su FPGA Gowin basato su **PicoRV32 (RISC-V RV32IMC)** con bus Wishbone, DMA SPI→SDRAM+FFT, SPI, PWM, GPIO e controller SDRAM.

---

## Struttura del progetto

```
efes_project_s360501/
├── src/                         ← Sorgenti VHDL (hardware)
│   ├── top.vhd                  ← Top-level: istanzia CPU, bus, periferiche
│   ├── wb_interconnect.vhd      ← Bus Wishbone 2M/8S con decoder indirizzi
│   ├── dma.vhd                  ← DMA SPI→SDRAM + FFT 512pt
│   ├── spi_master.vhd           ← SPI Master (MCP3201 ADC, solo RX)
│   ├── pwm_generic_master.vhd   ← PWM parametrico (N-bit period/duty)
│   ├── gpio_generic.vhd         ← GPIO parametrico N-bit
│   ├── uart_generic.vhd         ← UART full-duplex configurabile
│   ├── memory_arbiter.vhd       ← Arbitro SDRAM: CPU (M0) vs DMA (M1)
│   ├── gowin_picorv32/          ← IP core Gowin: PicoRV32 + ITCM/DTCM
│   └── sdram_controller_hs/     ← Controller SDRAM
├── firmware/                    ← Firmware C per il PicoRV32
│   ├── include/
│   │   └── periphs.h            ← Mappa periferiche + funzioni inline
│   ├── src/
│   │   ├── crt0.S               ← Startup assembly (stack, BSS, chiama main)
│   │   ├── syscalls.c           ← Stub syscall (sbrk, ecc.)
│   │   └── main.c               ← Applicazione principale (modem AUSP)
│   ├── link.ld                  ← Linker script (ITCM 64K / DTCM 64K)
│   ├── Makefile                 ← Build firmware
│   └── README.md                ← Documentazione firmware + tabella AUSP
└── impl/                        ← Output sintesi Gowin (bitstream .fs)
```

---

## Architettura Hardware

```
                    ┌─────────────────────────────┐
                    │     GowinPicoSoC (IP core)  │
                    │  ┌──────────┐ ┌──────────┐  │
                    │  │ PicoRV32 │ │  ITCM    │  │
                    │  │ RV32IMC  │ │ (codice) │  │
                    │  └────┬─────┘ └──────────┘  │
                    │       │        ┌──────────┐  │
clk ───────────────►│  JTAG │        │  DTCM    │  │
rst ───────────────►│  debug│        │  (dati)  │  │
ser_tx/rx ─────────►│       │        └──────────┘  │
                    │  slv_ext_* (WB master) ───────┼──────────────┐
                    └─────────────────────────────┘              │
                                                                 ▼
                    ┌──────────────────────────────────────────────┐
                    │             wb_interconnect (2M / 8S)         │
                    │  M0=CPU   M1=DMA(periferiche non-SDRAM)      │
                    │                                              │
                    │  S0 0x1xxxxxxx  S1 0x4xxxxxxx  S2 0x5xxxxxxx│
                    │  SDRAM arb.     SPI Master      PWM 15-bit   │
                    │                                              │
                    │  S3 0x6xxxxxxx  S4 0x7xxxxxxx  S5 0x3xxxxxxx│
                    │  PWM 4-bit      GPIO 1-bit      DMA control  │
                    │                                              │
                    │  S6 0x2xxxxxxx                               │
                    │  UART_GENERIC                                 │
                    └──┬──────────────────────────────────────────┘
                       │
              ┌────────▼──────────┐
              │  memory_arbiter   │
              │  M0=CPU (bassa)   │
              │  M1=DMA (alta)    │
              └────────┬──────────┘
                       │
                  ┌────▼────────┐
                  │    SDRAM    │
                  └─────────────┘
```

---

## Mappa Memoria

| Indirizzo C | WB Slave | Periferico | Note |
|-------------|----------|------------|------|
| `0x01000000` | — | DTCM | Data RAM — variabili, stack |
| `0x02000000` | — | ITCM | Instruction RAM — codice firmware |
| `0x10000000` | S0 | SDRAM | CPU via memory_arbiter M0; DMA scrive via M1 |
| `0x20000000` | S6 | UART_GENERIC | UART esterno debug/comunicazione |
| `0x30000000` | S5 | DMA | Registri controllo DMA |
| `0x40000000` | S1 | SPI Master | ADC MCP3201, usato anche dal DMA |
| `0x50000000` | S2 | PWM 15-bit | Tono audio TX |
| `0x60000000` | S3 | PWM 4-bit | LED (16 livelli), pin 77 |
| `0x70000000` | S4 | GPIO | 1-bit output (low-side driver), pin 80 |

> **Nota:** Il PicoRV32 instrada al bus WB esterno solo gli indirizzi con
> `addr[31:28] > 0` e `addr[31] = 0` — range valido `0x10000000`–`0x7FFFFFFF`.

---

## Registri Periferiche

> **Tutti gli offset sono multipli di 4 (word-aligned).**
> I VHDL periferici leggono sempre `dat_i[7:0]`; offset non-allineati
> farebbero scrivere al compilatore nei byte sbagliati del word 32-bit.

### UART_GENERIC — base `0x20000000`

| Offset  | Dir | Descrizione |
|---------|-----|-------------|
| `+0x00` | R   | `bit[8]`=rx_valid, `bit[7:0]`=RX byte (lettura azzera rx_valid) |
| `+0x00` | W   | Trasmetti byte `dat[7:0]` (ignorato se tx_busy o disabled) |
| `+0x04` | W   | Abilita UART (start) |
| `+0x08` | W   | Disabilita UART (stop) |
| `+0x0C` | W   | `dat[15:0]` = baud_div = clk_hz / baud_rate (default 234 = 27 MHz/115200) |
| `+0x10` | W   | `dat[1:0]`=parità (00=none,01=even,10=odd), `dat[2]`=stop (0=1bit,1=2bit), `dat[6:3]`=data_bits−5 |
| `+0x14` | R   | `dat[1]`=rx_valid, `dat[0]`=tx_busy |

### DMA — base `0x30000000`

| Offset  | Dir | Descrizione |
|---------|-----|-------------|
| `+0x04` | W   | Start — avvia acquisizione continua MCP3201 (~46.9 kHz) |
| `+0x08` | W   | Stop — ferma acquisizione |
| `+0x0C` | W   | `dat[20:0]` = indirizzo base SDRAM (word address) per ping-pong |

FFT 512pt eseguita ogni 512 campioni. Risultati scritti in SDRAM all'indirizzo word
`0x1300` (byte `0x10004C00`). IRQ bit 20 alzato al termine.

### SPI Master — base `0x40000000`

| Offset  | Dir | Descrizione |
|---------|-----|-------------|
| `+0x00` | R   | `dat[11:0]` = campione MCP3201 12-bit (valido quando data_ready) |
| `+0x04` | W   | Start lettura SPI |
| `+0x08` | W   | Stop lettura SPI |
| `+0x0C` | W   | Clear flag data_ready |

### PWM 15-bit — base `0x50000000` (tono audio)

| Offset  | Dir | Descrizione |
|---------|-----|-------------|
| `+0x04` | W   | `dat[29:15]`=duty, `dat[14:0]`=period → avvia |
| `+0x08` | W   | Stop |

`period = 27_000_000 / freq_hz`. Esempio: 1 kHz → period=27000, duty=13500 (50%).
Range valido: 824 Hz – 27 MHz (period da 1 a 32767).

### PWM 4-bit — base `0x60000000` (LED)

| Offset  | Dir | Descrizione |
|---------|-----|-------------|
| `+0x04` | W   | `dat[7:4]`=duty, `dat[3:0]`=period → avvia |
| `+0x08` | W   | Stop |

LED ON: `gpio_set(1)` abilita il low-side driver (pin 80), poi `pwm4_start(p, d)` porta HIGH il pin 77.

### GPIO — base `0x70000000`

| Offset  | Dir | Descrizione |
|---------|-----|-------------|
| `+0x00` | W   | `dat[0]` = gpio_1_o (pin 80) |
| `+0x00` | R   | `dat[0]` = gpio_in (fisso 0) |

---

## Costruire e caricare il firmware

### 1. Toolchain (MSYS2 MINGW64)

```bash
pacman -S mingw-w64-x86_64-riscv64-unknown-elf-gcc make
```

### 2. Compila

```bash
# in MSYS2 MINGW64
cd /c/Gowin/.../efes_project_s360501/firmware
make clean && make
# produce: firmware.elf, firmware.hex, firmware.bin, firmware.dump
```

### 3. Sintetizza

Apri Gowin IDE → **Synthesize** → **Place & Route** (flow completo).
Il percorso del binario è in `src/gowin_picorv32/temp/gowin_picorv32/pico_define.vh`
(`SW_BIN_PATH`): il firmware viene baked nel bitstream a compile time.

> Ogni volta che modifichi il firmware **o** i VHDL devi risintetizzare.

### 4. Programma la flash (dal Mac)

```bash
openFPGALoader -b tangnano20k --write-flash impl/pnr/efes_project_s360501.fs
```

La SRAM è volatile (si cancella al power-off). Usa `--write-flash` per rendere il bitstream permanente.

### 5. UART debug

```bash
# Mac — trova la porta
ls /dev/tty.usbserial-*
# Connetti
screen /dev/tty.usbserial-XXXXXXX 115200
# oppure
minicom -D /dev/tty.usbserial-XXXXXXX -b 115200
```

Dopo il power cycle compare: `[BOOT] firmware ok`

---

## Pin FPGA (Tang Nano 20K)

| Segnale       | Pin | Direzione | Nota |
|---------------|-----|-----------|------|
| `clk_i`       | 10  | IN  | Oscillatore 27 MHz |
| `rst_i`       | 88  | IN  | Reset attivo LOW (pull-up → normalmente HIGH) |
| `ser_tx`      | 25  | OUT | UART interna PicoRV32 |
| `ser_rx`      | 26  | IN  | UART interna PicoRV32 |
| `uart_ext_tx` | 17  | OUT | UART esterna → BL702 bridge → USB |
| `uart_ext_rx` | 18  | IN  | UART esterna ← BL702 bridge ← USB |
| `gpio_1_o`    | 80  | OUT | Low-side driver enable LED |
| `pwm_4_o`     | 77  | OUT | Segnale LED (HIGH = ON) |
| `pwm_10_o`    | 76  | OUT | Tono audio TX |
| `cs_p`        | 73  | OUT | SPI CS — MCP3201 |
| `sck_p`       | 74  | OUT | SPI SCK |
| `mosi_p`      | 75  | OUT | SPI MOSI (fisso 0) |
| `miso_p`      | 85  | IN  | SPI MISO — dati ADC |

---

## Toolchain e Dipendenze

| Tool | Versione | Uso |
|------|----------|-----|
| Gowin EDA | V1.9.11.03 Education | Sintesi FPGA |
| riscv64-unknown-elf-gcc | 12+ (MSYS2) | Compilatore firmware RV32IMC |
| openFPGALoader | qualsiasi | Programmazione flash dal Mac |
| screen / minicom | qualsiasi | Monitor UART |

---

## Clock e frequenze

### Sorgente clock
Board Gowin Tang Nano 20K: oscillatore a **27 MHz** sul pin 10 (`clk_i`).

### Dominio clock CPU/periferiche — 27 MHz
PicoRV32, DMA, SPI, PWM, GPIO, UART girano tutti a 27 MHz.  
`CLK_HZ = 27000000UL` usato per baud rate UART e calcolo period PWM.

### Dominio clock SDRAM — 108 MHz
Il `memory_arbiter` (e il `SDRAM_Controller_HS_Top` al suo interno) gira a 108 MHz
generati dall'rPLL Gowin con parametri (standard per Tang Nano 20K):

| Parametro | Valore | Note |
|-----------|--------|------|
| `FCLKIN`  | 27 MHz | oscillatore di board |
| `IDIV_SEL`| 0      | divisore ingresso = 1 |
| `FBDIV_SEL`| 3    | fout = 27×(3+1)/(0+1) = 108 MHz |
| `ODIV_SEL`| 8      | VCO = 108×8 = 864 MHz |
| **VCO**   | 864 MHz | dentro range valido GW2AR-18 (500–1250 MHz) |
| **fout**  | 108 MHz | clock SDRAM controller |

> **ATTENZIONE:** se si rigenera il wizard rPLL, usare i valori della tabella sopra.  
> Parametri errati (es. ODIV_SEL=4, FBDIV_SEL=42 → VCO=166 MHz fuori range) → PLL non aggancia → SDRAM non si inizializza mai.

### Timing SDRAM Controller HS (a 108 MHz)

| Parametro | Valore | Motivo |
|-----------|--------|--------|
| Data Width | 32 | SDRAM embedded 32-bit |
| Bank Width | 2 | 4 banchi |
| Row Width | 11 | 2048 righe |
| Column Width | 8 | 256 colonne |
| CL | 3 | CAS Latency 3 cicli |
| tRP | 3 | 3×9.26ns=27.8ns ≥ 15ns min |
| tRFC | 9 | 9×9.26ns=83.3ns ≥ 66ns min |
| tMRD | 2 | 2 cicli min |
| tRCD | 3 | 3×9.26ns=27.8ns ≥ 15ns min |
| tWR | 3 | 3×9.26ns=27.8ns ≥ 12ns min |
| Disable I/O Insertion | ✓ | obbligatorio per SDRAM embedded |

### PLL LOCK e reset SDRAM
Il segnale `lock` dell'rPLL è collegato a `I_sdrc_rst_n` del controller SDRAM.
Il controller rimane in reset finché il PLL non aggancia, impedendo inizializzazioni spurie.
