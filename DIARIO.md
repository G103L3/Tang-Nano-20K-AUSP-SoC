# Diario di Lavoro — efes_project_s360501

FPGA: Gowin GW2AR-18 (Tang Nano 20K) | CPU: PicoRV32 RV32IMC | fCLK = 27 MHz

---

## 2026-04-16 — Feature: SPI Master + PicoRV32

**Obiettivo:** prima integrazione SPI Master con il soft-core PicoRV32 via IP Gowin.

- Implementato `spi_master.vhd` per driver ADC MCP3201 (SPI Mode 0,0, 12-bit, solo RX).
- Integrato IP core Gowin PicoRV32 (RV32IMC) con ITCM/DTCM.
- Primo scaffolding del bus Wishbone.

---

## 2026-04-17 — Feature: PWM, GPIO, Wishbone Bus

**Obiettivo:** completare le periferiche di base.

- `pwm_generic_master.vhd`: PWM parametrico N-bit (period + duty cycle).
- `gpio_generic.vhd`: GPIO parametrico N-bit.
- `wb_interconnect.vhd`: bus Wishbone 2 master / 8 slave con decoder indirizzi.
- Top-level `top.vhd` aggiornato con tutte le istanze.

---

## 2026-04-19 — Fix: SPI Master + DMA

**Obiettivo:** far funzionare la catena SPI → DMA.

- Fix sincronizzazione SPI master (ridotto a 1 singolo processo clocked).
- Fix acknowledge Wishbone SPI.
- Implementato `dma.vhd`: DMA SPI → SDRAM con stato HLSM.
- TestBench DMA scritto e debuggato.
- Fix connessione DMA ↔ Bus ↔ SPI completato e funzionante.

---

## 2026-04-20 — Feature: FFT Gowin + Clock tuning

**Obiettivo:** aggiungere FFT hardware e stabilizzare i clock.

- Integrata FFT 512pt Gowin IP (`src/fft/fft.v`).
- Rimossa UART interna (liberato spazio logica).
- Aggiornato prescaler SPI: **36 tick di clock** per periodo SCK → fSCK = 750 kHz.
- Aggiornato firmware scaffolding con supporto DMA.

---

## 2026-04-21 — Feature: FFT dentro DMA HLSM

**Obiettivo:** integrare la FFT direttamente nel flow del DMA.

- FFT 512pt collegata all'uscita del buffer di acquisizione dentro il DMA.
- HLSM DMA: after 512 campioni SPI → esegui FFT → scrivi risultati in SDRAM.
- Risultati FFT scritti a word address `0x1300` (byte `0x10004C00`).
- IRQ bit 20 alzato al termine FFT.

---

## 2026-04-23 — Feature: Firmware AUSP + Integrazione Finale

**Obiettivo:** portare il firmware del protocollo AUSP sulla board.

- Importato e adattato firmware dal repository AUSP Protocol.
- `main.c`: init UART, GPIO ON (transistor LED), loop PWM4 blink (500ms ON/OFF).
- `periphs.h`: mappa completa periferiche + funzioni inline (`uartext_*`, `pwm4_*`, `gpio_set`).
- Integrazione completa SPI ↔ DMA ↔ FFT verificata a livello RTL.

---

## 2026-05-14 — Hardware Analogico + Debug SPI/ADC + Fix Null Bit

### Circuito analogico: MCP6022 + CMB-6544PF

**Problema iniziale:** circuito non funzionante, board si spegneva appena si collegava il pin CS dell'op-amp a GND.

**Causa scoperta:** il chip era un **MCP6022** (dual op-amp, pin1=VOUTA, nessun CS, nessun VREF interno), non un MCP6023 come creduto. Collegare il "CS" a GND significava cortocircuitare VOUTA → spegnimento immediato.

**Schema finale MCP6022 configurato come amplificatore non invertente (G=11):**

```
VDD (3.3V) ──────────────── Pin 8 (VDD)
GND ──────────────────────── Pin 4 (VSS)

Microfono CMB-6544PF (alimentato a 5V):
  Pin+ mic ──[cap 1µF]──── Pin 3 (VINA+)
                     └──[Rbias 100kΩ]── VREF (1.65V)

VREF = partitore 2×10kΩ da 3.3V:
  3.3V ──[10kΩ]──┬──[10kΩ]── GND
                 └── VREF = 1.65V

Rete di guadagno (non invertente):
  Pin 2 (VINA-) ──[R1=10kΩ]── VREF
  Pin 2 (VINA-) ──[R2=100kΩ]── Pin 1 (VOUTA)

G = 1 + R2/R1 = 1 + 100k/10k = 11
Vout_DC = VREF = 1.65V (centrato per ADC MCP3201)
Vout_AC = segnale mic × 11 (4mV_pk → 44mV_pk attorno a 1.65V)
```

Condensatori di bypass aggiunti: 100nF (0.1µF / codice 104) da VDD→GND e da VREF→GND.

**ADC MCP3201:** alimentato a **5V** (VDD=5V). MISO collegato alla FPGA via partitore 1kΩ (serie) + 2kΩ (a GND) per portare il livello da 5V a max 3.3V (compatibile LVCMOS33 FPGA).

---

### Analisi timing SPI (MCP3201 @ fSCK = 750 kHz)

| Parametro | Valore |
|-----------|--------|
| PRESCALER | 36 tick |
| fSCK | 750 kHz (1.333 µs/periodo) |
| Frame totale | 16 × 36 = 576 clock = 21.33 µs |
| fSAMPLE | 46.875 kHz |
| CS LOW | 13 periodi SCK (bit_cnt 0–12) = 17.33 µs |
| CS HIGH (tCSH) | 3 periodi SCK = **4 µs** >> 625 ns min ✓ |

---

### Bug scoperto: Null Bit off-by-one

**Problema:** il SPI master catturava il bit NULL del MCP3201 al posto di B0 (LSB), restituendo `ADC_code >> 1` invece del valore reale.

**Causa:** il MCP3201 in Mode 0,0 emette il NULL bit (sempre 0) dopo il 1° falling edge di SCK. Il master catturava su rising edge con condizione `bit_cnt >= 1`, quindi:
- `bit_cnt=1` rising → catturava **NULL** (invece di stare fermo)
- `bit_cnt=2..12` → catturava B11..B1
- B0 (emesso dopo il 13° falling edge) non veniva mai catturato (CS andava HIGH subito dopo)

**Risultato:** `shift_reg = {NULL=0, B11..B1}` → valore riportato = metà del reale.

**Fix applicato in `spi_master.vhd`:**

| Parametro | Prima | Dopo |
|-----------|-------|------|
| Cattura attiva | `bit_cnt >= 1` | `bit_cnt >= 2` |
| CS LOW fino a | `bit_cnt <= 12` (13 periodi) | `bit_cnt <= 13` (14 periodi) |
| data_ready trigger | `bit_cnt = 12` | `bit_cnt = 13` |
| tCSH risultante | 3 periodi = 4 µs ✓ | 2 periodi = 2.67 µs ✓ |

Sequenza corretta post-fix:
- `bit_cnt=0`: CS LOW, no cattura (MISO in HI-Z)
- `bit_cnt=1`: CS LOW, no cattura (NULL sul MISO)
- `bit_cnt=2..13`: CS LOW, 12 catture → **B11..B0** ✓
- `bit_cnt=14,15`: CS HIGH

---

### Test di verifica via multimetro (media DC)

**Metodo:** forzare VIN dell'ADC a 5V (full scale → codice 0xFFF), misurare la tensione media sul pin MISO dopo il partitore 1kΩ+2kΩ e sul pin 49 della FPGA.

**Problema intermedio scoperto:** un LED aveva il pin positivo collegato al pin MISO dell'ADC, assorbendo corrente e falsando le misure (1.6V invece del valore atteso). Rimosso il LED, le misure sono tornate coerenti.

**Risultati post-fix:**

