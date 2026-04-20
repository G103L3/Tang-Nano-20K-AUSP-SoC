# efes_project_s360501 — GowinPicoSoC FPGA System

Sistema embedded su FPGA Gowin basato su **PicoRV32 (RISC-V RV32IMC)** con bus Wishbone, DMA, SPI, PWM, GPIO e controller SDRAM.

---

## Struttura del progetto

```
efes_project_s360501/
├── src/                    ← Sorgenti VHDL (hardware)
│   ├── top.vhd             ← Top-level: istanzia CPU, bus, periferiche
│   ├── wb_interconnect.vhd ← Bus Wishbone 2M/8S con decoder indirizzi
│   ├── dma.vhd             ← DMA SDRAM↔SPI (master WB + slave config)
│   ├── spi_master.vhd      ← SPI Master 32-bit (solo RX, MOSI=0)
│   ├── pwm_generic.vhd     ← PWM parametrico (N-bit period/duty)
│   ├── gpio_generic.vhd    ← GPIO parametrico N-bit
│   ├── memory_arbiter.vhd  ← Arbitro SDRAM: CPU (M0) vs DMA (M1)
│   ├── gowin_picorv32/     ← IP core Gowin: PicoRV32 + ITCM/DTCM + UART
│   └── sdram_controller_hs/← Controller SDRAM
├── firmware/               ← Firmware C per il PicoRV32
│   ├── include/
│   │   └── periphs.h       ← Mappa periferiche + funzioni inline
│   ├── src/
│   │   ├── crt0.S          ← Startup assembly (stack, BSS, chiama main)
│   │   └── main.c          ← Applicazione principale
│   ├── link.ld             ← Linker script (ITCM/DTCM)
│   └── Makefile            ← Build + flash via OpenOCD
└── impl/                   ← Output sintesi Gowin
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
UART TX/RX ────────►│       │        └──────────┘  │
                    │  slv_ext_* (WB master) ───────┼──────────────┐
                    └─────────────────────────────┘              │
                                                                 ▼
                    ┌──────────────────────────────────────────────┐
                    │             wb_interconnect (2M / 8S)         │
                    │  M0=CPU   M1=DMA(periferiche)                │
                    │                                              │
                    │  S0 0x1xxxxxxx  S1 0x4xxxxxxx  S2 0x5xxxxxxx│
                    │  SDRAM arb.     SPI Master      PWM 10-bit   │
                    │                                              │
                    │  S3 0x6xxxxxxx  S4 0x7xxxxxxx  S5 0x3xxxxxxx│
                    │  PWM 4-bit      GPIO 1-bit      DMA control  │
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

## Mappa Memoria (visione dal C)

| Indirizzo | Regione | Descrizione |
|-----------|---------|-------------|
| `0x01000000` | DTCM | Data RAM — variabili globali, stack |
| `0x02000000` | ITCM | Instruction RAM — codice firmware |
| `0x04000004` | UART\_DIV | Divisore baud rate (simpleuart interno) |
| `0x04000008` | UART\_DATA | TX write / RX read (bit[8]=valid) |
| `0x10000000` | SDRAM | Via WB S0 → memory\_arbiter M0 |
| `0x30000000` | DMA | Registri di controllo DMA |
| `0x40000000` | SPI | SPI Master (solo RX, 32-bit) |
| `0x50000000` | PWM10 | PWM 10-bit (period + duty) |
| `0x60000000` | PWM4 | PWM 4-bit (period + duty) |
| `0x70000000` | GPIO | GPIO 1-bit output |

> **Nota:** Il PicoRV32 instrada al bus WB esterno solo gli indirizzi con
> `addr[31:28] > 0` e `addr[31] = 0`. Per questo motivo SDRAM è a `0x1xxxxxxx`
> e DMA a `0x3xxxxxxx` (non `0x0` o `0x8` come sarebbe intuitivo).

---

## Registri Periferiche

### UART (simpleuart, interno al GowinPicoSoC)
| Indirizzo | Accesso | Descrizione |
|-----------|---------|-------------|
| `0x04000004` | R/W | Divisore: `div = clk_hz / baud` |
| `0x04000008` | W | Trasmetti byte (attende TX libero) |
| `0x04000008` | R | Bit[8]=0: dato valido in Bit[7:0] |

### SPI Master (`spi_master.vhd`)
| Offset | Accesso | Descrizione |
|--------|---------|-------------|
| `+0x00` | R | Dato MISO 32-bit (ack solo se data\_ready) |
| `+0x01` | W | Start lettura SPI |
| `+0x02` | W | Stop lettura SPI |
| `+0x03` | W | Clear flag data\_ready |

### PWM 10-bit (`pwm_generic.vhd`, nbit=10)
| Offset | Accesso | Descrizione |
|--------|---------|-------------|
| `+0x01` | W | `dat[19:10]`=duty, `dat[9:0]`=period → avvia |
| `+0x02` | W | Stop (necessario prima di riconfigurare) |

### PWM 4-bit (`pwm_generic.vhd`, nbit=4)
| Offset | Accesso | Descrizione |
|--------|---------|-------------|
| `+0x01` | W | `dat[7:4]`=duty, `dat[3:0]`=period → avvia |
| `+0x02` | W | Stop |

### GPIO (`gpio_generic.vhd`, nbit=1)
| Offset | Accesso | Descrizione |
|--------|---------|-------------|
| qualsiasi | W | `dat[0]` = `gpio_1_o` |
| qualsiasi | R | `dat[0]` = `gpio_in` (attualmente fisso a 0) |

### DMA (`dma.vhd`)
| Offset | Accesso | Descrizione |
|--------|---------|-------------|
| `+0x00` | W | CTRL: bit[0]=start, bit[1]=enable |
| `+0x04` | W | SRC: indirizzo sorgente in SDRAM |
| `+0x08` | W | DST: indirizzo destinazione in SDRAM |
| `+0x0C` | W | LEN: numero di parole 32-bit |
| `+0x10` | R/W | STATUS: bit[0]=busy, bit[1]=done (W=1 per azzera done) |

> IRQ DMA → `irq_in[20]` del PicoRV32

---

## Firmware C — Guida rapida

### 1. Installa la toolchain RISC-V

**Windows (MSYS2):**
```bash
pacman -S mingw-w64-x86_64-riscv32-unknown-elf-gcc
```

**Windows (xPack — standalone, senza MSYS2):**
Scarica da [xpack-dev-tools/riscv-none-elf-gcc-xpack](https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases).
In quel caso modifica nel `Makefile`: `CROSS = riscv-none-elf`

### 2. Verifica le dimensioni ITCM/DTCM

Apri Gowin IDE → IP Core → GowinPicoRV32 → controlla i campi
**ITCM Size** e **DTCM Size**.
Aggiorna [firmware/link.ld](firmware/link.ld) se necessario (default: ITCM=64K, DTCM=16K).

### 3. Compila

```bash
cd firmware
make
# produce: firmware.elf, firmware.hex, firmware.bin, firmware.dump
```

### 4. Carica via JTAG

Il PicoRV32 ha il debug JTAG abilitato (pin `jtag_tdi/tdo/tck/tms` esposti nel top).
Usa **OpenOCD** con un programmatore compatibile (es. FT2232H):

```bash
make flash   # chiama openocd con firmware.elf
```

Configura `firmware/openocd.cfg` per il tuo programmatore. Esempio per FT2232H:
```tcl
adapter driver ftdi
ftdi_vid_pid 0x0403 0x6010
transport select jtag
set _CHIPNAME riscv
jtag newtap $_CHIPNAME cpu -irlen 5
target create $_CHIPNAME.cpu riscv -chain-position $_CHIPNAME.cpu
```

### 5. Esempio d'uso nel codice C

```c
#include "include/periphs.h"

