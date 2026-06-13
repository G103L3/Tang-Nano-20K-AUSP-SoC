//Copyright (C)2014-2026 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12.02_SP2
//IP Version: 1.4
//Part Number: GW2AR-LV18QN88C8/I7
//Device: GW2AR-18
//Device Version: C
//Created Time: Sat Jun 13 00:49:09 2026

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	Gowin_PicoRV32_Top your_instance_name(
		.ser_tx(ser_tx), //output ser_tx
		.ser_rx(ser_rx), //input ser_rx
		.slv_ext_stb_o(slv_ext_stb_o), //output slv_ext_stb_o
		.slv_ext_we_o(slv_ext_we_o), //output slv_ext_we_o
		.slv_ext_cyc_o(slv_ext_cyc_o), //output slv_ext_cyc_o
		.slv_ext_ack_i(slv_ext_ack_i), //input slv_ext_ack_i
		.slv_ext_adr_o(slv_ext_adr_o), //output [31:0] slv_ext_adr_o
		.slv_ext_wdata_o(slv_ext_wdata_o), //output [31:0] slv_ext_wdata_o
		.slv_ext_rdata_i(slv_ext_rdata_i), //input [31:0] slv_ext_rdata_i
		.slv_ext_sel_o(slv_ext_sel_o), //output [3:0] slv_ext_sel_o
		.irq_in(irq_in), //input [31:20] irq_in
		.jtag_TDI(jtag_TDI), //input jtag_TDI
		.jtag_TDO(jtag_TDO), //output jtag_TDO
		.jtag_TCK(jtag_TCK), //input jtag_TCK
		.jtag_TMS(jtag_TMS), //input jtag_TMS
		.clk_in(clk_in), //input clk_in
		.resetn_in(resetn_in) //input resetn_in
	);

//--------Copy end-------------------