| Punto di misura | Tensione misurata | Atteso | Interpretazione |
|-----------------|-------------------|--------|-----------------|
| MISO dopo partitore (1kΩ+2kΩ) | **2.5V** | 75% × 3.3V = 2.475V ✓ | 12 bit HIGH su 16 SCK → timing corretto |
| Pin 49 FPGA (`shift_reg(0)` = B0) | **2.12V** | max teorico 2.37V | B0=1 per ~89% delle conversioni → normale |

**Perché pin 49 < 75% × 3.3V:** `shift_reg(0)` è forzato a 0 durante i primi 2 periodi di ogni frame (bit_cnt=0,1, prima delle catture) e durante gli ultimi 2 (bit_cnt=14,15, dopo il clearing). Duty cycle massimo teorico = 414/576 = 71.9% → 2.37V. Il 2.12V misurato è coerente con B0 non sempre a 1 (VIN non esattamente 5V, rumore).

**Conclusione:** ADC e FPGA funzionano correttamente. Il dato a 12 bit catturato è ora {B11..B0} ✓.

---

### PIN FPGA usati in questo progetto (aggiornato)

| Pin | Segnale | Ruolo |
|-----|---------|-------|
| 4 | `clk_i` | Clock 27 MHz |
| 88 | `rst_i` | Reset attivo LOW |
| 17 | `uart_ext_tx` | UART debug → USB |
| 18 | `uart_ext_rx` | UART debug ← USB |
| 25 | `ser_tx` | UART PicoRV32 |
| 26 | `ser_rx` | UART PicoRV32 |
| 49 | `ausp_dbg_o` | Debug: `shift_reg(0)` del SPI master |
| 53 | `fft_trig_led_o` | Debug: stream seriale FFT |
| 71 | `irq_led_o` | IRQ LED |
| 73 | `cs_p` | SPI CS → MCP3201 |
| 74 | `sck_p` | SPI SCK → MCP3201 |
| 75 | `mosi_p` | SPI MOSI (fisso 0) |
| 76 | `pwm_10_o` | Tono TX 4200 Hz |
| 77 | `pwm_4_o` | Tono TX 8200 Hz |
| 80 | `gpio_1_o` | **SEMPRE '1'** — abilita transistor LED |
| 85 | `miso_p` | SPI MISO ← MCP3201 (via partitore 1kΩ+2kΩ) |

---

## 2026-05-14 (sera) — Debug pipeline SDRAM: DMA→SDRAM→AUSP

**Problema di partenza:** nessuna uscita UART, pin 53 e 86 sempre spenti. Pin 71 (sdram_init_done) acceso → il controller SDRAM si inizializza, il blocco è nel flow DMA→SDRAM.

---

### Cosa ho capito su `O_sdrc_cmd_ack`

Il segnale `O_sdrc_cmd_ack` del controller Gowin SDRC_HS è un flip-flop con **INIT='0'**: parte a zero dopo il power-on e non va mai a '1' da solo. Il codice precedente controllava `cmd_ack='1'` in stato IDLE prima di emettere qualsiasi comando → deadlock permanente, l'arbiter non usciva mai da IDLE.

**Fix (già in quarta riscrittura):** rimosso il controllo di `cmd_ack` dall'IDLE. Si emette WRITE/READ subito quando `init_done='1'` e arriva un request, senza aspettare cmd_ack.

---

### Bug `if/if` → `if/elsif` in `M1_WR_WAIT`

```vhdl
-- BUG: se cmd_ack='1' e cyc='0' nello stesso ciclo, il secondo if vince
if sdrc_cmd_ack = '1' then arb_state <= M1_ACK; end if;
if m1_cyc_i = '0'    then arb_state <= IDLE;    end if;  -- sovrascrive!

-- FIX: elif → solo uno dei due rami viene eseguito
if    sdrc_cmd_ack = '1' then arb_state <= M1_ACK;
elsif m1_cyc_i = '0'     then arb_state <= IDLE;
end if;
```

---

### Timer fallback per WRITE (quinta riscrittura)

Non si sa con certezza se `cmd_ack` si attiva per i comandi WRITE nel SDRC_HS (per READ sì, si è visto che funziona). Aggiunto un timer da 7 bit in `M1_WR_WAIT`:

- **Scatta a 128 cicli @ 108 MHz = 1.18 µs**
- Il timing massimo di una scrittura SDRAM (ACTIVATE + tRCD=3 + WRITE + tWR=3 + PRECHARGE + tRP=3) è circa 15–20 cicli @ 108 MHz = ~185 ns
- 128 cicli è **6–8× il tempo di write** → margine enorme, il controller ha sicuramente finito
- Se `cmd_ack` arriva prima (ciclo ~15), si usa quello; il timer è solo il fallback

**Budget tempo drain:** 512 write × 128 cicli = 65536 cicli @ 108 MHz = **0.6 ms**. Un frame SPI dura 512 campioni / 46875 Hz = **10.9 ms**. Il drain occupa il 5.6% del frame → nessuna perdita di campioni SPI.

**CDC (cross-domain clock):** il DMA gira a 27 MHz, l'arbiter a 108 MHz. I segnali cyc/stb del DMA non hanno synchronizer, ma reggono perché ogni ciclo da 27 MHz dura 4 cicli da 108 MHz → il segnale è stabile quando l'arbiter lo campiona. L'ack resta alto in `M1_ACK` finché il DMA non lo vede → handshake self-consistent.

---

### LED cambiati per diagnosi

| Pin | Prima | Dopo | Perché |
|-----|-------|------|--------|
| 53 | `fft_ser_s` (FS_SERIAL, mai raggiunto) | `fft_dbg_s` = `drain_reached` | capire se DMA arriva a FS_DRAIN |
| 86 | `sdram_nz_s` (AUSP read non-zero) | `fft_ack_dbg_s` = `drain_ack_seen` | capire se l'arbiter ack almeno una write |

---

### Risultati

Dopo sintesi + PnR + programmazione:

- **Pin 71 ON** → SDRAM inizializzata ✓
- **Pin 53 ON** → DMA raggiunge FS_DRAIN ✓  
- **Pin 86 ON** → arbiter genera ack per le write (timer o cmd_ack) ✓

Pipeline SPI → DMA → FFT → FS_DRAIN → memory_arbiter: **funziona**.

---

### Problema aperto: UART dice "00001" invece di "04660"

Il test scrive `fft_dat = 0x00001234` (= 4660 dec) in tutti gli indirizzi SDRAM 0..511. L'AUSP legge gli indirizzi 0..7 e dovrebbe stampare "04660" per ogni bin. Invece stampa "00001".

"00001" = `v_u15 = 1`. Questo succede se:
- `ausp_rdat = 0x00000001` → il dato scritto non è arrivato in SDRAM
- `ausp_rdat = 0xFFFFFFFF` → DQ bus a 0xFF (SDRAM non ha scritto nulla, bus floating con pull-up): `NOT(0x7FFF) + 1 = 1`

**Prossimo passo:** cambiare `fft_dat` da `x"00001234"` a `x"00007FFF"`. Se UART mostra "32767" → write+read funzionano, era solo un falso positivo. Se ancora "00001" → il dato non arriva in SDRAM (problema nel write data path o `I_sdrc_data_len`).

---

## 2026-05-15 — Debug SDRAM: perché l'UART manda 5 cifre decimali e analisi write failure

### Perché l'UART manda 5 cifre decimali (non 8 esadecimali)

L'AUSP legge dalla SDRAM una word a 32 bit (`ausp_rdat`), ma usa solo i bit [15:0] che sono l'uscita della FFT (`xk_re`, parte reale). L'FFT Gowin produce valori **signed 16-bit** (complemento a 2):
- bit 15 = segno (0 = positivo, 1 = negativo)
- bit [14:0] = valore (0..32767)

L'AUSP calcola la **magnitudine** |xk_re|:
```
se bit15='0': magnitude = xk_re[14:0]           (valore positivo, 0..32767)
se bit15='1': magnitude = NOT(xk_re[14:0]) + 1  (complemento a 2 → positivo)
```

Risultato: `v_u15` è sempre 0..32767 (15 bit) → **5 cifre decimali** (non 8 hex).

### Perché "00001" = 1

