--Copyright (C)2014-2025 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.11.03 Education
--Part Number: GW2AR-LV18QN88C8/I7
--Device: GW2AR-18
--Device Version: C
--Created Time: Thu Apr 16 00:16:49 2026

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component Gowin_PicoRV32_Top
	port (
		ser_tx: out std_logic;
		ser_rx: in std_logic;
		slv_ext_stb_o: out std_logic;
		slv_ext_we_o: out std_logic;
		slv_ext_cyc_o: out std_logic;
		slv_ext_ack_i: in std_logic;
		slv_ext_adr_o: out std_logic_vector(31 downto 0);
		slv_ext_wdata_o: out std_logic_vector(31 downto 0);
		slv_ext_rdata_i: in std_logic_vector(31 downto 0);
		slv_ext_sel_o: out std_logic_vector(3 downto 0);
		irq_in: in std_logic_vector(31 downto 20);
		jtag_TDI: in std_logic;
		jtag_TDO: out std_logic;
		jtag_TCK: in std_logic;
		jtag_TMS: in std_logic;
		clk_in: in std_logic;
		resetn_in: in std_logic
	);
end component;

your_instance_name: Gowin_PicoRV32_Top
	port map (
		ser_tx => ser_tx,
		ser_rx => ser_rx,
		slv_ext_stb_o => slv_ext_stb_o,
		slv_ext_we_o => slv_ext_we_o,
		slv_ext_cyc_o => slv_ext_cyc_o,
		slv_ext_ack_i => slv_ext_ack_i,
		slv_ext_adr_o => slv_ext_adr_o,
		slv_ext_wdata_o => slv_ext_wdata_o,
		slv_ext_rdata_i => slv_ext_rdata_i,
		slv_ext_sel_o => slv_ext_sel_o,
		irq_in => irq_in,
		jtag_TDI => jtag_TDI,
		jtag_TDO => jtag_TDO,
		jtag_TCK => jtag_TCK,
		jtag_TMS => jtag_TMS,
		clk_in => clk_in,
		resetn_in => resetn_in
	);

----------Copy end-------------------
