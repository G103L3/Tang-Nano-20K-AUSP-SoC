--Copyright (C)2014-2025 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--Tool Version: V1.9.11.03 Education
--Part Number: GW2AR-LV18QN88C8/I7
--Device: GW2AR-18
--Device Version: C
--Created Time: Mon Apr 20 20:15:12 2026

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component FFT_Top
	port (
		idx: out std_logic_vector(8 downto 0);
		xk_re: out std_logic_vector(15 downto 0);
		xk_im: out std_logic_vector(15 downto 0);
		sod: out std_logic;
		ipd: out std_logic;
		eod: out std_logic;
		busy: out std_logic;
		soud: out std_logic;
		opd: out std_logic;
		eoud: out std_logic;
		xn_re: in std_logic_vector(15 downto 0);
		xn_im: in std_logic_vector(15 downto 0);
		start: in std_logic;
		clk: in std_logic;
		rst: in std_logic
	);
end component;

your_instance_name: FFT_Top
	port map (
		idx => idx,
		xk_re => xk_re,
		xk_im => xk_im,
		sod => sod,
		ipd => ipd,
		eod => eod,
		busy => busy,
		soud => soud,
		opd => opd,
		eoud => eoud,
		xn_re => xn_re,
		xn_im => xn_im,
		start => start,
		clk => clk,
		rst => rst
	);

----------Copy end-------------------