`v_u15 = 1` se `ausp_rdat[15:0]` = `0xFFFF` (= −1 in signed):
- `NOT(0x7FFF) + 1 = 0x0000 + 1 = 0x0001 = 1`

`ausp_rdat = 0xFFFFFFFF` → SDRAM mai scritta, bit[15:0]=0xFFFF → magnitudine=1 → "00001".

**Conclusione:** la SDRAM restituisce 0xFFFFFFFF (stato iniziale) → le write NON hanno modificato le celle.

---

### Log test — Write path

| # | fft_dat | UART | Esito |
|---|---------|------|-------|
| 1 | `x"00001234"` (=4660) | "00001" | SDRAM non scritta |
| 2 | `x"00007FFF"` (=32767) | "00001" | Nessun effetto → write FAIL confermato |

**Diagnosi:** cambiare `fft_dat` non cambia l'output → le celle SDRAM non vengono mai aggiornate dalle write del DMA.

---

### Ipotesi write failure + fix applicato (da testare — Test 3)

**Ipotesi principale (Settima riscrittura):**

`O_sdrc_cmd_ack` scatta al ciclo ~4 (`Count_cmd_delay=4`, durante la fase ACTIVATE) **anche per WRITE**, non solo per READ. Nel codice precedente, `M1_WR_WAIT` usciva al primo `cmd_ack='1'`:

```vhdl
-- BUG (sesta riscrittura):
if sdrc_cmd_ack = '1' or wr_timer = 127 then  -- ← cmd_ack al ciclo 4 → esce troppo presto
    arb_state <= M1_ACK;

-- FIX (settima riscrittura):
if wr_timer = 127 then  -- ← solo timer, garantisce ~12 cicli WRITE+tWR+PRECHARGE+tRP
    arb_state <= M1_ACK;
```

Con `cmd_ack` al ciclo 4, l'arbiter usciva da `M1_WR_WAIT` troppo presto → il DMA deassertava `cyc` → l'arbiter tornava a IDLE al ciclo ~8-12 → emetteva il comando WRITE successivo mentre il controller era ancora in fase PRECHARGE (~ciclo 9-12). L'SDRC_HS ignorava il nuovo comando → nessuna word scritta in SDRAM.

**Ulteriore fix applicato:**
- `I_sdrc_data_len`: da `x"00"` a `x"01"` — test ipotesi che `x"00"` = 0 word (nessun dato scritto)
- `rd_latch_dly`: da 8 a 4 — latch dato READ al ciclo corretto (4+1+4=8 da cmd_en, dove CL=3 → dato valido al ciclo ~8)

**Test 3:** sintesi + PnR + programma → UART deve mostrare "32767" se write funzionano.

---

### Risultato Test 3 — FALLITO

**Esito:** UART ancora "00001,00001,00001,..." → le write continuano a non modificare la SDRAM.

Il timer-only + `data_len=x"01"` + `rd_latch_dly=4` non hanno risolto il problema. Le celle restano a 0xFFFFFFFF.

| # | Fix applicato | UART | Esito |
|---|--------------|------|-------|
| 3 | Timer-only (no cmd_ack) + `data_len=x"01"` + `rd_latch_dly=4` | "00001" | WRITE ancora FAIL |

---

### Nuova strategia: diagnosi incrementale con LED (Test 4)

Invece di continuare a modificare parametri alla cieca, aggiunti checkpoint LED per capire **a quale livello** si rompe il protocollo WRITE con SDRC_HS.

**Segnali diagnostici aggiunti in `memory_arbiter.vhd`:**
- `wr_ack_seen` — latch a '1' la prima volta che `O_sdrc_cmd_ack='1'` mentre l'arbiter è in `M1_WR_WAIT`. Risponde alla domanda: *SDRC_HS genera cmd_ack quando emetto un WRITE?*
- `rd_ack_seen` — stesso ma per `M0_RD_WAIT` durante READ. Risponde a: *SDRC_HS genera cmd_ack quando emetto un READ?*

**Nuovi pin LED (top.vhd):**

| Pin | Segnale | Significato |
|-----|---------|-------------|
| 53 | `wr_ack_seen_s` | cmd_ack visto durante WRITE |
| 86 | `rd_ack_seen_s` | cmd_ack visto durante READ |
| 71 | `sdram_init_done` | SDRAM inizializzata (invariato) |

**Interpretazione attesa:**

| Pin 53 | Pin 86 | Diagnosi |
|--------|--------|----------|
| OFF | OFF | SDRC_HS non risponde a nessun comando → reset o clock errato |
| OFF | ON | cmd_ack solo su READ → il WRITE non viene riconosciuto (protocollo sbagliato?) |
| ON | OFF | cmd_ack su WRITE ma non READ → READ non funziona |
| ON | ON | cmd_ack funziona su entrambi → problema nel data path (dato scritto ma non riletto correttamente) |

**Prossimo test (Test 4):** sintesi + PnR + programma → osservare i pin 53, 71, 86.

---

### Risultato Test 4 — cmd_ack WRITE OK, READ mai

**Esito:**
- Pin 71 ON → SDRAM init ✓
- Pin 53 ON → `wr_ack_seen`: cmd_ack scatta durante WRITE → SDRC_HS accetta i comandi WRITE ✓
- Pin 86 OFF → `rd_ack_seen` (era cmd_ack per READ): cmd_ack **non scatta mai** durante M0_RD_WAIT

| # | Fix applicato | Pin 53 | Pin 86 | UART | Esito |
|---|--------------|--------|--------|------|-------|
| 4 | wr_ack_seen + rd_ack_seen su pin 53/86 | ON | OFF | "00001" | WRITE ack ok, READ ack mai |

**Conclusione:** il path di lettura SDRAM è rotto perché dipende da cmd_ack che non arriva per READ. L'arbiter rimane bloccato in `M0_RD_WAIT` aspettando cmd_ack che non arriva → nessun latch del dato → nessun ack ad AUSP → AUSP bloccato in `ST_RD_WAIT`.

---

### Fix ottava riscrittura: timer fisso per READ (non dipendere da cmd_ack)

**Stessa strategia usata per WRITE:** ignorare cmd_ack, usare un timer fisso.

Timing READ su SDRC_HS:
- ACTIVATE interno: ~4 cicli (Count_cmd_delay=4 → cmd_ack avrebbe scattato qui, ma non scatta)
- CL=3 cicli dopo CAS → dato valido al ciclo ~7-8 da cmd_en
- sdrc_data_out mantiene il dato anche dopo precharge (output register)

Nuovo M0_RD_WAIT: timer `rd_timer` (5 bit), latch a `rd_timer=12` (ciclo 13 da cmd_en, ampio margine sopra il ciclo 7-8 di validità dato).

**Cambio diagnostica pin 86:** `rd_ack_seen` ora latch '1' quando l'arbiter **entra** in M0_RD_WAIT (non quando arriva cmd_ack), così:
- Pin 86 ON → AUSP ottiene il bus e M0_RD_WAIT viene raggiunto
- Pin 86 OFF → M0_RD_WAIT mai raggiunto → AUSP non ottiene mai il bus (problema priorità M1)

**Test 5:** sintesi + PnR + programma → pin 53 ON, pin 86 ON, UART "32767".

---

### Risultato Test 5 — tutti i pin ON, UART ancora "00001"

**Esito:**
- Pin 71 ON (2.9V), Pin 53 ON (2.4V), Pin 86 ON (3.0V) → tutti i latch scattano ✓
- UART ancora "00001" → sdrc_data_out = 0xFFFFFFFF → dato non scritto in SDRAM

| # | Fix applicato | Pin 53 | Pin 86 | UART | Esito |
|---|--------------|--------|--------|------|-------|
| 5 | Timer READ (rd_timer=12) + rd_ack_seen = M0_RD_WAIT raggiunto | ON | ON | "00001" | SDRAM ancora 0xFFFF |

**Analisi:** il dato non viene scritto nonostante cmd_ack scatti per WRITE. Cercato online la documentazione SDRC_HS Gowin (IPUG279-1.4E).

---