#define CLK_HZ  27000000UL   // 27 MHz board Gowin Education

int main(void) {
    uart_init(CLK_HZ, 115200);
    uart_puts("Ciao dal PicoRV32!\r\n");

    pwm10_start(1023, 512);  // 50% duty cycle
    gpio_set(1);

    while (1) {
        int c = uart_getchar_nb();
        if (c == 's') pwm10_stop();
        if (c == 'g') pwm10_start(1023, 768);  // 75%
    }
}
```

---

## Cose ancora da fare (TODO)

- [ ] **Collegare il DMA in `top.vhd`**: istanziare `dma.vhd` e connettere a `s5_*` del wb\_interconnect e a `memory_arbiter M1`
- [ ] **Collegare `irq_o` del DMA** a `irq_in(20)` del PicoRV32
- [ ] **Fix address decode in `dma.vhd`**: i confronti `s_adr_i = x"00000003"` usano l'indirizzo assoluto, dovrebbero usare i bit bassi dell'offset
- [ ] **Configurare OpenOCD** per il programmatore JTAG disponibile
- [ ] **Verificare indirizzi UART** (`0x04000004`/`0x04000008`) con un test hello world

---

## Toolchain e Dipendenze

| Tool | Versione minima | Uso |
|------|-----------------|-----|
| Gowin EDA | V1.9.11.03 Education | Sintesi FPGA |
| riscv32-unknown-elf-gcc | 12+ | Compilatore firmware |
| OpenOCD | 0.12+ | Caricamento via JTAG |
| GHDL (opzionale) | 3.0+ | Simulazione VHDL |

---

## Clock

Il board Gowin Education usa un oscillatore a **27 MHz**.
Usare `CLK_HZ = 27000000UL` nelle funzioni UART e delay.
Se usi un PLL, aggiorna questo valore di conseguenza.
