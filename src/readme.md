# src/ — Sorgenti VHDL

Questa cartella contiene tutti i file hardware del sistema.
---

## File

| File | Descrizione |
|------|-------------|
| `top.vhd` | Top-level: istanzia CPU, bus Wishbone, tutte le periferiche |
| `wb_interconnect.vhd` | Bus Wishbone 2 master / 8 slave con decoder indirizzi |
| `dma.vhd` | DMA SPI→SDRAM: slave WB per config CPU (start/stop/base), master WB per scrittura SDRAM |
| `spi_master.vhd` | SPI Master 32-bit (solo RX, MOSI fisso a 0) |
| `pwm_generic_master.vhd` | PWM parametrico N-bit (period + duty) |
| `gpio_generic.vhd` | GPIO parametrico N-bit |
| `memory_arbiter.vhd` | Arbitro SDRAM: M0=CPU (bassa priorità), M1=DMA (alta priorità) |
| `gowin_picorv32/` | IP core Gowin: PicoRV32 RV32IMC + ITCM + DTCM + UART + JTAG |
| `sdram_controller_hs/` | Controller SDRAM |
| `tb_*.vhd` | Testbench GHDL per le singole periferiche |

---

## Mappa indirizzi Wishbone (CPU → periferiche)

> Il PicoRV32 instrada al bus WB esterno solo gli indirizzi con
> `addr[31:28] > 0` **e** `addr[31] = 0`.
> Per questo SDRAM è a `0x1xxxxxxx` e DMA a `0x3xxxxxxx`.

| Indirizzo C | Slave WB | Periferica |
|-------------|----------|------------|
| `0x10000000` | S0 | SDRAM (via memory\_arbiter M0) |
| `0x30000000` | S5 | DMA — registri di controllo |
| `0x40000000` | S1 | SPI Master |
| `0x50000000` | S2 | PWM 10-bit |
| `0x60000000` | S3 | PWM 4-bit |
| `0x70000000` | S4 | GPIO 1-bit |

Indirizzi interni al GowinPicoSoC (non via WB):

| Indirizzo C | Periferica |
|-------------|------------|
| `0x01000000` | DTCM — variabili, stack |
| `0x02000000` | ITCM — codice (reset vector) |
| `0x04000004` | UART divisore baud (`baud = clk / div`) |
| `0x04000008` | UART dato (write=TX, read bit[8]=valid) |

---

## Pin Map — GW2AR-LV18QN88C8/I7

### Assegnati (da `efes_project_s360501.cst`)

| Segnale `top.vhd` | Pin | IO Type | Direzione | Periferica |
|-------------------|-----|---------|-----------|------------|
| `cs_p` | **73** | LVCMOS18 | OUT | SPI — Chip Select |
| `sck_p` | **74** | LVCMOS18 | OUT | SPI — Clock |
| `mosi_p` | **75** | LVCMOS18 | OUT | SPI — MOSI (fisso a 0) |
| `miso_p` | **85** | LVCMOS18 | IN | SPI — MISO |
| `pwm_10_o` | **76** | LVCMOS18 | OUT | PWM 10-bit |
| `pwm_4_o` | **77** | LVCMOS18 | OUT | PWM 4-bit |
| `gpio_1_o` | **80** | LVCMOS18 | OUT | GPIO 1-bit |

### Da assegnare (non ancora nel `.cst`)

Board: **Sipeed Tang Nano 20K** — GW2AR-LV18QN88C8/I7

| Segnale `top.vhd` | Pin | Direzione | Fonte sul board |
|-------------------|-----|-----------|-----------------|
| `clk_i` | **4** | IN | Oscillatore 27 MHz |
| `rst_i` | **88** | IN | Tasto S1 (attivo basso) |
| `ser_tx` | **17** | OUT | UART → CH552 USB-Serial |
| `ser_rx` | **18** | IN | UART ← CH552 USB-Serial |
| `jtag_tdi` | — | IN | Header libero (debug firmware C) |
| `jtag_tdo` | — | OUT | Header libero |
| `jtag_tck` | — | IN | Header libero |
| `jtag_tms` | — | IN | Header libero |

---

## TODO hardware

- [x] Istanziare `dma.vhd` in `top.vhd` e collegarlo a `s5_*` del wb\_interconnect
- [x] Collegare master WB del DMA a `memory_arbiter M1`
- [x] Collegare `dma.irq_o` a `irq_in(20)` del PicoRV32
- [x] Correggere il confronto indirizzo in `dma.vhd` (ora usa `s_adr_i` a 32 bit correttamente)