### BUG TROVATO: I_sdrc_data_len usa codifica length-1

Dal manuale Gowin SDRAM Controller IP (IPUG279-1.4E):
> **"The actual data read/write length is `I_sdrc_data_len + 1`."**

Encoding length-1:
- `x"00"` = 1 word → CORRETTO per accesso singola word
- `x"01"` = 2 word → SBAGLIATO (quello che avevamo)

Avevamo cambiato `x"00"` → `x"01"` pensando che `x"00"` = 0 word. In realtà `x"00"` = 1 word.

**Con `x"01"` (2 word):**
- Per WRITE: il controller aspetta 2 word di dati. Noi forniamo sempre lo stesso dato su `I_sdrc_data` → il burst a 2 word non completa correttamente o scrive dato errato.
- Per READ: il controller fa burst a 2 word → sdrc_data_out cambia nel tempo, noi potremmo latchare la word sbagliata.

**Fix applicato (nona riscrittura):** `I_sdrc_data_len => x"00"` (= 1 word, codifica length-1).

**Test 6:** sintesi + PnR + programma → UART deve mostrare "32767".

---

### Risultato Test 6 — ancora "00001" nonostante data_len=x"00"

*(da compilare dopo il test)*

---

### Test 7: bypass totale — sdram_test standalone

Strategia: eliminare tutta la complessità (memory_arbiter, wishbone, DMA) e testare SDRAM_Controller_HS_Top direttamente con una FSM minima.

**Nuovo file:** `src/sdram_test.vhd`
- Entità standalone con SDRAM IP + UART TX @ 108 MHz
- FSM: INIT → WRITE(0xA55A1234 ad addr 0, timer 200 cicli) → READ(addr 0, timer 12 cicli) → TX hex → PAUSE(0.3s) → READ → ...
- Nessun wishbone, nessun arbiter, nessun DMA
- uart_tx hardwired a `uart_ext_tx` in top.vhd

**In top.vhd:**
- `memory_arbiter` sostituito da `sdram_test`
- `ausp_ack <= '0'`, `dma_ack <= '0'` → DMA e AUSP si bloccano, non interferiscono
- `uart_ext_tx <= test_uart_s`

**Atteso su terminale:** `=A55A1234` ripetuto ogni 0.3s
- Se stampa `=A55A1234` → SDRAM write+read funziona, il problema era nel wishbone/arbiter
- Se stampa `=FFFFFFFF` → write non funziona ancora (problema SDRC_HS IP settings)
- Se stampa `=00000000` → write funziona ma READ timer troppo presto

---

## 2026-05-15 — Debug SDRAM Fase 2: Test Inline Diretto in top.vhd

### Strategia adottata

Abbandonato il file `sdram_test.vhd` separato. Il test è stato integrato **direttamente in `top.vhd`** come tre processi aggiuntivi (`tst_*`) più un'istanza `u_sdram_direct` di `SDRAM_Controller_HS_Top`. Vincolo assoluto: non toccare AUSP FSM né DMA. Solo segnali `tst_*`, istanza `u_sdram_direct` e i tre processi di test sono modificabili.

**Logica complessiva del test:**

```
TS_INIT → TS_WRITE → TS_WR_WAIT → TS_READ → TS_RD_WAIT → TS_TX → TS_PAUSE → TS_WRITE (loop)
```

- **WRITE:** scrive `0xDEADBEEF` ad indirizzo 0
- **READ:** rilegge l'indirizzo 0 a 4 istanti diversi da cmd_ack
- **TX:** trasmette via UART il risultato come stringa esadecimale ASCII
- **PAUSE:** attende ~311 ms poi ricomincia da WRITE

---

### Bug #1 — Frequenza PLL sbagliata (baud rate doppio)

**Sintomo:** UART trasmette ma ricevitore decodifica tutto errato.

**Scoperta:** il divisore UART era `936` (per `115200 baud @ 108 MHz`) ma la sintesi usava ancora i parametri PLL precedenti che generavano 54 MHz, non 108 MHz.

**Formula rPLL Gowin:**
```
VCO  = FCLKIN × (FBDIV+1) × ODIV / (IDIV+1)
FOUT = FCLKIN × (FBDIV+1) / (IDIV+1)
```

Con i parametri corretti già in `gowin_rpll.vhd`:
- `FCLKIN = 27`, `FBDIV = 3`, `ODIV = 8`, `IDIV = 0`
- `VCO = 27 × 4 × 8 / 1 = 864 MHz` (dentro spec: 400–900 MHz)
- `FOUT = 27 × 4 / 1 = 108 MHz`

**Causa:** la sintesi Gowin usava il bitstream in cache della run precedente. Il tool non riduce automaticamente se i file sorgente sembrano invariati.

**Fix:** `Project → Clean All` prima di ogni sintetizzazione. **Regola generale: dopo ogni modifica strutturale, sempre Clean All.**

---

### Bug #2 — SDC: clk_sdram vincolato a 54 MHz invece di 108 MHz

**File:** `src/efes_project_s360501.sdc`

**Prima:**
```tcl
create_clock -name clk_sdram -period 18.519 -waveform {0 9.259} [get_nets {clk_sdram}]
```
18.519 ns = 54 MHz. Il Place & Route ottimizzava per 54 MHz → path critico non rispettato a 108 MHz → skew e hold violation non visibili ma presenti.

**Dopo:**
```tcl
create_clock -name clk_sdram -period 9.259 -waveform {0 4.629} [get_nets {clk_sdram}]
```
9.259 ns = 108 MHz (half-period 4.629 ns). P&R ora ottimizza correttamente tutti i path a 108 MHz.

**Effetto:** WARN `PR1014` su `clk_i_d` (clock 27 MHz su routing generico) rimasto ma non bloccante — riguarda il clock lento, non il dominio SDRAM.

---

### Bug #3 — Baud rate UART: divisore 468 invece di 936

**Formula:** `fBAUD = fCLK / (divisore + 1)`

| Divisore | fCLK | fBAUD | Esito |
|----------|------|-------|-------|
| 468 | 108 MHz | 230,400 baud | **doppio** — ricevitore campiona al 50% sbagliato |
| 936 | 108 MHz | 115,261 baud ≈ 115,200 | ✓ |

**Fix:** `tst_baud_cnt = 936` come limite (counter 0..936, periodo = 937 cicli).

---

### Bug #4 — AND gate tra domini di clock diversi (glitch CDC su UART)

**Codice difettoso:**
```vhdl
uart_ext_tx <= boot_tx_pin and test_uart_s;
```

- `boot_tx_pin`: dominio `clk_i` (27 MHz) — UART di boot del PicoRV32
- `test_uart_s`: dominio `clk_sdram` (108 MHz) — UART di test

L'AND combinatorio tra due segnali con clock diversi genera **glitch metastabili** ogni volta che i fronti si sovrappongono: la transizione di `boot_tx_pin` vista a 108 MHz produce pulse spurie di 1–4 ns che il ricevitore interpreta come bit errati.

**Sintomo osservato:** UART trasmette sequenze come `FPGA ␇␐␐...` invece di `A:DEADBEEF...`

**Fix:**
```vhdl
uart_ext_tx <= test_uart_s;
```
`boot_tx_pin` rimosso completamente dall'equazione. Il PicoRV32 è fermo (non ha firmware), quindi `boot_tx_pin` era comunque fisso a '1' — l'AND serviva a zero.

---

### Bug #5 — UART phase drift (seconda iterazione garbled: 'A'→'P')

**Sintomo:** prima iterazione corretta (`A:...`), dalla seconda in poi il primo carattere era sbagliato (`P:...` o simili).

**Causa:** il baud counter `tst_baud_cnt` è libero di girare anche fuori da TS_TX. Quando TS_TX inizia la seconda volta, il counter è in una fase casuale. Se in quel momento `tst_baud_cnt` si trova a metà periodo (es. = 516), il primo baud tick arriva dopo soli `937 - 516 = 421` cicli invece dei 937 canonici.

