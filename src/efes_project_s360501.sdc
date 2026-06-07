//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11.03 Education 
//Created Time: 2026-04-22 20:40:16
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk_i}]

// clk_sdram = uscita del PLL = clk_i * (FBDIV_SEL+1)/(IDIV_SEL+1) = 27 * 3/2 = 40.5 MHz
// (periodo 24.691 ns). Questo dominio porta CPU, bus, tutte le UART/SPI e flash_ctrl.
// Prima MANCAVA il vincolo: senza, il place&route non garantiva i 40.5 MHz -> i path
// marginali (campionamento UART RX, SPI) erano al limite e cambiavano ad ogni sintesi
// (comportamento flaky). Con questo il P&R DEVE rispettare i 40.5 MHz.
create_generated_clock -name clk_sdram -source [get_ports {clk_i}] -master_clock clk -multiply_by 3 -divide_by 2 [get_nets {clk_sdram}]
