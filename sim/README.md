# EFES — testbench per le waveform reali (time diagram)

Queste testbench servono a generare i **diagrammi temporali REALI** dei componenti
(simulati da GHDL), da mettere nel report al posto di quelli disegnati a mano.

## Come eseguire
Serve **GHDL** (gia' usato nel progetto). Da questa cartella:

```sh
sh run.sh
```

Genera quattro file VCD. GHDL mette nel VCD **tutti** i segnali della gerarchia,
quindi in GTKWave si vedono anche i segnali **interni** del componente sotto test
(sotto `tb_xxx` → `uut` → ...).

## Come vedere e ESPORTARE l'immagine per il report
```sh
gtkwave tb_pwm.vcd
```
In GTKWave: trascina i segnali interessanti nel pannello, regola lo zoom, poi
**File → Grab To File** (PNG) oppure **File → Print → to PDF**. L'immagine va poi
inclusa nel `.tex` con `\includegraphics`.

## Le quattro testbench

| File | Componente | Cosa guardare in GTKWave |
|---|---|---|
| `tb_pwm.vhd` | `PWM_GENERIC` (DDS speaker) | `pwm` (uscita), e sotto `uut`: accumulatore di fase DDS, stato inviluppo (attack/on/release), uscita LUT seno. Run 3 ms: **zooma sull'inizio** per vedere l'attacco. |
| `tb_uart.vhd` | `UART_GENERIC` (caratteri) | `tx`: start-bit (0) + 8 bit **LSB-first** + stop (1). Trasmette `0x55` ('U', bit alternati) poi `0x61` ('a'). |
| `tb_spi_adc.vhd` | `SPI_Master` (ADC) | `cs`, `sck`, `mosi`, `miso`, `data_ready` + `dat_o`: una transazione SPI di lettura. MISO presenta un pattern noto (0xA5C3). |
| `tb_flash_spi.vhd` | `SPI_Flash` (motore SPI NOR) | `sck`, `mosi`, `miso`, `busy`, `done`, `rxb`: comando JEDEC `0x9F` + 3 byte dummy; il modello MISO risponde `EF 40 17` (ID Winbond W25Q64). Mode 0, MSB-first, SCK=clk/64. |
| `tb_sdram.vhd` (+ `sdram_sip_model.vhd`) | SDRAM lato utente (modello) | `init_done`, `busy_n`, `wr_n`, `rd_n`, `addr`, `wdata`, `wrd_ack`, `rd_valid`, `rdata`: init, poi WRITE burst di 8 parole (wr_n + dati + wrd_ack) e READ burst (rd_n + rd_valid + rdata). Mostra parole/burst/cicli di attesa dell'handshake. |

Nota sui "modelli": in simulazione non abbiamo il chip NOR vero ne' la SDRAM vera
(e il controller SDRAM e' un IP Verilog non simulabile da GHDL). Come per la flash
SPI, **fingiamo** la risposta: il modello MISO della NOR risponde con l'ID JEDEC, e
`sdram_sip_model` fa da finto controller SDRAM con una piccola RAM interna. Quello
che le testbench mostrano e' quindi il **protocollo lato nostro** (quante parole,
quanti burst, quanti cicli di attesa, gli handshake), che e' la parte reale del
nostro RTL; le latenze esatte del chip/IP esterno sono ovviamente del modello.

Nota: la testbench dell'intero `flash_ctrl` NON e' inclusa perche' al boot fa lo
scan di 512 slot (≈32 ms di simulazione, VCD enorme): per il timing SPI della NOR
basta `tb_flash_spi`, che mostra il singolo trasferimento a byte usato dalla FSM.

`tb_pwm.vcd` e' grande (~10 MB) per via dei 3 ms a 27 MHz: se serve piu' leggero,
riduci il `wait for` in `tb_pwm.vhd` (es. 0.5 ms) e rilancia `run.sh`.