Il ricevitore UART campiona al centro del bit: dopo `937/2 = 468` cicli dal fronte discendente dello start bit. Con uno start bit di soli 421 cicli, il campionamento avviene DOPO che lo start bit è già finito → ricevitore fraintende il bit di dato successivo come start → disloca tutta la finestra → `0x41` ('A') decodificato come `0x50` ('P').

**Fix:** il primo byte di ogni sequenza TS_TX viene caricato solo quando arriva il prossimo tick del baud counter (fase perfettamente allineata):
```vhdl
if tst_tx_busy = '0' and tst_tx_load = '0' and (tst_tx_seq > 0 or tst_baud_tick = '1') then
```
- `tst_tx_seq = 0` (primo byte): aspetta `tst_baud_tick = '1'` → start bit sempre di 937 cicli esatti
- `tst_tx_seq > 0` (byte successivi): procede subito (la fase è già allineata)

---

### Bug #6 — cmd_en pulsato 1 ciclo: controller non accetta il comando

**Codice difettoso (TS_WRITE e TS_READ):**
```vhdl
when TS_WRITE =>
    tst_cmd_en  <= '1';    -- solo per 1 ciclo!
    tst_cmd     <= "100";
    tst_st      <= TS_WR_WAIT;  -- va subito al wait
```

Il controller SDRC_HS richiede che `cmd_en='1'` e `cmd_ack='1'` siano contemporaneamente alti. Se il controller è occupato (in precharge, refresh, ecc.) e `cmd_ack` non è ancora alto, il comando di 1 ciclo viene perso.

**Fix:** TS_WRITE e TS_READ tengono `cmd_en='1'` finché non ricevono `cmd_ack='1'`:
```vhdl
when TS_WRITE =>
    tst_cmd_en  <= '1';
    tst_cmd     <= "100";
    tst_addr    <= (others => '0');
    tst_wr_data <= x"DEADBEEF";
    if tst_cmd_ack_s = '1' then
        tst_wr_ack_latched <= '1';
        tst_timer <= (others => '0');
        tst_st    <= TS_WR_WAIT;
    end if;
```

---

### Bug #7 — CV0023: "Sweep user defined iobuf instance with dangling iopin" (LETTURA SDRAM 0x00000000)

**Questo è stato il bug più importante e più difficile da trovare.**

#### Sintomo
Dopo aver corretto tutti i bug precedenti, la UART trasmetteva correttamente ma tutti i latch restituivano `0x00000000`.

#### Analisi del warning
Il log di sintesi Gowin riportava:
```
WARN (CV0023): Sweep user defined iobuf instance with dangling iopin
```
32 volte: una per ogni bit di `IO_sdram_dq[31:0]`.

**Cosa significa CV0023:** il controller SDRAM_Controller_HS_Top instanzia 32 primitive `IOBUF` per il bus bidirezionale DQ. Ogni IOBUF ha 4 porte:
- `I`  → dato da scrivere (logica → pad)
- `O`  → dato letto (pad → logica)
- `IO` → il pad fisico bidirezionale
- `OEN` → output enable (active-low)

Se il pin `IO` (il pad fisico) non ha una destinazione fisica, Gowin lo "spazza via" (sweep) durante l'ottimizzazione. Conseguenza: sia il path di scrittura che il path di lettura vengono rimossi → scritture ignorate, letture restituiscono 0x00000000.

#### Causa radice

In `top.vhd`, i segnali SDRAM erano dichiarati come **segnali interni dell'architettura**:
```vhdl
architecture behavioral of top_system is
    ...
    signal O_sdram_clk   : std_logic;       -- ← segnale interno!
    signal IO_sdram_dq   : std_logic_vector(31 downto 0);  -- ← idem
    ...
```

Questi segnali interni non hanno alcuna destinazione fisica dal punto di vista del P&R. Gli IOBUF dentro il controller vedono `IO_sdram_dq(n)` connesso a un filo interno senza pad → CV0023 → sweep.

#### Scoperta chiave: "magic port names" del GW2AR-18C

Il GW2AR-18C (Tang Nano 20K) ha l'SDRAM integrata nel package SIP (System-in-Package): il die SDRAM è incollato internamente e connesso all'FPGA tramite **bond wire interni**, non pin fisici del PCB. Non esistono pin fisici per `IO_sdram_dq`, `O_sdram_clk`, ecc. sulla scheda.

**Come funziona il routing su GW2AR-18C:**
Gowin EDA riconosce automaticamente i nomi esatti dei port come "magic port names". Quando questi 10 segnali appaiono come **port dell'entità top-level** con i loro nomi precisi, il router li instrada automaticamente verso i bond SIP interni del die SDRAM — senza bisogno di constraint nel file `.cst`.

I 10 "magic names" obbligatori:
```vhdl
O_sdram_clk   : out   std_logic
O_sdram_cke   : out   std_logic
O_sdram_cs_n  : out   std_logic
O_sdram_cas_n : out   std_logic
O_sdram_ras_n : out   std_logic
O_sdram_wen_n : out   std_logic
O_sdram_dqm   : out   std_logic_vector(3 downto 0)
O_sdram_addr  : out   std_logic_vector(10 downto 0)
O_sdram_ba    : out   std_logic_vector(1 downto 0)
IO_sdram_dq   : inout std_logic_vector(31 downto 0)
```

**Regola:** NON aggiungere constraint `.cst` per questi segnali. I bond SIP interni non sono pin fisici del package → qualsiasi `IO_LOC` causerebbe errori.

#### Fix applicato

**Prima (bug):** 10 signal declarations nell'architettura (segnali interni)
**Dopo (fix):** 10 port declarations nell'entità top_system

```vhdl
entity top_system is
    port (
        clk_i        : in  std_logic;
        -- ... tutti gli altri port ...
        uart_ext_rx  : in  std_logic;
        -- AGGIUNTO:
        O_sdram_clk   : out   std_logic;
        O_sdram_cke   : out   std_logic;
        O_sdram_cs_n  : out   std_logic;
        O_sdram_cas_n : out   std_logic;
        O_sdram_ras_n : out   std_logic;
        O_sdram_wen_n : out   std_logic;
        O_sdram_dqm   : out   std_logic_vector(3 downto 0);
        O_sdram_addr  : out   std_logic_vector(10 downto 0);
        O_sdram_ba    : out   std_logic_vector(1 downto 0);
        IO_sdram_dq   : inout std_logic_vector(31 downto 0)
    );
end top_system;
```

Rimossi i 10 `signal` corrispondenti dall'architecture body. Il port map di `u_sdram_direct` rimane invariato (gli stessi nomi esistono ora come port).

**Risultato dopo fix CV0023:**
```
A:DEADBEEF 00000000 00000000 00000000
```
Prima iterazione: `tst_rd_latch_8 = DEADBEEF` ✓ — il dato scritto viene riletto.
Iterazioni successive: tutte `FFFFFFFF` → spiegazione nella sezione successiva.

---

### Scoperta del write-to-read forwarding e della finestra temporale

#### Osservazione

| Iterazione | t=8 | t=10 | t=12 | t=14 |
|------------|-----|------|------|------|
| 1ª (dopo WRITE) | **DEADBEEF** | FEADBFFF | FFFFFFFF | FFFFFFFF |
| 2ª+ (solo READ) | FFFFFFFF | FFFFFFFF | FFFFFFFF | FFFFFFFF |

#### Analisi

**Prima iterazione:** il controller SDRC_HS, dopo una WRITE immediata seguita da READ sullo stesso indirizzo, usa il **write-to-read forwarding**: restituisce il dato dal proprio buffer interno di scrittura invece di ri-leggere l'SDRAM. Il dato interno è stabile per molti cicli → `DEADBEEF` a t=8.

**Iterazioni successive:** la read è una vera read SDRAM. La finestra valida del dato su `O_sdrc_data` è molto stretta e si colloca **prima** di t=8.

**Timing SDRAM con i parametri configurati:**

| Parametro IP | Valore | Cicli @ 108 MHz |
|-------------|--------|-----------------|
| CL (CAS Latency) | 3 | 3 cicli |
| tRCD (RAS to CAS Delay) | 3 | 3 cicli |
| tRP (Precharge time) | 3 | 3 cicli |
| tWR (Write Recovery) | 3 | 3 cicli |

