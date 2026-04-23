//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.11.03 Education 
//Created Time: 2026-04-22 20:40:16
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk_i}]
create_clock -name jatag_clk -period 100 -waveform {0 50} [get_ports {jtag_tck}]