Dopo cmd_ack, il controller:
1. Emette ACT (ACTIVATE) alla SDRAM → riga aperta dopo tRCD = 3 cicli
2. Emette CAS (READ) → dato valido dopo CL = 3 cicli
3. **Finestra valida totale: ~t=3..7 cicli da cmd_ack**

La finestra di t=3–7 cicli è **prima** del campionamento a t=8 → tutti `FFFFFFFF` (bus rilasciato, pull-up a VCC).

Il t=10 della prima iterazione mostra `FEADBFFF`: il forwarding si stava già rilasciando, alcuni bit tornati a '1' (bus SIP rilasciato), altri ancora tenuti dall'output register del controller.

#### Fix #1: sempre WRITE prima di READ

Cambiato `TS_PAUSE → TS_WRITE` invece di `TS_PAUSE → TS_READ`. Ogni iterazione riapre la riga con una nuova WRITE → il timing del READ successivo è quello della prima iterazione (row già aperta = forwarding attivo, o row riaperta con timing consistente).

#### Fix #2: campionamento anticipato

```vhdl
-- Prima (campionamento tardivo, fuori finestra)
if tst_timer = 8  then tst_rd_latch_8  <= tst_rd_data;
if tst_timer = 10 then tst_rd_latch_10 <= tst_rd_data;
if tst_timer = 12 then tst_rd_latch_12 <= tst_rd_data;
if tst_timer = 14 then tst_rd_latch_14 <= tst_rd_data;

-- Dopo (finestra t=3..9 cicli da cmd_ack)
if tst_timer = 3  then tst_rd_latch_8  <= tst_rd_data;
if tst_timer = 5  then tst_rd_latch_10 <= tst_rd_data;
if tst_timer = 7  then tst_rd_latch_12 <= tst_rd_data;
if tst_timer = 9  then tst_rd_latch_14 <= tst_rd_data;
```

---

### Risultato Finale — SDRAM Embedded GW2AR-18C FUNZIONANTE ✓

**Output UART stabile su tutte le iterazioni:**
```
A:DEADBEEF DEADBEEF DEADBEEF FEADBFFF
A:DEADBEEF DEADBEEF DEADBEEF FEADBFFF
A:DEADBEEF DEADBEEF DEADBEEF FEADBFFF
A:DEADBEEF DEADBEEF DEADBEEF DEADBFFF
```

**Interpretazione:**

| Campo | Valore | Significato |
|-------|--------|-------------|
| `A` | write cmd_ack visto | WRITE accettato dal controller ✓ |
| t=3 | `DEADBEEF` | dato valido — inizio finestra SDRAM ✓ |
| t=5 | `DEADBEEF` | dato ancora valido ✓ |
| t=7 | `DEADBEEF` | dato ancora valido ✓ |
| t=9 | `FEADBFFF` | bus in rilascio: `0xD→0xF`, ultimi bit tornano a 1 |

La finestra valida di `O_sdrc_data` è **t=3..8 cicli** dopo `cmd_ack`. Il bus si rilascia tra t=8 e t=9 (burst length=1: la SDRAM guida DQ per esattamente 1 ciclo di CAS, poi tristate).

**LED in stato finale:**
- Pin 53 (`fft_trig_led_o`) → lampeggiante @ 311 ms (heartbeat TS_PAUSE)
- Pin 71 (`irq_led_o`) → fisso ON (`tst_init_done = '1'`)

---

### Riepilogo PIN SDRAM (GW2AR-18C embedded, Tang Nano 20K)

| Segnale VHDL | Destinazione | Note |
|--------------|-------------|------|
| `O_sdram_clk` | Bond SIP interno | "Magic name" — nessun CST |
| `O_sdram_cke` | Bond SIP interno | "Magic name" — nessun CST |
| `O_sdram_cs_n` | Bond SIP interno | "Magic name" — nessun CST |
| `O_sdram_cas_n` | Bond SIP interno | "Magic name" — nessun CST |
| `O_sdram_ras_n` | Bond SIP interno | "Magic name" — nessun CST |
| `O_sdram_wen_n` | Bond SIP interno | "Magic name" — nessun CST |
| `O_sdram_dqm[3:0]` | Bond SIP interno | "Magic name" — nessun CST |
| `O_sdram_addr[10:0]` | Bond SIP interno | "Magic name" — nessun CST |
| `O_sdram_ba[1:0]` | Bond SIP interno | "Magic name" — nessun CST |
| `IO_sdram_dq[31:0]` | Bond SIP interno | "Magic name" — nessun CST |

**Regola assoluta per GW2AR-18C:** tutti e 10 i segnali SDRAM devono essere **port dell'entità top-level** (non segnali interni). Il router Gowin li riconosce per nome e li instrada ai bond interni del package SIP. Non aggiungere mai entry CST per questi segnali.

---

### Riepilogo cronologico dei bug e fix

| # | Bug | Sintomo | Fix |
|---|-----|---------|-----|
| 1 | Synthesis cache (no Clean All) | PLL a 54 MHz invece 108 MHz | Project → Clean All prima di ogni build |
| 2 | SDC clk_sdram 18.519 ns (54 MHz) | P&R ottimizzato per freq sbagliata, skew a 108 MHz | SDC: period 9.259 ns, half 4.629 ns |
| 3 | Baud divisore 468 (230400 baud) | UART incomprensibile | divisore → 936 (937 cicli, 115200 baud) |
| 4 | AND gate cross-domain clk_i∧clk_sdram | Glitch, caratteri errati | `uart_ext_tx <= test_uart_s` (CDC rimosso) |
| 5 | Baud phase drift (start bit <468 cicli) | 2ª iterazione: 'A'→'P' | Aspetta baud_tick per il primo byte di ogni TX |
| 6 | cmd_en pulsato 1 ciclo | Comando ignorato se controller busy | Tieni cmd_en='1' finché cmd_ack='1' |
| 7 | IO_sdram_dq segnale interno (CV0023) | IOBUF swept, tutto 0x00000000 | Spostare tutti e 10 i segnali SDRAM a port entity |
| 8 | Campionamento a t=8..14 (fuori finestra) | 2ª+ iterazione: FFFFFFFF | Campionare a t=3,5,7,9 (finestra CL+tRCD=6 cicli) |
| 9 | TS_PAUSE → TS_READ (no WRITE) | Iterazioni 2+ leggono SDRAM "fredda" | TS_PAUSE → TS_WRITE (WRITE ogni iterazione) |

---

### Prossimo passo

Test SDRAM confermato. Rimuovere il test inline e ripristinare la pipeline completa:
- Reimpostare `memory_arbiter` al posto di `u_sdram_direct`
- Ripristinare connessioni DMA e AUSP
- Verificare la pipeline SPI → DMA → FFT → SDRAM → AUSP end-to-end

---

## 2026-05-19 — SDRAM: test scrittura+lettura burst di 26 parole — FUNZIONANTE

**Obiettivo:** validare in hardware un ciclo completo *scrivi N parole consecutive
in SDRAM → rileggile* sul SIP SDRAM integrato del GW2AR-18C, allineando il
design al reference ufficiale Gowin (`sdrc_interface_used.v`, `gw_pll.v`).

### Esito

Output UART (115200 baud) dopo `clean + synthesis + place&route + program`:

```
FPGA ON
00000001 00000002 00000003 ... 00000018 00000019 (00000019)
```

26 parole scritte in indirizzo SDRAM `{bank=2, row=2, col=5}` e rilette in
sequenza incrementale **corretta** (1 … 0x1A). Resta un solo difetto minore:
l'ultima parola (0x1A) viene persa e la penultima (0x19) appare duplicata
— vedi fix in coda.

### Causa radice del problema (perché prima falliva)

Il design girava a **108 MHz**; il reference Gowin gira a **~41 MHz**.
A 108 MHz, con phase-shift del clock SDRAM `PSDA_SEL="0001"` (22.5°), il
margine di setup/hold sul bus dati `IO_sdram_dq` era insufficiente →
bit-error e parole duplicate sulle posizioni dispari, più un offset
deterministico (+9) introdotto dalla latenza interna del SIP non assorbita.
Portando la frequenza a quella per cui il SIP Gowin è caratterizzato
(~40 MHz) entrambi i problemi sono spariti.

### Configurazione rPLL definitiva (`src/gowin_rpll/gowin_rpll.vhd`)

Clock di ingresso: 27 MHz. Formula reale del primitivo `rPLL` (rivelata
dall'errore EX0311 del tool):

```
VCO    = FCLKIN * (FBDIV_SEL+1) * ODIV_SEL / (IDIV_SEL+1)   [valido 500–1250 MHz]
CLKOUT = FCLKIN * (FBDIV_SEL+1) / (IDIV_SEL+1)
```

| Parametro | Valore | Note |
|-----------|--------|------|
| `FCLKIN` | `"27"` | clock cristallo Tang Nano 20K |
| `IDIV_SEL` | `1` | divisore ingresso = 2 |
| `FBDIV_SEL` | `2` | moltiplicatore feedback = 3 |
| `ODIV_SEL` | `16` | divisore uscita |
| `PSDA_SEL` | `"0001"` | phase-shift statico 22.5° su CLKOUTP (clock SDRAM) |
| `DYN_DA_EN` | `"false"` | phase-shift statico |
| `DUTYDA_SEL` | `"1000"` | duty 50% |
| `FDLY` | `"1111"` | fine-delay feedback (come reference `gw_pll.v`) |
| `CLKFB_SEL` | `"internal"` | feedback interno |

Risultato: VCO = 27·3·16/2 = **648 MHz** (in range), **CLKOUT = 40.5 MHz**.
- `clkout`  → `clk_sdram`  : clock logica controller SIP (`I_sdrc_clk`)
- `clkoutp` → `clk_sdram_p`: clock fisico SDRAM, sfasato 22.5° (`I_sdram_clk`)

Conseguenza: ricalibrato il divisore baud della UART di test in
`top.vhd` (process baud tick): `tst_baud_cnt = 351` → 40.5 MHz / 352 ≈
115 200 baud. (Le UART `boot_tx`/`rtx` restano su `clk_i` = 27 MHz.)

### Come funziona la FSM di test (`top.vhd`, process su `clk_sdram`)

FSM `tst_st` con stati `TS_INIT, TS_WRITE_WAIT, TS_WRITE, TS_READ_WAIT,
TS_READ, TS_TX_WORD, TS_TX_CRLF, TS_PAUSE`. Replica `sdrc_interface_used.v`.

1. **TS_INIT** — `wr_n=rd_n=1`, `tst_wr_data=0`. Attende `O_sdrc_init_done`
   poi conta 200 000 cicli (margine di stabilizzazione SIP) → `TS_WRITE_WAIT`.
2. **TS_WRITE_WAIT** — appena `busy_n=1`: pulsa `wr_n=0` per **1 ciclo**,
   imposta `addr = {bank=2, row=2, col=5}` (`"100000000010000000101"`),
   azzera il contatore → `TS_WRITE`.
3. **TS_WRITE** — `wr_n` torna a 1; `tst_wr_data` incrementa di 1 ad ogni
   ciclo (0→1→2…); dopo 29 cicli (`timeout=28`) → `TS_READ_WAIT`. Il SIP
   bufferizza i dati nella sua FIFO interna durante la sequenza.
   `data_len = 0x19` (25) ⇒ burst di **26 parole**.
4. **TS_READ_WAIT** — appena `busy_n=1`: pulsa `rd_n=0` per 1 ciclo, stesso
   `addr` del write, azzera l'indice di cattura → `TS_READ`.
5. **TS_READ** — attende 200 cicli mentre, in parallelo nello stesso process,
   ogni `O_sdrc_rd_valid` campiona `O_sdrc_data` in `tst_rd_arr2[0..25]`.
6. **TS_TX_WORD / TS_TX_CRLF** — serializza le 26 parole in esadecimale ASCII
   sulla UART, poi CR/LF.
7. **TS_PAUSE** — stato finale (loop singolo).

Wiring SIP (`u_sdram_direct`): `I_sdrc_clk=clk_sdram`,
`I_sdram_clk=clk_sdram_p`, `I_sdrc_rst_n=pll_lock`,
`I_sdrc_data_len=x"19"`, dati `tst_wr_data`/`tst_rd_data`.

### Riepilogo fix di oggi

| # | Problema | Sintomo | Fix |
|---|----------|---------|-----|
| 10 | Freq SDRAM 108 MHz fuori caratterizzazione SIP | bit-flip + duplicati su posizioni dispari, offset +9 | rPLL → 40.5 MHz (IDIV=1, FBDIV=2, ODIV=16) |
| 11 | Baud divisore tarato per 108 MHz | UART illeggibile a 40.5 MHz | `tst_baud_cnt` 936 → 351 |
| 12 | `FDLY="0000"` ≠ reference | (nessun effetto isolato) | `FDLY="1111"` come `gw_pll.v` |
| 13 | `rd_valid` alto 2 cicli su una parola | ultima parola (0x1A) persa, 0x19 duplicato | (tentativo edge-detect: rompeva tutto → rollback. Difetto minore rinviato) |

### Espansione test: 520 parole (20 burst × 26)

Il SIP Gowin lavora a burst (reference: `data_len=25` ⇒ 26 parole/burst).
Per testare 512 parole si itera il pattern da 26 su più righe SDRAM:
**20 burst × 26 = 520 parole** (≥ 512).

- Nuovi: `tst_burst` (0..19), `TST_NBURST=20`. Array di cattura resta da 26.
- Indirizzo per burst k: `{bank=2, row=2+k, col=5}` (1 riga distinta/burst,
  26 colonne ben dentro le 256 della riga).
- Dato base burst k = `k*26` ⇒ sequenza globale riletta continua 1…520.
- Flusso: **fase WRITE** (burst 0→19 tutti scritti in SDRAM) → **fase READ**
  (burst 0→19 riletti e stampati via UART subito, array da 26 riusato).
- Esito primo test 520: sequenza globale continua e corretta `0x0B…0x207`
  (520 valori). Difetti residui: (a) il **primo burst** perdeva i primi ~10
  valori — la prima lettura partiva subito dopo la raffica di 20 scritture
  con SIP ancora occupato; (b) duplicato ultima parola/burst (difetto #13,
  rinviato).
- Fix (a) tentativo 1: stato `TS_WRITE_DONE` con attesa 200 000 cicli tra
  fase WRITE e fase READ → **nessun effetto** (output invariato). Il primo
  burst veniva corrotto NON dopo, ma DURANTE i 20 write back-to-back: il
  SIP non completa la scrittura della riga del burst 0 prima che parta il
  write del burst 1.
- Fix (a) tentativo 2: adottato il **pattern del reference Gowin**
  (`sdrc_interface_used.v`: write/read alternati per burst). Output
  **invariato** → il problema NON era nel pattern di accesso SDRAM.
- **Diagnosi corretta**: la SDRAM scrive/rilegge 520 parole in modo
  perfetto (1…520). I "primi 10 mancanti" del burst 0 NON sono persi in
  memoria: sono persi nella **UART di test** che all'avvio assoluto perde
  ~10 caratteri durante la sincronizzazione del baud (bug #5, transitorio
  iniziale TX). Nell'output si vede una valanga di garbage prima di
  `0000000B`: i valori `01`…`0A` sono lì dentro, corrotti dalla TX.
- Fix (a) definitivo: nuovo stato `TS_PREAMBLE` — prima del burst 0 la TX
  invia 40 caratteri spazio sacrificali che assorbono il transitorio di
  sincronizzazione; i dati reali partono a UART stabile. Pattern SDRAM
  resta write/read alternato per burst (robusto, come reference);
  `TS_WRITE_DONE` stato morto innocuo.

**Test SDRAM 520 parole funzionante** via UART (preambolo + 1…520 continui).

### Fix #13 — ultima parola/burst duplicata

Il difetto colpiva sempre e solo l'**ultima** (26ª) parola del burst:
`…0x18 0x19 0x19` invece di `…0x18 0x19 0x1A`. Le prime 25 sempre corrette.
Tentativo precedente (edge-detect su `rd_valid`) → portava tutto a 0:
**scartato e vietato**.

Fix a rischio minimo, **senza toccare la logica di cattura raw**: alzato
il burst del SIP da 26 a 27 parole (`I_sdrc_data_len: x"19"→x"1A"`). Il
problema resta confinato all'ultima parola del burst (ora la 27ª); la
cattura prende solo le prime 26 (`if tst_idx < 26`, già esistente) quindi
la 27ª difettosa è semplicemente ignorata. `TS_WRITE` incrementa già 29
volte ⇒ dati sufficienti per 27 parole. Dato base burst k = `k*26`
invariato ⇒ sequenza globale resta continua 1…520, **senza duplicati**.

Esito: #13 **risolto** — sequenza pulita senza duplicati fino a `0x208`
(520). Resta solo il transitorio UART del burst 0 (preambolo 40 troppo
corto: il transitorio si estende ~10 valori dentro il burst 0).
Fix: preambolo allungato a **256 caratteri** (`tst_wrd_cnt` esteso a
range 0..511) per coprire l'intero transitorio di avvio TX.

### Fix #14 — burst 0 perde i primi 10 valori (1a transazione "fredda")

Preambolo 256 **non risolve**: il burst 0 parte sempre da `0x0B`. Quindi
NON è la UART — è la SDRAM: la **primissima transazione write dopo init**
è "fredda" (pipeline interna del SIP non calda) e perde i primi 10 dati.
Tutti i burst successivi (1…19) perfetti. (Confermato: la vecchia versione
a singolo burst leggeva `1` correttamente perché… in realtà il problema
emerge col loop multi-burst: la 1a transazione assoluta resta difettosa.)

Fix: **burst di warm-up** — un write+read scartato su una riga dummy
(`row=1`) prima del loop reale, per "scaldare" la pipeline del SIP.
Signal `tst_warm` ('1' iniziale): primo giro `TS_WRITE_WAIT→TS_WRITE→
TS_READ_WAIT→TS_READ` su riga 1, poi `tst_warm<='0'`, `tst_burst<=0` e si
salta la TX (warm-up non stampato). I 20 burst reali (righe 2…21) partono
a pipeline calda. Nessuna modifica alla cattura raw né al timing core.

**Conclusione test SDRAM:** scrittura+lettura di 520 parole consecutive
(>512) su 20 righe SDRAM, sequenza pulita 1…520 — **completo e verificato**.

---

## 2026-05-19 — Refactor: dati FFT reali in SDRAM (pipeline DMA)

**Obiettivo:** sostituire il test SDRAM con la pipeline reale — il DMA
scrive i 512 risultati FFT (`fft_result_buf`) in SDRAM con la **stessa
procedura collaudata** (warm-up + burst + pattern reference), poi su IRQ
una FSM nel top li rilegge e li stampa via UART. Scelta architetturale
(utente): spostare la logica SDRAM **dentro il DMA** e far girare il DMA
alla frequenza del SIP (**40.5 MHz**), scalando le temporizzazioni ×1.5.

Refactor a 3 fasi (per non sprecare i lunghi build):

### Fase 1 — DMA+SPI a clk_sdram (40.5 MHz)
- `top.vhd`: `u_dma` e `u_spi` da `clk_i` (27 MHz) → `clk_sdram` (40.5 MHz).
- `spi_master.vhd`: `PRESCALER 36 → 54` (×1.5) ⇒ fSCK = 40.5e6/54 =
  750 kHz, identica all'originale 27e6/36.
- `wb_interconnect` è combinatorio (nessun clock) ⇒ niente CDC sul bus;
  DMA↔SPI ora stesso dominio. Nessun master CPU attivo (DMA auto-start).
- FSM test SDRAM lasciata attiva: output UART deve restare i 520 valori
  → conferma sistema stabile. **Verifica chiave: il P&R deve chiudere il
  timing dell'IP FFT a 40.5 MHz** (rischio isolato prima delle fasi 2-3).
- Esito: UART = 520 valori ok (sistema regge 40.5 MHz). IP FFT "swept"
  (eliminato): atteso, perché senza pipeline reale non ha output → il suo
  timing si verificherà solo in Fase 2/3 (quando i risultati FFT vanno
  davvero in SDRAM→UART e l'IP non è più logica morta).

### Fase 2 — logica write SDRAM dentro il DMA (`dma.vhd`)
- Nuove porte DMA→SIP: `sdr_own_o, sdr_wr_n_o, sdr_addr_o, sdr_data_o`,
  ingressi `sdr_busy_n_i, sdr_initdone_i`.
- `FS_DRAIN` (scriveva via WB un valore di test fisso) **sostituito** da
  `FS_SDR_SETTLE → FS_SDR_WW → FS_SDR_W`: replica esatta della procedura
  collaudata (settle init+200k, warm-up write-only riga 1, 20 burst×26 su
  righe 2+k, `data_len` SIP = 0x1A). Sorgente dato = `fft_result_buf`
  (16-bit esteso a 32: `x"0000" & buf`), indice `buf_idx` clamp 0..511.
- A fine scrittura: `FS_IRQ` pulsa `irq_o`, rilascia il SIP (`sdr_own=0`),
  `sdr_done=1` ⇒ **un solo ciclo** di scrittura SDRAM (evita il conflitto
  SIP fra write-DMA e read-top finché non aggiungiamo l'handshake).

### Fase 3 — lettura su IRQ + UART (`top.vhd`)
- SIP **muxato**: `sdr_own=1` ⇒ lo pilota il DMA (write); `=0` ⇒ la FSM
  top (read). Tutto su `clk_sdram` ⇒ nessun CDC, `dma_irq` stesso dominio.
- FSM `tst_st` resa **read-only**: `TS_INIT` attende il fronte di
  `dma_irq` → `TS_PREAMBLE` (256 spazi) → 20× (`TS_READ_WAIT/TS_READ`
  riga 2+k → `TS_TX_WORD/CRLF`) → `TS_PAUSE → TS_INIT` (riarmo). Niente
  più write/contatore/warm-up nel top (il warm-up è write-only nel DMA).
- Atteso UART: `FPGA ON` + preambolo + 520 valori = **i risultati reali
  dell'FFT** (`xk_re` a 16-bit, formato `0000XXXX`), una volta sola.
- Verifica: P&R con FFT non più swept (timing 40.5 MHz reale); i valori
  riflettono il segnale ADC (silenzio ⇒ valori piccoli).
- Esito 1° build Fasi 2-3: pipeline **funzionante** — 520 valori puliti
  via UART (write-DMA + read-top + SDRAM ok), FFT non più swept. MA tutti
  i valori ≈ `0000FFFC` (−4): nessun bin0 alto atteso per input ≈ costante.

### Fix off-by-one bin0
Il SIP scarta il valore presentato in `TS_WRITE_WAIT`/`FS_SDR_WW` e scrive
dal 1° presentato in `*_W` (nel test mascherato: dati = contatore, base=0
→ si leggeva 1,2,…). Con sorgente `fft_result_buf` questo **scartava
`fft_result_buf[0]` = bin0** (il valore grande per input quasi-costante).
I `0000FFFx` osservati erano i bin 1…511 ≈ 0 (rumore). Fix: in `FS_SDR_W`
indice dato = `buf_idx(burst, sdr_widx)` invece di `sdr_widx+1` → il 1°
valore scritto/letto è `fft_result_buf[0]`.
- Timing core invariato (29 cicli `TS_WRITE`, 200 `TS_READ`, cattura raw,
  PLL 40.5 MHz, baud 351): aggiunto solo il loop di burst e l'indirizzo
  dinamico in `TS_WRITE_WAIT`/`TS_READ_WAIT`, con ritorno burst da
  `TS_WRITE` (write successivo) e da `TS_TX_CRLF` (read successivo).
