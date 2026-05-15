--
--Written by GowinSynthesis
--Tool Version "V1.9.12.02_SP2"
--IP Version: 1.0
--Sat May  9 19:31:10 2026

--Source file index table:
--file0 "\/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/ipcore/SDRC_HS/data/SDRAM_Controller_HS_Top.v"
--file1 "\/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/ipcore/SDRC_HS/data/sdrc_hs_top.vp"
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library gw2a;
use gw2a.components.all;

entity SDRAM_Controller_HS_Top is
port(
  O_sdram_clk :  out std_logic;
  O_sdram_cke :  out std_logic;
  O_sdram_cs_n :  out std_logic;
  O_sdram_cas_n :  out std_logic;
  O_sdram_ras_n :  out std_logic;
  O_sdram_wen_n :  out std_logic;
  O_sdram_dqm :  out std_logic_vector(3 downto 0);
  O_sdram_addr :  out std_logic_vector(10 downto 0);
  O_sdram_ba :  out std_logic_vector(1 downto 0);
  IO_sdram_dq :  inout std_logic_vector(31 downto 0);
  I_sdrc_rst_n :  in std_logic;
  I_sdrc_clk :  in std_logic;
  I_sdram_clk :  in std_logic;
  I_sdrc_cmd_en :  in std_logic;
  I_sdrc_cmd :  in std_logic_vector(2 downto 0);
  I_sdrc_precharge_ctrl :  in std_logic;
  I_sdram_power_down :  in std_logic;
  I_sdram_selfrefresh :  in std_logic;
  I_sdrc_addr :  in std_logic_vector(20 downto 0);
  I_sdrc_dqm :  in std_logic_vector(3 downto 0);
  I_sdrc_data :  in std_logic_vector(31 downto 0);
  I_sdrc_data_len :  in std_logic_vector(7 downto 0);
  O_sdrc_data :  out std_logic_vector(31 downto 0);
  O_sdrc_init_done :  out std_logic;
  O_sdrc_cmd_ack :  out std_logic);
end SDRAM_Controller_HS_Top;
architecture beh of SDRAM_Controller_HS_Top is
  signal u_sdrc_hs_top_U_ODDR_clk : std_logic ;
  signal \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_PRECHARGEALL\ : std_logic ;
  signal \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH1\ : std_logic ;
  signal \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH2\ : std_logic ;
  signal \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG\ : std_logic ;
  signal \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_PRECHARGE_DELAY\ : std_logic ;
  signal \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH1_DELAY\ : std_logic ;
  signal \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH2_DELAY\ : std_logic ;
  signal \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG_DELAY\ : std_logic ;
  signal \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_INIT_DONE\ : std_logic ;
  signal \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_IDLE\ : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Precharge_flag : std_logic ;
  signal \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_AUTOREFRESH_DELAY\ : std_logic ;
  signal \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\ : std_logic ;
  signal \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_ACTIVE2RW_DELAY\ : std_logic ;
  signal \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\ : std_logic ;
  signal \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\ : std_logic ;
  signal \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\ : std_logic ;
  signal \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_PRECHARGE_DELAY\ : std_logic ;
  signal \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_INIT\ : std_logic ;
  signal \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_POWER_DOWN\ : std_logic ;
  signal \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH\ : std_logic ;
  signal \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH_WAIT\ : std_logic ;
  signal \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH_EXIT\ : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_wen_n : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_cas_n : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_ras_n : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid : std_logic ;
  signal u_sdrc_hs_top_n26 : std_logic ;
  signal u_sdrc_hs_top_n26_2 : std_logic ;
  signal u_sdrc_hs_top_n25 : std_logic ;
  signal u_sdrc_hs_top_n25_2 : std_logic ;
  signal u_sdrc_hs_top_n24 : std_logic ;
  signal u_sdrc_hs_top_n24_2 : std_logic ;
  signal u_sdrc_hs_top_n23 : std_logic ;
  signal u_sdrc_hs_top_n23_2 : std_logic ;
  signal u_sdrc_hs_top_n22 : std_logic ;
  signal u_sdrc_hs_top_n22_2 : std_logic ;
  signal u_sdrc_hs_top_n21 : std_logic ;
  signal u_sdrc_hs_top_n21_2 : std_logic ;
  signal u_sdrc_hs_top_n20 : std_logic ;
  signal u_sdrc_hs_top_n20_2 : std_logic ;
  signal u_sdrc_hs_top_n19 : std_logic ;
  signal u_sdrc_hs_top_n19_2 : std_logic ;
  signal u_sdrc_hs_top_n18 : std_logic ;
  signal u_sdrc_hs_top_n18_2 : std_logic ;
  signal u_sdrc_hs_top_n17 : std_logic ;
  signal u_sdrc_hs_top_n17_2 : std_logic ;
  signal u_sdrc_hs_top_n16 : std_logic ;
  signal u_sdrc_hs_top_n16_2 : std_logic ;
  signal u_sdrc_hs_top_n15 : std_logic ;
  signal u_sdrc_hs_top_n15_2 : std_logic ;
  signal u_sdrc_hs_top_n14 : std_logic ;
  signal u_sdrc_hs_top_n14_2 : std_logic ;
  signal u_sdrc_hs_top_n13 : std_logic ;
  signal u_sdrc_hs_top_n13_2 : std_logic ;
  signal u_sdrc_hs_top_n12 : std_logic ;
  signal u_sdrc_hs_top_n12_2 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_cke : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Reset_cmd_count : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n178 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n179 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n180 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n181 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n182 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n183 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n184 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n185 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n991 : std_logic ;
  signal u_sdrc_hs_top_n204 : std_logic ;
  signal u_sdrc_hs_top_n206 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_8 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n79 : std_logic ;
  signal u_sdrc_hs_top_n159 : std_logic ;
  signal u_sdrc_hs_top_n161 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n995 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1001 : std_logic ;
  signal u_sdrc_hs_top_n155 : std_logic ;
  signal u_sdrc_hs_top_n157 : std_logic ;
  signal u_sdrc_hs_top_n163 : std_logic ;
  signal u_sdrc_hs_top_n165 : std_logic ;
  signal u_sdrc_hs_top_n167 : std_logic ;
  signal u_sdrc_hs_top_n169 : std_logic ;
  signal u_sdrc_hs_top_n171 : std_logic ;
  signal u_sdrc_hs_top_n173 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n578 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n580 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n582 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n584 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n586 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n588 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n590 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n592 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n594 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n596 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n600 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n602 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n998 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1003 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1005 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1007 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1009 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1011 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1013 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1015 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1017 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1019 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1021 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1023 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1025 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1027 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n79_27 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n604 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n610 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n616 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_O_sdram_cke : std_logic ;
  signal u_sdrc_hs_top_n65 : std_logic ;
  signal u_sdrc_hs_top_n64 : std_logic ;
  signal u_sdrc_hs_top_n63 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n85 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n84 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n83 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n99 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n98 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n97 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n178_4 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n178_5 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n179_4 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n179_5 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n180_4 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n180_5 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n181_4 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n181_5 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n182_4 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n182_5 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n183_4 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n183_5 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n184_4 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n991_4 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9 : std_logic ;
  signal u_sdrc_hs_top_n159_17 : std_logic ;
  signal u_sdrc_hs_top_n159_18 : std_logic ;
  signal u_sdrc_hs_top_n159_19 : std_logic ;
  signal u_sdrc_hs_top_n161_17 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n995_17 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n995_18 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n995_19 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1001_17 : std_logic ;
  signal u_sdrc_hs_top_n157_17 : std_logic ;
  signal u_sdrc_hs_top_n157_18 : std_logic ;
  signal u_sdrc_hs_top_n165_18 : std_logic ;
  signal u_sdrc_hs_top_n165_19 : std_logic ;
  signal u_sdrc_hs_top_n167_18 : std_logic ;
  signal u_sdrc_hs_top_n173_18 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n578_32 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n580_26 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n580_27 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n580_28 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n580_29 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n582_32 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n582_33 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n584_31 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n588_27 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n590_27 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n590_28 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n594_28 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n596_28 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n998_18 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n998_19 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1003_19 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1005_19 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1007_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1009_19 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1011_19 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1013_19 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1015_19 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1017_19 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1017_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1019_19 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1019_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1021_19 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1023_19 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1025_19 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1027_19 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n79_29 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n604_15 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n608 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n610_13 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n614 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n757 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_O_sdram_cke_8 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n179_6 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_10 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_11 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n79_30 : std_logic ;
  signal u_sdrc_hs_top_n159_20 : std_logic ;
  signal u_sdrc_hs_top_n159_21 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n995_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n995_22 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1001_18 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n578_35 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n580_30 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n580_31 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n580_32 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n580_33 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n582_34 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n582_35 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n584_33 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n998_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n998_21 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1003_21 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1003_22 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1003_23 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1005_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1007_21 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1009_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1011_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1013_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1015_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1017_21 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1019_21 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1021_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1023_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1025_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1027_20 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n79_31 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_12 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_13 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_14 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n578_36 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n578_37 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n580_34 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n580_35 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n580_36 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n580_37 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n998_22 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n998_23 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1013_21 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1015_21 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1017_22 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1017_23 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1019_22 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1019_23 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1021_21 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1023_21 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1025_21 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1027_21 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n79_32 : std_logic ;
  signal u_sdrc_hs_top_n202 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n582_38 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n79_34 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n578_39 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1001_22 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n594_31 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n578_41 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n995_24 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1007_23 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n582_40 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1003_26 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n1001_24 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n584_35 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n757_9 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n594_33 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n618 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n614_15 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n612 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n608_15 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n606 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7_11 : std_logic ;
  signal u_sdrc_hs_top_n27 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n620 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n604_19 : std_logic ;
  signal u_sdrc_hs_top_n67 : std_logic ;
  signal u_sdrc_hs_top_n9 : std_logic ;
  signal u_sdrc_hs_top_n207 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0 : std_logic ;
  signal u_sdrc_hs_top_n66 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n86 : std_logic ;
  signal u_sdrc_hs_top_u_sdrc_control_fsm_n100 : std_logic ;
  signal u_sdrc_hs_top_Init_cnt_14 : std_logic ;
  signal GND_0 : std_logic ;
  signal VCC_0 : std_logic ;
  signal IO_sdram_dq_in : std_logic_vector(31 downto 0);
  signal \u_sdrc_hs_top/Init_cnt\ : std_logic_vector(15 downto 0);
  signal \u_sdrc_hs_top/Count_init_delay\ : std_logic_vector(3 downto 0);
  signal \u_sdrc_hs_top/Sdram_cmd_init\ : std_logic_vector(2 downto 0);
  signal \u_sdrc_hs_top/Sdram_ba_init\ : std_logic_vector(1 downto 1);
  signal \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\ : std_logic_vector(3 downto 0);
  signal \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\ : std_logic_vector(3 downto 0);
  signal \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\ : std_logic_vector(31 downto 0);
  signal \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\ : std_logic_vector(7 downto 0);
  signal \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_bk_wrd\ : std_logic_vector(1 downto 0);
  signal \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_ba\ : std_logic_vector(1 downto 0);
  signal \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\ : std_logic_vector(10 downto 0);
  signal \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\ : std_logic_vector(7 downto 0);
  signal \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\ : std_logic_vector(8 downto 0);
  signal NN : std_logic;
  signal NN_0 : std_logic;
begin
IO_sdram_dq_0_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(0),
  IO => IO_sdram_dq(0),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(0),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_1_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(1),
  IO => IO_sdram_dq(1),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(1),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_2_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(2),
  IO => IO_sdram_dq(2),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(2),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_3_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(3),
  IO => IO_sdram_dq(3),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(3),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_4_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(4),
  IO => IO_sdram_dq(4),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(4),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_5_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(5),
  IO => IO_sdram_dq(5),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(5),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_6_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(6),
  IO => IO_sdram_dq(6),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(6),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_7_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(7),
  IO => IO_sdram_dq(7),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(7),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_8_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(8),
  IO => IO_sdram_dq(8),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(8),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_9_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(9),
  IO => IO_sdram_dq(9),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(9),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_10_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(10),
  IO => IO_sdram_dq(10),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(10),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_11_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(11),
  IO => IO_sdram_dq(11),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(11),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_12_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(12),
  IO => IO_sdram_dq(12),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(12),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_13_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(13),
  IO => IO_sdram_dq(13),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(13),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_14_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(14),
  IO => IO_sdram_dq(14),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(14),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_15_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(15),
  IO => IO_sdram_dq(15),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(15),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_16_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(16),
  IO => IO_sdram_dq(16),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(16),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_17_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(17),
  IO => IO_sdram_dq(17),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(17),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_18_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(18),
  IO => IO_sdram_dq(18),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(18),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_19_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(19),
  IO => IO_sdram_dq(19),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(19),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_20_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(20),
  IO => IO_sdram_dq(20),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(20),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_21_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(21),
  IO => IO_sdram_dq(21),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(21),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_22_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(22),
  IO => IO_sdram_dq(22),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(22),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_23_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(23),
  IO => IO_sdram_dq(23),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(23),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_24_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(24),
  IO => IO_sdram_dq(24),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(24),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_25_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(25),
  IO => IO_sdram_dq(25),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(25),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_26_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(26),
  IO => IO_sdram_dq(26),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(26),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_27_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(27),
  IO => IO_sdram_dq(27),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(27),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_28_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(28),
  IO => IO_sdram_dq(28),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(28),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_29_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(29),
  IO => IO_sdram_dq(29),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(29),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_30_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(30),
  IO => IO_sdram_dq(30),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(30),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
IO_sdram_dq_31_iobuf: IOBUF
port map (
  O => IO_sdram_dq_in(31),
  IO => IO_sdram_dq(31),
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(31),
  OEN => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0);
\u_sdrc_hs_top/U_ODDR_clk\: ODDR
port map (
  Q0 => O_sdram_clk,
  Q1 => u_sdrc_hs_top_U_ODDR_clk,
  D0 => VCC_0,
  D1 => GND_0,
  TX => VCC_0,
  CLK => I_sdram_clk);
\u_sdrc_hs_top/Init_cnt_14_s0\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(14),
  D => u_sdrc_hs_top_n13,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_Init_cnt_14,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_cnt_13_s0\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(13),
  D => u_sdrc_hs_top_n14,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_Init_cnt_14,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_cnt_12_s0\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(12),
  D => u_sdrc_hs_top_n15,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_Init_cnt_14,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_cnt_11_s0\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(11),
  D => u_sdrc_hs_top_n16,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_Init_cnt_14,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_cnt_10_s0\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(10),
  D => u_sdrc_hs_top_n17,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_Init_cnt_14,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_cnt_9_s0\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(9),
  D => u_sdrc_hs_top_n18,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_Init_cnt_14,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_cnt_8_s0\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(8),
  D => u_sdrc_hs_top_n19,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_Init_cnt_14,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_cnt_7_s0\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(7),
  D => u_sdrc_hs_top_n20,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_Init_cnt_14,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_cnt_6_s0\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(6),
  D => u_sdrc_hs_top_n21,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_Init_cnt_14,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_cnt_5_s0\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(5),
  D => u_sdrc_hs_top_n22,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_Init_cnt_14,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_cnt_4_s0\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(4),
  D => u_sdrc_hs_top_n23,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_Init_cnt_14,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_cnt_3_s0\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(3),
  D => u_sdrc_hs_top_n24,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_Init_cnt_14,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_cnt_2_s0\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(2),
  D => u_sdrc_hs_top_n25,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_Init_cnt_14,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_cnt_1_s0\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(1),
  D => u_sdrc_hs_top_n26,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_Init_cnt_14,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Count_init_delay_3_s0\: DFFR
port map (
  Q => \u_sdrc_hs_top/Count_init_delay\(3),
  D => u_sdrc_hs_top_n63,
  CLK => I_sdrc_clk,
  RESET => u_sdrc_hs_top_n67);
\u_sdrc_hs_top/Count_init_delay_2_s0\: DFFR
port map (
  Q => \u_sdrc_hs_top/Count_init_delay\(2),
  D => u_sdrc_hs_top_n64,
  CLK => I_sdrc_clk,
  RESET => u_sdrc_hs_top_n67);
\u_sdrc_hs_top/Count_init_delay_1_s0\: DFFR
port map (
  Q => \u_sdrc_hs_top/Count_init_delay\(1),
  D => u_sdrc_hs_top_n65,
  CLK => I_sdrc_clk,
  RESET => u_sdrc_hs_top_n67);
\u_sdrc_hs_top/Count_init_delay_0_s0\: DFFR
port map (
  Q => \u_sdrc_hs_top/Count_init_delay\(0),
  D => u_sdrc_hs_top_n66,
  CLK => I_sdrc_clk,
  RESET => u_sdrc_hs_top_n67);
\u_sdrc_hs_top/Cmd_init_state.INIT_STATE_PRECHARGEALL_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_PRECHARGEALL\,
  D => u_sdrc_hs_top_n155,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Cmd_init_state.INIT_STATE_AUTOREFRESH1_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH1\,
  D => u_sdrc_hs_top_n157,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Cmd_init_state.INIT_STATE_AUTOREFRESH2_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH2\,
  D => u_sdrc_hs_top_n159,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Cmd_init_state.INIT_STATE_LOAD_MODEREG_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG\,
  D => u_sdrc_hs_top_n161,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Cmd_init_state.INIT_STATE_PRECHARGE_DELAY_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_PRECHARGE_DELAY\,
  D => u_sdrc_hs_top_n165,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Cmd_init_state.INIT_STATE_AUTOREFRESH1_DELAY_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH1_DELAY\,
  D => u_sdrc_hs_top_n167,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Cmd_init_state.INIT_STATE_AUTOREFRESH2_DELAY_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH2_DELAY\,
  D => u_sdrc_hs_top_n169,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Cmd_init_state.INIT_STATE_LOAD_MODEREG_DELAY_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG_DELAY\,
  D => u_sdrc_hs_top_n171,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Cmd_init_state.INIT_STATE_INIT_DONE_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_INIT_DONE\,
  D => u_sdrc_hs_top_n173,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_finish_s0\: DFFC
port map (
  Q => NN_0,
  D => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_INIT_DONE\,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Sdram_cmd_init_2_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/Sdram_cmd_init\(2),
  D => u_sdrc_hs_top_n202,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/Sdram_cmd_init_1_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/Sdram_cmd_init\(1),
  D => u_sdrc_hs_top_n204,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/Sdram_cmd_init_0_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/Sdram_cmd_init\(0),
  D => u_sdrc_hs_top_n206,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/Sdram_ba_init_1_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/Sdram_ba_init\(1),
  D => u_sdrc_hs_top_n207,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/Cmd_init_state.INIT_STATE_IDLE_s0\: DFFP
port map (
  Q => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_IDLE\,
  D => u_sdrc_hs_top_n163,
  CLK => I_sdrc_clk,
  PRESET => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay_3_s0\: DFFR
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(3),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n83,
  CLK => I_sdrc_clk,
  RESET => u_sdrc_hs_top_u_sdrc_control_fsm_Reset_cmd_count);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay_2_s0\: DFFR
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(2),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n84,
  CLK => I_sdrc_clk,
  RESET => u_sdrc_hs_top_u_sdrc_control_fsm_Reset_cmd_count);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay_1_s0\: DFFR
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(1),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n85,
  CLK => I_sdrc_clk,
  RESET => u_sdrc_hs_top_u_sdrc_control_fsm_Reset_cmd_count);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay_0_s0\: DFFS
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(0),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n86,
  CLK => I_sdrc_clk,
  SET => u_sdrc_hs_top_u_sdrc_control_fsm_Reset_cmd_count);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2_3_s0\: DFFR
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(3),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n97,
  CLK => I_sdrc_clk,
  RESET => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2_2_s0\: DFFR
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(2),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n98,
  CLK => I_sdrc_clk,
  RESET => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2_1_s0\: DFFR
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(1),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n99,
  CLK => I_sdrc_clk,
  RESET => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2_0_s0\: DFFS
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(0),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n100,
  CLK => I_sdrc_clk,
  SET => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_31_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(31),
  D => I_sdrc_data(31),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_30_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(30),
  D => I_sdrc_data(30),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_29_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(29),
  D => I_sdrc_data(29),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_28_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(28),
  D => I_sdrc_data(28),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_27_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(27),
  D => I_sdrc_data(27),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_26_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(26),
  D => I_sdrc_data(26),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_25_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(25),
  D => I_sdrc_data(25),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_24_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(24),
  D => I_sdrc_data(24),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_23_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(23),
  D => I_sdrc_data(23),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_22_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(22),
  D => I_sdrc_data(22),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_21_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(21),
  D => I_sdrc_data(21),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_20_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(20),
  D => I_sdrc_data(20),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_19_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(19),
  D => I_sdrc_data(19),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_18_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(18),
  D => I_sdrc_data(18),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_17_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(17),
  D => I_sdrc_data(17),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_16_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(16),
  D => I_sdrc_data(16),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_15_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(15),
  D => I_sdrc_data(15),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_14_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(14),
  D => I_sdrc_data(14),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_13_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(13),
  D => I_sdrc_data(13),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_12_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(12),
  D => I_sdrc_data(12),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_11_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(11),
  D => I_sdrc_data(11),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_10_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(10),
  D => I_sdrc_data(10),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_9_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(9),
  D => I_sdrc_data(9),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_8_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(8),
  D => I_sdrc_data(8),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_7_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(7),
  D => I_sdrc_data(7),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_6_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(6),
  D => I_sdrc_data(6),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_5_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(5),
  D => I_sdrc_data(5),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_4_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(4),
  D => I_sdrc_data(4),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_3_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(3),
  D => I_sdrc_data(3),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_2_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(2),
  D => I_sdrc_data(2),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_1_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(1),
  D => I_sdrc_data(1),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data_0_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_data\(0),
  D => I_sdrc_data(0),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_dqm_3_s0\: DFF
port map (
  Q => O_sdram_dqm(3),
  D => I_sdrc_dqm(3),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_dqm_2_s0\: DFF
port map (
  Q => O_sdram_dqm(2),
  D => I_sdrc_dqm(2),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_dqm_1_s0\: DFF
port map (
  Q => O_sdram_dqm(1),
  D => I_sdrc_dqm(1),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_dqm_0_s0\: DFF
port map (
  Q => O_sdram_dqm(0),
  D => I_sdrc_dqm(0),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/Precharge_flag_s0\: DFFE
port map (
  Q => u_sdrc_hs_top_u_sdrc_control_fsm_Precharge_flag,
  D => I_sdrc_precharge_ctrl,
  CLK => I_sdrc_clk,
  CE => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len_7_s0\: DFFE
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(7),
  D => I_sdrc_data_len(7),
  CLK => I_sdrc_clk,
  CE => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len_6_s0\: DFFE
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(6),
  D => I_sdrc_data_len(6),
  CLK => I_sdrc_clk,
  CE => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len_5_s0\: DFFE
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(5),
  D => I_sdrc_data_len(5),
  CLK => I_sdrc_clk,
  CE => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len_4_s0\: DFFE
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(4),
  D => I_sdrc_data_len(4),
  CLK => I_sdrc_clk,
  CE => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len_3_s0\: DFFE
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(3),
  D => I_sdrc_data_len(3),
  CLK => I_sdrc_clk,
  CE => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len_2_s0\: DFFE
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(2),
  D => I_sdrc_data_len(2),
  CLK => I_sdrc_clk,
  CE => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len_1_s0\: DFFE
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(1),
  D => I_sdrc_data_len(1),
  CLK => I_sdrc_clk,
  CE => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len_0_s0\: DFFE
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(0),
  D => I_sdrc_data_len(0),
  CLK => I_sdrc_clk,
  CE => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_bk_wrd_1_s0\: DFFE
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_bk_wrd\(1),
  D => I_sdrc_addr(20),
  CLK => I_sdrc_clk,
  CE => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_bk_wrd_0_s0\: DFFE
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_bk_wrd\(0),
  D => I_sdrc_addr(19),
  CLK => I_sdrc_clk,
  CE => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/Cmd_fsm_state.SDRC_STATE_AUTOREFRESH_DELAY_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_AUTOREFRESH_DELAY\,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n578,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Cmd_fsm_state.SDRC_STATE_IDLE_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n580,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Cmd_fsm_state.SDRC_STATE_ACTIVE2RW_DELAY_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_ACTIVE2RW_DELAY\,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n582,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n584,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n586,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n588,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Cmd_fsm_state.SDRC_STATE_PRECHARGE_DELAY_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_PRECHARGE_DELAY\,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n590,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Cmd_fsm_state.SDRC_STATE_INIT_s0\: DFFP
port map (
  Q => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_INIT\,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n592,
  CLK => I_sdrc_clk,
  PRESET => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Cmd_fsm_state.SDRC_STATE_POWER_DOWN_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_POWER_DOWN\,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n594,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Cmd_fsm_state.SDRC_STATE_SELFREFRESH_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH\,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n596,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Cmd_fsm_state.SDRC_STATE_SELFREFRESH_WAIT_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH_WAIT\,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n600,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Cmd_fsm_state.SDRC_STATE_SELFREFRESH_EXIT_s0\: DFFC
port map (
  Q => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH_EXIT\,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n602,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_31_s0\: DFF
port map (
  Q => O_sdrc_data(31),
  D => IO_sdram_dq_in(31),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_30_s0\: DFF
port map (
  Q => O_sdrc_data(30),
  D => IO_sdram_dq_in(30),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_29_s0\: DFF
port map (
  Q => O_sdrc_data(29),
  D => IO_sdram_dq_in(29),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_28_s0\: DFF
port map (
  Q => O_sdrc_data(28),
  D => IO_sdram_dq_in(28),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_27_s0\: DFF
port map (
  Q => O_sdrc_data(27),
  D => IO_sdram_dq_in(27),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_26_s0\: DFF
port map (
  Q => O_sdrc_data(26),
  D => IO_sdram_dq_in(26),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_25_s0\: DFF
port map (
  Q => O_sdrc_data(25),
  D => IO_sdram_dq_in(25),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_24_s0\: DFF
port map (
  Q => O_sdrc_data(24),
  D => IO_sdram_dq_in(24),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_23_s0\: DFF
port map (
  Q => O_sdrc_data(23),
  D => IO_sdram_dq_in(23),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_22_s0\: DFF
port map (
  Q => O_sdrc_data(22),
  D => IO_sdram_dq_in(22),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_21_s0\: DFF
port map (
  Q => O_sdrc_data(21),
  D => IO_sdram_dq_in(21),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_20_s0\: DFF
port map (
  Q => O_sdrc_data(20),
  D => IO_sdram_dq_in(20),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_19_s0\: DFF
port map (
  Q => O_sdrc_data(19),
  D => IO_sdram_dq_in(19),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_18_s0\: DFF
port map (
  Q => O_sdrc_data(18),
  D => IO_sdram_dq_in(18),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_17_s0\: DFF
port map (
  Q => O_sdrc_data(17),
  D => IO_sdram_dq_in(17),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_16_s0\: DFF
port map (
  Q => O_sdrc_data(16),
  D => IO_sdram_dq_in(16),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_15_s0\: DFF
port map (
  Q => O_sdrc_data(15),
  D => IO_sdram_dq_in(15),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_14_s0\: DFF
port map (
  Q => O_sdrc_data(14),
  D => IO_sdram_dq_in(14),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_13_s0\: DFF
port map (
  Q => O_sdrc_data(13),
  D => IO_sdram_dq_in(13),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_12_s0\: DFF
port map (
  Q => O_sdrc_data(12),
  D => IO_sdram_dq_in(12),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_11_s0\: DFF
port map (
  Q => O_sdrc_data(11),
  D => IO_sdram_dq_in(11),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_10_s0\: DFF
port map (
  Q => O_sdrc_data(10),
  D => IO_sdram_dq_in(10),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_9_s0\: DFF
port map (
  Q => O_sdrc_data(9),
  D => IO_sdram_dq_in(9),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_8_s0\: DFF
port map (
  Q => O_sdrc_data(8),
  D => IO_sdram_dq_in(8),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_7_s0\: DFF
port map (
  Q => O_sdrc_data(7),
  D => IO_sdram_dq_in(7),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_6_s0\: DFF
port map (
  Q => O_sdrc_data(6),
  D => IO_sdram_dq_in(6),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_5_s0\: DFF
port map (
  Q => O_sdrc_data(5),
  D => IO_sdram_dq_in(5),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_4_s0\: DFF
port map (
  Q => O_sdrc_data(4),
  D => IO_sdram_dq_in(4),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_3_s0\: DFF
port map (
  Q => O_sdrc_data(3),
  D => IO_sdram_dq_in(3),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_2_s0\: DFF
port map (
  Q => O_sdrc_data(2),
  D => IO_sdram_dq_in(2),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_1_s0\: DFF
port map (
  Q => O_sdrc_data(1),
  D => IO_sdram_dq_in(1),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_data_0_s0\: DFF
port map (
  Q => O_sdrc_data(0),
  D => IO_sdram_dq_in(0),
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_wen_n_s0\: DFF
port map (
  Q => u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_wen_n,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n995,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_cas_n_s0\: DFF
port map (
  Q => u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_cas_n,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n998,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_ras_n_s0\: DFF
port map (
  Q => u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_ras_n,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n1001,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_ba_1_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_ba\(1),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n1003,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_ba_0_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_ba\(0),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n1005,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_addr_10_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(10),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n1007,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_addr_9_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(9),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n1009,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_addr_8_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(8),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n1011,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_addr_7_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(7),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n1013,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_addr_6_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(6),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n1015,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_addr_5_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(5),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n1017,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_addr_4_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(4),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n1019,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_addr_3_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(3),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n1021,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_addr_2_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(2),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n1023,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_addr_1_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(1),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n1025,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_addr_0_s0\: DFF
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(0),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n1027,
  CLK => I_sdrc_clk);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_cs_n_s0\: DFFP
port map (
  Q => O_sdram_cs_n,
  D => GND_0,
  CLK => I_sdrc_clk,
  PRESET => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/Init_cnt_15_s1\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(15),
  D => VCC_0,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_n12,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd_7_s1\: DFFE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(7),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n178,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7_11);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd_6_s1\: DFFE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(6),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n179,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7_11);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd_5_s1\: DFFE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(5),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n180,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7_11);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd_4_s1\: DFFE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(4),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n181,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7_11);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd_3_s1\: DFFE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(3),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n182,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7_11);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd_2_s1\: DFFE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(2),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n183,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7_11);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd_1_s1\: DFFE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(1),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n184,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7_11);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd_0_s1\: DFFE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(0),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n185,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7_11);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_wr_data_valid_s1\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n757_9,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_8,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdrc_cmd_ack_s1\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => NN,
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n79_27,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_n79,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num_8_s1\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(8),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n604,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_n604_19,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num_7_s1\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(7),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n606,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_n604_19,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num_6_s1\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(6),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n608_15,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_n604_19,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num_5_s1\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(5),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n610,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_n604_19,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num_4_s1\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(4),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n612,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_n604_19,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num_3_s1\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(3),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n614_15,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_n604_19,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num_2_s1\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(2),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n616,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_n604_19,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num_1_s1\: DFFCE
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(1),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n618,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_n604_19,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/n26_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n26,
  COUT => u_sdrc_hs_top_n26_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(1),
  I1 => \u_sdrc_hs_top/Init_cnt\(0),
  I3 => GND_0,
  CIN => GND_0);
\u_sdrc_hs_top/n25_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n25,
  COUT => u_sdrc_hs_top_n25_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(2),
  I1 => GND_0,
  I3 => GND_0,
  CIN => u_sdrc_hs_top_n26_2);
\u_sdrc_hs_top/n24_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n24,
  COUT => u_sdrc_hs_top_n24_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(3),
  I1 => GND_0,
  I3 => GND_0,
  CIN => u_sdrc_hs_top_n25_2);
\u_sdrc_hs_top/n23_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n23,
  COUT => u_sdrc_hs_top_n23_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(4),
  I1 => GND_0,
  I3 => GND_0,
  CIN => u_sdrc_hs_top_n24_2);
\u_sdrc_hs_top/n22_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n22,
  COUT => u_sdrc_hs_top_n22_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(5),
  I1 => GND_0,
  I3 => GND_0,
  CIN => u_sdrc_hs_top_n23_2);
\u_sdrc_hs_top/n21_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n21,
  COUT => u_sdrc_hs_top_n21_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(6),
  I1 => GND_0,
  I3 => GND_0,
  CIN => u_sdrc_hs_top_n22_2);
\u_sdrc_hs_top/n20_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n20,
  COUT => u_sdrc_hs_top_n20_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(7),
  I1 => GND_0,
  I3 => GND_0,
  CIN => u_sdrc_hs_top_n21_2);
\u_sdrc_hs_top/n19_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n19,
  COUT => u_sdrc_hs_top_n19_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(8),
  I1 => GND_0,
  I3 => GND_0,
  CIN => u_sdrc_hs_top_n20_2);
\u_sdrc_hs_top/n18_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n18,
  COUT => u_sdrc_hs_top_n18_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(9),
  I1 => GND_0,
  I3 => GND_0,
  CIN => u_sdrc_hs_top_n19_2);
\u_sdrc_hs_top/n17_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n17,
  COUT => u_sdrc_hs_top_n17_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(10),
  I1 => GND_0,
  I3 => GND_0,
  CIN => u_sdrc_hs_top_n18_2);
\u_sdrc_hs_top/n16_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n16,
  COUT => u_sdrc_hs_top_n16_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(11),
  I1 => GND_0,
  I3 => GND_0,
  CIN => u_sdrc_hs_top_n17_2);
\u_sdrc_hs_top/n15_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n15,
  COUT => u_sdrc_hs_top_n15_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(12),
  I1 => GND_0,
  I3 => GND_0,
  CIN => u_sdrc_hs_top_n16_2);
\u_sdrc_hs_top/n14_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n14,
  COUT => u_sdrc_hs_top_n14_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(13),
  I1 => GND_0,
  I3 => GND_0,
  CIN => u_sdrc_hs_top_n15_2);
\u_sdrc_hs_top/n13_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n13,
  COUT => u_sdrc_hs_top_n13_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(14),
  I1 => GND_0,
  I3 => GND_0,
  CIN => u_sdrc_hs_top_n14_2);
\u_sdrc_hs_top/n12_s\: ALU
generic map (
  ALU_MODE => 0
)
port map (
  SUM => u_sdrc_hs_top_n12,
  COUT => u_sdrc_hs_top_n12_2,
  I0 => \u_sdrc_hs_top/Init_cnt\(15),
  I1 => GND_0,
  I3 => GND_0,
  CIN => u_sdrc_hs_top_n13_2);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_cke_s3\: DFFSE
generic map (
  INIT => '1'
)
port map (
  Q => u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_cke,
  D => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  CLK => I_sdrc_clk,
  CE => u_sdrc_hs_top_u_sdrc_control_fsm_O_sdram_cke,
  SET => u_sdrc_hs_top_u_sdrc_control_fsm_n991);
\u_sdrc_hs_top/O_sdram_ras_n_d_s\: LUT3
generic map (
  INIT => X"AC"
)
port map (
  F => O_sdram_ras_n,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_ras_n,
  I1 => \u_sdrc_hs_top/Sdram_cmd_init\(2),
  I2 => NN_0);
\u_sdrc_hs_top/O_sdram_cas_n_d_s\: LUT3
generic map (
  INIT => X"CA"
)
port map (
  F => O_sdram_cas_n,
  I0 => \u_sdrc_hs_top/Sdram_cmd_init\(1),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_cas_n,
  I2 => NN_0);
\u_sdrc_hs_top/O_sdram_wen_n_d_s\: LUT3
generic map (
  INIT => X"CA"
)
port map (
  F => O_sdram_wen_n,
  I0 => \u_sdrc_hs_top/Sdram_cmd_init\(0),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_wen_n,
  I2 => NN_0);
\u_sdrc_hs_top/O_sdram_addr_d_10_s\: LUT3
generic map (
  INIT => X"CA"
)
port map (
  F => O_sdram_addr(10),
  I0 => \u_sdrc_hs_top/Sdram_ba_init\(1),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(10),
  I2 => NN_0);
\u_sdrc_hs_top/O_sdram_addr_d_9_s\: LUT3
generic map (
  INIT => X"CA"
)
port map (
  F => O_sdram_addr(9),
  I0 => \u_sdrc_hs_top/Sdram_ba_init\(1),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(9),
  I2 => NN_0);
\u_sdrc_hs_top/O_sdram_addr_d_8_s\: LUT3
generic map (
  INIT => X"CA"
)
port map (
  F => O_sdram_addr(8),
  I0 => \u_sdrc_hs_top/Sdram_ba_init\(1),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(8),
  I2 => NN_0);
\u_sdrc_hs_top/O_sdram_addr_d_7_s\: LUT3
generic map (
  INIT => X"CA"
)
port map (
  F => O_sdram_addr(7),
  I0 => \u_sdrc_hs_top/Sdram_ba_init\(1),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(7),
  I2 => NN_0);
\u_sdrc_hs_top/O_sdram_addr_d_6_s\: LUT3
generic map (
  INIT => X"CA"
)
port map (
  F => O_sdram_addr(6),
  I0 => \u_sdrc_hs_top/Sdram_ba_init\(1),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(6),
  I2 => NN_0);
\u_sdrc_hs_top/O_sdram_addr_d_3_s\: LUT3
generic map (
  INIT => X"CA"
)
port map (
  F => O_sdram_addr(3),
  I0 => \u_sdrc_hs_top/Sdram_ba_init\(1),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(3),
  I2 => NN_0);
\u_sdrc_hs_top/O_sdram_addr_d_2_s\: LUT3
generic map (
  INIT => X"CA"
)
port map (
  F => O_sdram_addr(2),
  I0 => \u_sdrc_hs_top/Sdram_ba_init\(1),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(2),
  I2 => NN_0);
\u_sdrc_hs_top/O_sdram_addr_d_1_s\: LUT3
generic map (
  INIT => X"CA"
)
port map (
  F => O_sdram_addr(1),
  I0 => \u_sdrc_hs_top/Sdram_ba_init\(1),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(1),
  I2 => NN_0);
\u_sdrc_hs_top/O_sdram_addr_d_0_s\: LUT3
generic map (
  INIT => X"CA"
)
port map (
  F => O_sdram_addr(0),
  I0 => \u_sdrc_hs_top/Sdram_ba_init\(1),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(0),
  I2 => NN_0);
\u_sdrc_hs_top/O_sdram_ba_d_1_s\: LUT3
generic map (
  INIT => X"CA"
)
port map (
  F => O_sdram_ba(1),
  I0 => \u_sdrc_hs_top/Sdram_ba_init\(1),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_ba\(1),
  I2 => NN_0);
\u_sdrc_hs_top/O_sdram_ba_d_0_s\: LUT3
generic map (
  INIT => X"CA"
)
port map (
  F => O_sdram_ba(0),
  I0 => \u_sdrc_hs_top/Sdram_ba_init\(1),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_ba\(0),
  I2 => NN_0);
\u_sdrc_hs_top/u_sdrc_control_fsm/Reset_cmd_count_s0\: LUT4
generic map (
  INIT => X"FFFE"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_Reset_cmd_count,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n178_s0\: LUT4
generic map (
  INIT => X"AA3C"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n178,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n178_4,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(7),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n178_5,
  I3 => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/n179_s0\: LUT4
generic map (
  INIT => X"3CAA"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n179,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n179_4,
  I1 => I_sdrc_addr(6),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n179_5,
  I3 => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/n180_s0\: LUT4
generic map (
  INIT => X"3C55"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n180,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n180_4,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n180_5,
  I2 => I_sdrc_addr(5),
  I3 => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/n181_s0\: LUT4
generic map (
  INIT => X"AA3C"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n181,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n181_4,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(4),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n181_5,
  I3 => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/n182_s0\: LUT4
generic map (
  INIT => X"3C55"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n182,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n182_4,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n182_5,
  I2 => I_sdrc_addr(3),
  I3 => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/n183_s0\: LUT4
generic map (
  INIT => X"3C55"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n183,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n183_4,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n183_5,
  I2 => I_sdrc_addr(2),
  I3 => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/n184_s0\: LUT4
generic map (
  INIT => X"553C"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n184,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n184_4,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(0),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(1),
  I3 => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/n185_s0\: LUT3
generic map (
  INIT => X"35"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n185,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(0),
  I1 => I_sdrc_addr(0),
  I2 => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/n991_s0\: LUT4
generic map (
  INIT => X"FFF2"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n991,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n991_4,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n604_19,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH_EXIT\);
\u_sdrc_hs_top/n204_s1\: LUT3
generic map (
  INIT => X"01"
)
port map (
  F => u_sdrc_hs_top_n204,
  I0 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG\,
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH2\,
  I2 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH1\);
\u_sdrc_hs_top/n206_s1\: LUT2
generic map (
  INIT => X"1"
)
port map (
  F => u_sdrc_hs_top_n206,
  I0 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG\,
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_PRECHARGEALL\);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_wr_data_valid_s3\: LUT3
generic map (
  INIT => X"F8"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_8,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9,
  I2 => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/n79_s21\: LUT3
generic map (
  INIT => X"BF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n79,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n604_19,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n79_34);
\u_sdrc_hs_top/n159_s12\: LUT4
generic map (
  INIT => X"FB0F"
)
port map (
  F => u_sdrc_hs_top_n159,
  I0 => u_sdrc_hs_top_n159_17,
  I1 => u_sdrc_hs_top_n159_18,
  I2 => u_sdrc_hs_top_n159_19,
  I3 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH2\);
\u_sdrc_hs_top/n161_s12\: LUT4
generic map (
  INIT => X"FB0F"
)
port map (
  F => u_sdrc_hs_top_n161,
  I0 => u_sdrc_hs_top_n159_17,
  I1 => u_sdrc_hs_top_n159_18,
  I2 => u_sdrc_hs_top_n161_17,
  I3 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n995_s12\: LUT4
generic map (
  INIT => X"4FFF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n995,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_17,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_wen_n,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_18,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_19);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1001_s12\: LUT4
generic map (
  INIT => X"70FF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1001,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Precharge_flag,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1001_17);
\u_sdrc_hs_top/n155_s12\: LUT4
generic map (
  INIT => X"FA30"
)
port map (
  F => u_sdrc_hs_top_n155,
  I0 => \u_sdrc_hs_top/Init_cnt\(15),
  I1 => u_sdrc_hs_top_n159_18,
  I2 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_PRECHARGEALL\,
  I3 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_IDLE\);
\u_sdrc_hs_top/n157_s12\: LUT4
generic map (
  INIT => X"00EF"
)
port map (
  F => u_sdrc_hs_top_n157,
  I0 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_PRECHARGE_DELAY\,
  I1 => u_sdrc_hs_top_n159_17,
  I2 => u_sdrc_hs_top_n157_17,
  I3 => u_sdrc_hs_top_n157_18);
\u_sdrc_hs_top/n163_s12\: LUT3
generic map (
  INIT => X"70"
)
port map (
  F => u_sdrc_hs_top_n163,
  I0 => u_sdrc_hs_top_n159_18,
  I1 => \u_sdrc_hs_top/Init_cnt\(15),
  I2 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_IDLE\);
\u_sdrc_hs_top/n165_s13\: LUT4
generic map (
  INIT => X"FFB0"
)
port map (
  F => u_sdrc_hs_top_n165,
  I0 => u_sdrc_hs_top_n165_18,
  I1 => u_sdrc_hs_top_n165_19,
  I2 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_PRECHARGE_DELAY\,
  I3 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_PRECHARGEALL\);
\u_sdrc_hs_top/n167_s13\: LUT3
generic map (
  INIT => X"F4"
)
port map (
  F => u_sdrc_hs_top_n167,
  I0 => u_sdrc_hs_top_n167_18,
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH1_DELAY\,
  I2 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH1\);
\u_sdrc_hs_top/n169_s13\: LUT3
generic map (
  INIT => X"F4"
)
port map (
  F => u_sdrc_hs_top_n169,
  I0 => u_sdrc_hs_top_n167_18,
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH2_DELAY\,
  I2 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH2\);
\u_sdrc_hs_top/n171_s13\: LUT4
generic map (
  INIT => X"FFB0"
)
port map (
  F => u_sdrc_hs_top_n171,
  I0 => u_sdrc_hs_top_n159_17,
  I1 => u_sdrc_hs_top_n159_18,
  I2 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG_DELAY\,
  I3 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG\);
\u_sdrc_hs_top/n173_s13\: LUT3
generic map (
  INIT => X"F8"
)
port map (
  F => u_sdrc_hs_top_n173,
  I0 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG_DELAY\,
  I1 => u_sdrc_hs_top_n173_18,
  I2 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_INIT_DONE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n578_s27\: LUT3
generic map (
  INIT => X"F4"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n578,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_32,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_AUTOREFRESH_DELAY\,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_41);
\u_sdrc_hs_top/u_sdrc_control_fsm/n580_s21\: LUT4
generic map (
  INIT => X"FEFF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n580,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_26,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_27,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_28,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_29);
\u_sdrc_hs_top/u_sdrc_control_fsm/n582_s26\: LUT4
generic map (
  INIT => X"8F88"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n582,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_40,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_32,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_33,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_ACTIVE2RW_DELAY\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n584_s26\: LUT4
generic map (
  INIT => X"F444"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n584,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n584_31,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\,
  I2 => I_sdrc_cmd(0),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n584_35);
\u_sdrc_hs_top/u_sdrc_control_fsm/n586_s26\: LUT4
generic map (
  INIT => X"4F44"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n586,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n584_31,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I2 => I_sdrc_cmd(0),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n584_35);
\u_sdrc_hs_top/u_sdrc_control_fsm/n588_s22\: LUT4
generic map (
  INIT => X"F5C0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n588,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_32,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n588_27,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n590_s22\: LUT4
generic map (
  INIT => X"FFF4"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n590,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_33,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_PRECHARGE_DELAY\,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n590_27,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n590_28);
\u_sdrc_hs_top/u_sdrc_control_fsm/n592_s21\: LUT2
generic map (
  INIT => X"4"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n592,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_32,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_INIT\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n594_s22\: LUT4
generic map (
  INIT => X"75C0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n594,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n594_33,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n594_28,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_POWER_DOWN\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n596_s23\: LUT4
generic map (
  INIT => X"F5C0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n596,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n594_33,
  I1 => I_sdram_selfrefresh,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n596_28,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n600_s22\: LUT3
generic map (
  INIT => X"F4"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n600,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_32,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH_WAIT\,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n602_s21\: LUT4
generic map (
  INIT => X"F530"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n602,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_32,
  I1 => I_sdram_selfrefresh,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH_WAIT\,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH_EXIT\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n998_s13\: LUT4
generic map (
  INIT => X"2FFF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n998,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n998_18,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n998_19);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1003_s14\: LUT4
generic map (
  INIT => X"4FFF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1003,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_bk_wrd\(1),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_19,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1005_s14\: LUT4
generic map (
  INIT => X"4FFF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1005,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_bk_wrd\(0),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1005_19,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1007_s14\: LUT4
generic map (
  INIT => X"F4FF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1007,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1007_23,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(10),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1007_20,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1009_s14\: LUT4
generic map (
  INIT => X"F4FF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1009,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1007_23,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(9),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1009_19,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1011_s14\: LUT4
generic map (
  INIT => X"F4FF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1011,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1007_23,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(8),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1011_19,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1013_s14\: LUT4
generic map (
  INIT => X"4FFF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1013,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(7),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1013_19,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1015_s14\: LUT4
generic map (
  INIT => X"4FFF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1015,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(6),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1015_19,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1017_s14\: LUT4
generic map (
  INIT => X"8FFF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1017,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n1017_19,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1017_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1019_s14\: LUT4
generic map (
  INIT => X"8FFF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1019,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n1019_19,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1019_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1021_s14\: LUT4
generic map (
  INIT => X"4FFF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1021,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(3),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1021_19,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1023_s14\: LUT4
generic map (
  INIT => X"4FFF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1023,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(2),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1023_19,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1025_s14\: LUT4
generic map (
  INIT => X"4FFF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1025,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(1),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1025_19,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1027_s14\: LUT4
generic map (
  INIT => X"4FFF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1027,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(0),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1027_19,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n79_s22\: LUT4
generic map (
  INIT => X"00BF"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n79_27,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_40,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n79_34,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n79_29);
\u_sdrc_hs_top/u_sdrc_control_fsm/n604_s9\: LUT4
generic map (
  INIT => X"0708"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n604,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(7),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n604_15,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(8));
\u_sdrc_hs_top/u_sdrc_control_fsm/n610_s8\: LUT4
generic map (
  INIT => X"0708"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n610,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(4),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n610_13,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(5));
\u_sdrc_hs_top/u_sdrc_control_fsm/n616_s8\: LUT4
generic map (
  INIT => X"0708"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n616,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(1),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(2));
\u_sdrc_hs_top/O_sdram_cke_d_s\: LUT2
generic map (
  INIT => X"B"
)
port map (
  F => O_sdram_cke,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_cke,
  I1 => NN_0);
\u_sdrc_hs_top/O_sdram_addr_d_4_s\: LUT2
generic map (
  INIT => X"B"
)
port map (
  F => O_sdram_addr(4),
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(4),
  I1 => NN_0);
\u_sdrc_hs_top/O_sdram_addr_d_5_s\: LUT2
generic map (
  INIT => X"B"
)
port map (
  F => O_sdram_addr(5),
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(5),
  I1 => NN_0);
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_cke_s5\: LUT2
generic map (
  INIT => X"B"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_O_sdram_cke,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_O_sdram_cke_8,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\);
\u_sdrc_hs_top/n65_s0\: LUT2
generic map (
  INIT => X"6"
)
port map (
  F => u_sdrc_hs_top_n65,
  I0 => \u_sdrc_hs_top/Count_init_delay\(0),
  I1 => \u_sdrc_hs_top/Count_init_delay\(1));
\u_sdrc_hs_top/n64_s0\: LUT3
generic map (
  INIT => X"78"
)
port map (
  F => u_sdrc_hs_top_n64,
  I0 => \u_sdrc_hs_top/Count_init_delay\(0),
  I1 => \u_sdrc_hs_top/Count_init_delay\(1),
  I2 => \u_sdrc_hs_top/Count_init_delay\(2));
\u_sdrc_hs_top/n63_s0\: LUT4
generic map (
  INIT => X"7F80"
)
port map (
  F => u_sdrc_hs_top_n63,
  I0 => \u_sdrc_hs_top/Count_init_delay\(0),
  I1 => \u_sdrc_hs_top/Count_init_delay\(1),
  I2 => \u_sdrc_hs_top/Count_init_delay\(2),
  I3 => \u_sdrc_hs_top/Count_init_delay\(3));
\u_sdrc_hs_top/u_sdrc_control_fsm/n85_s0\: LUT2
generic map (
  INIT => X"6"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n85,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(1));
\u_sdrc_hs_top/u_sdrc_control_fsm/n84_s0\: LUT3
generic map (
  INIT => X"78"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n84,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(1),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(2));
\u_sdrc_hs_top/u_sdrc_control_fsm/n83_s0\: LUT4
generic map (
  INIT => X"7F80"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n83,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(1),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(2),
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(3));
\u_sdrc_hs_top/u_sdrc_control_fsm/n99_s0\: LUT2
generic map (
  INIT => X"6"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n99,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(1));
\u_sdrc_hs_top/u_sdrc_control_fsm/n98_s0\: LUT3
generic map (
  INIT => X"78"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n98,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(1),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(2));
\u_sdrc_hs_top/u_sdrc_control_fsm/n97_s0\: LUT4
generic map (
  INIT => X"7F80"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n97,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(1),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(2),
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(3));
\u_sdrc_hs_top/u_sdrc_control_fsm/n178_s1\: LUT3
generic map (
  INIT => X"78"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n178_4,
  I0 => I_sdrc_addr(6),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n179_5,
  I2 => I_sdrc_addr(7));
\u_sdrc_hs_top/u_sdrc_control_fsm/n178_s2\: LUT4
generic map (
  INIT => X"8000"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n178_5,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(4),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(5),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(6),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n181_5);
\u_sdrc_hs_top/u_sdrc_control_fsm/n179_s1\: LUT4
generic map (
  INIT => X"7F80"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n179_4,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(4),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(5),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n181_5,
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(6));
\u_sdrc_hs_top/u_sdrc_control_fsm/n179_s2\: LUT3
generic map (
  INIT => X"80"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n179_5,
  I0 => I_sdrc_addr(5),
  I1 => I_sdrc_addr(4),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n179_6);
\u_sdrc_hs_top/u_sdrc_control_fsm/n180_s1\: LUT3
generic map (
  INIT => X"87"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n180_4,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(4),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n181_5,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(5));
\u_sdrc_hs_top/u_sdrc_control_fsm/n180_s2\: LUT2
generic map (
  INIT => X"8"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n180_5,
  I0 => I_sdrc_addr(4),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n179_6);
\u_sdrc_hs_top/u_sdrc_control_fsm/n181_s1\: LUT2
generic map (
  INIT => X"6"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n181_4,
  I0 => I_sdrc_addr(4),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n179_6);
\u_sdrc_hs_top/u_sdrc_control_fsm/n181_s2\: LUT4
generic map (
  INIT => X"8000"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n181_5,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(1),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(2),
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(3));
\u_sdrc_hs_top/u_sdrc_control_fsm/n182_s1\: LUT4
generic map (
  INIT => X"807F"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n182_4,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(1),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(2),
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(3));
\u_sdrc_hs_top/u_sdrc_control_fsm/n182_s2\: LUT3
generic map (
  INIT => X"80"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n182_5,
  I0 => I_sdrc_addr(0),
  I1 => I_sdrc_addr(2),
  I2 => I_sdrc_addr(1));
\u_sdrc_hs_top/u_sdrc_control_fsm/n183_s1\: LUT3
generic map (
  INIT => X"87"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n183_4,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(1),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(2));
\u_sdrc_hs_top/u_sdrc_control_fsm/n183_s2\: LUT2
generic map (
  INIT => X"8"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n183_5,
  I0 => I_sdrc_addr(0),
  I1 => I_sdrc_addr(1));
\u_sdrc_hs_top/u_sdrc_control_fsm/n184_s1\: LUT2
generic map (
  INIT => X"9"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n184_4,
  I0 => I_sdrc_addr(0),
  I1 => I_sdrc_addr(1));
\u_sdrc_hs_top/u_sdrc_control_fsm/n991_s1\: LUT4
generic map (
  INIT => X"0001"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n991_4,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH_EXIT\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH_WAIT\,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH\,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_POWER_DOWN\);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd_7_s4\: LUT2
generic map (
  INIT => X"1"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_wr_data_valid_s4\: LUT4
generic map (
  INIT => X"9000"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(2),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(2),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_10,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_11);
\u_sdrc_hs_top/n159_s13\: LUT2
generic map (
  INIT => X"4"
)
port map (
  F => u_sdrc_hs_top_n159_17,
  I0 => \u_sdrc_hs_top/Init_cnt\(15),
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_IDLE\);
\u_sdrc_hs_top/n159_s14\: LUT3
generic map (
  INIT => X"B0"
)
port map (
  F => u_sdrc_hs_top_n159_18,
  I0 => u_sdrc_hs_top_n159_20,
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_PRECHARGE_DELAY\,
  I2 => u_sdrc_hs_top_n157_17);
\u_sdrc_hs_top/n159_s15\: LUT3
generic map (
  INIT => X"D3"
)
port map (
  F => u_sdrc_hs_top_n159_19,
  I0 => u_sdrc_hs_top_n159_21,
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH2\,
  I2 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH1_DELAY\);
\u_sdrc_hs_top/n161_s13\: LUT3
generic map (
  INIT => X"D3"
)
port map (
  F => u_sdrc_hs_top_n161_17,
  I0 => u_sdrc_hs_top_n159_21,
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG\,
  I2 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH2_DELAY\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n995_s13\: LUT4
generic map (
  INIT => X"8F00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n995_17,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_20,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n757,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_O_sdram_cke);
\u_sdrc_hs_top/u_sdrc_control_fsm/n995_s14\: LUT4
generic map (
  INIT => X"0B33"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n995_18,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Precharge_flag,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9);
\u_sdrc_hs_top/u_sdrc_control_fsm/n995_s15\: LUT4
generic map (
  INIT => X"D000"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n995_19,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_24,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_22,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n991_4,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_Reset_cmd_count);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1001_s13\: LUT4
generic map (
  INIT => X"0B00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1001_17,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1001_18,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1001_22);
\u_sdrc_hs_top/n157_s13\: LUT4
generic map (
  INIT => X"00F1"
)
port map (
  F => u_sdrc_hs_top_n157_17,
  I0 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH1_DELAY\,
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH2_DELAY\,
  I2 => u_sdrc_hs_top_n159_21,
  I3 => u_sdrc_hs_top_n165_18);
\u_sdrc_hs_top/n157_s14\: LUT3
generic map (
  INIT => X"07"
)
port map (
  F => u_sdrc_hs_top_n157_18,
  I0 => u_sdrc_hs_top_n159_20,
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_PRECHARGE_DELAY\,
  I2 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH1\);
\u_sdrc_hs_top/n165_s14\: LUT2
generic map (
  INIT => X"4"
)
port map (
  F => u_sdrc_hs_top_n165_18,
  I0 => u_sdrc_hs_top_n173_18,
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG_DELAY\);
\u_sdrc_hs_top/n165_s15\: LUT4
generic map (
  INIT => X"0100"
)
port map (
  F => u_sdrc_hs_top_n165_19,
  I0 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH2_DELAY\,
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH1_DELAY\,
  I2 => u_sdrc_hs_top_n159_17,
  I3 => u_sdrc_hs_top_n159_20);
\u_sdrc_hs_top/n167_s14\: LUT4
generic map (
  INIT => X"0100"
)
port map (
  F => u_sdrc_hs_top_n167_18,
  I0 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG_DELAY\,
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_PRECHARGE_DELAY\,
  I2 => u_sdrc_hs_top_n159_17,
  I3 => u_sdrc_hs_top_n159_21);
\u_sdrc_hs_top/n173_s14\: LUT4
generic map (
  INIT => X"0100"
)
port map (
  F => u_sdrc_hs_top_n173_18,
  I0 => \u_sdrc_hs_top/Count_init_delay\(1),
  I1 => \u_sdrc_hs_top/Count_init_delay\(2),
  I2 => \u_sdrc_hs_top/Count_init_delay\(3),
  I3 => \u_sdrc_hs_top/Count_init_delay\(0));
\u_sdrc_hs_top/u_sdrc_control_fsm/n578_s28\: LUT4
generic map (
  INIT => X"0E00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n578_32,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_26,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_39);
\u_sdrc_hs_top/u_sdrc_control_fsm/n580_s22\: LUT4
generic map (
  INIT => X"1F00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n580_26,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_35,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_30,
  I2 => I_sdrc_cmd_en,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_24);
\u_sdrc_hs_top/u_sdrc_control_fsm/n580_s23\: LUT4
generic map (
  INIT => X"C500"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n580_27,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n79_30,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_AUTOREFRESH_DELAY\,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(3),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_31);
\u_sdrc_hs_top/u_sdrc_control_fsm/n580_s24\: LUT4
generic map (
  INIT => X"050C"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n580_28,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Precharge_flag,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9);
\u_sdrc_hs_top/u_sdrc_control_fsm/n580_s25\: LUT4
generic map (
  INIT => X"8F00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n580_29,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_O_sdram_cke,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_32,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_33);
\u_sdrc_hs_top/u_sdrc_control_fsm/n582_s28\: LUT3
generic map (
  INIT => X"40"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n582_32,
  I0 => I_sdrc_cmd(2),
  I1 => I_sdrc_cmd(1),
  I2 => I_sdrc_cmd(0));
\u_sdrc_hs_top/u_sdrc_control_fsm/n582_s29\: LUT4
generic map (
  INIT => X"0E00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n582_33,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_26,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_35);
\u_sdrc_hs_top/u_sdrc_control_fsm/n584_s27\: LUT3
generic map (
  INIT => X"40"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n584_31,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_26,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_39);
\u_sdrc_hs_top/u_sdrc_control_fsm/n588_s23\: LUT2
generic map (
  INIT => X"8"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n588_27,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Precharge_flag);
\u_sdrc_hs_top/u_sdrc_control_fsm/n590_s23\: LUT2
generic map (
  INIT => X"8"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n590_27,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_O_sdram_cke_8);
\u_sdrc_hs_top/u_sdrc_control_fsm/n590_s24\: LUT3
generic map (
  INIT => X"80"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n590_28,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Precharge_flag,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9);
\u_sdrc_hs_top/u_sdrc_control_fsm/n594_s24\: LUT4
generic map (
  INIT => X"0EF0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n594_28,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n594_31,
  I1 => I_sdram_selfrefresh,
  I2 => I_sdram_power_down,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_POWER_DOWN\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n596_s24\: LUT4
generic map (
  INIT => X"0D00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n596_28,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n594_31,
  I1 => I_sdram_selfrefresh,
  I2 => I_sdram_power_down,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n998_s14\: LUT4
generic map (
  INIT => X"053F"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n998_18,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_O_sdram_cke_8,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n998_20,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_cas_n,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n998_s15\: LUT4
generic map (
  INIT => X"4F00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n998_19,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_32,
  I1 => I_sdrc_cmd_en,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_24,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n998_21);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1003_s15\: LUT4
generic map (
  INIT => X"053F"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_19,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_21,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_ba\(1),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_22);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1003_s16\: LUT4
generic map (
  INIT => X"1C00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_20,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_23,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n991_4);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1005_s15\: LUT4
generic map (
  INIT => X"053F"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1005_19,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_21,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_ba\(0),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1005_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1007_s16\: LUT4
generic map (
  INIT => X"4F00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1007_20,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n757,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n1007_21,
  I2 => I_sdrc_cmd_en,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_24);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1009_s15\: LUT4
generic map (
  INIT => X"4F00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1009_19,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n757,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n1009_20,
  I2 => I_sdrc_cmd_en,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_24);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1011_s15\: LUT4
generic map (
  INIT => X"4F00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1011_19,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n757,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n1011_20,
  I2 => I_sdrc_cmd_en,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_24);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1013_s15\: LUT4
generic map (
  INIT => X"053F"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1013_19,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_21,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(7),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1013_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1015_s15\: LUT4
generic map (
  INIT => X"053F"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1015_19,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_21,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(6),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1015_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1017_s15\: LUT4
generic map (
  INIT => X"BBF0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1017_19,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1017_21,
  I1 => I_sdrc_cmd_en,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(5),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1017_s16\: LUT4
generic map (
  INIT => X"0BBB"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1017_20,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(5),
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(5));
\u_sdrc_hs_top/u_sdrc_control_fsm/n1019_s15\: LUT4
generic map (
  INIT => X"BBF0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1019_19,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1019_21,
  I1 => I_sdrc_cmd_en,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(4),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1019_s16\: LUT4
generic map (
  INIT => X"0BBB"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1019_20,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd\(4),
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(4));
\u_sdrc_hs_top/u_sdrc_control_fsm/n1021_s15\: LUT4
generic map (
  INIT => X"053F"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1021_19,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_21,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(3),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1021_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1023_s15\: LUT4
generic map (
  INIT => X"053F"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1023_19,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_21,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(2),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1023_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1025_s15\: LUT4
generic map (
  INIT => X"053F"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1025_19,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_21,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(1),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1025_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1027_s15\: LUT4
generic map (
  INIT => X"053F"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1027_19,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_21,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(0),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1027_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n79_s24\: LUT4
generic map (
  INIT => X"EF00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n79_29,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Precharge_flag,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n79_31);
\u_sdrc_hs_top/u_sdrc_control_fsm/n604_s10\: LUT4
generic map (
  INIT => X"8000"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n604_15,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(4),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(5),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(6),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n610_13);
\u_sdrc_hs_top/u_sdrc_control_fsm/n608_s9\: LUT3
generic map (
  INIT => X"80"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n608,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(4),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(5),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n610_13);
\u_sdrc_hs_top/u_sdrc_control_fsm/n610_s9\: LUT4
generic map (
  INIT => X"8000"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n610_13,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(1),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(2),
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(3));
\u_sdrc_hs_top/u_sdrc_control_fsm/n614_s9\: LUT3
generic map (
  INIT => X"80"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n614,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(1),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(2));
\u_sdrc_hs_top/u_sdrc_control_fsm/n757_s2\: LUT2
generic map (
  INIT => X"4"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n757,
  I0 => I_sdrc_cmd(1),
  I1 => I_sdrc_cmd(2));
\u_sdrc_hs_top/u_sdrc_control_fsm/O_sdram_cke_s6\: LUT4
generic map (
  INIT => X"0100"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_O_sdram_cke_8,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(2),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(3),
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(1));
\u_sdrc_hs_top/u_sdrc_control_fsm/n179_s3\: LUT4
generic map (
  INIT => X"8000"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n179_6,
  I0 => I_sdrc_addr(0),
  I1 => I_sdrc_addr(3),
  I2 => I_sdrc_addr(2),
  I3 => I_sdrc_addr(1));
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_wr_data_valid_s5\: LUT3
generic map (
  INIT => X"90"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_10,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(6),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(6),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_12);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_wr_data_valid_s6\: LUT4
generic map (
  INIT => X"9000"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_11,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(1),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(1),
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_13,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_14);
\u_sdrc_hs_top/u_sdrc_control_fsm/n79_s25\: LUT2
generic map (
  INIT => X"1"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n79_30,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_PRECHARGE_DELAY\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_ACTIVE2RW_DELAY\);
\u_sdrc_hs_top/n159_s16\: LUT4
generic map (
  INIT => X"0100"
)
port map (
  F => u_sdrc_hs_top_n159_20,
  I0 => \u_sdrc_hs_top/Count_init_delay\(0),
  I1 => \u_sdrc_hs_top/Count_init_delay\(2),
  I2 => \u_sdrc_hs_top/Count_init_delay\(3),
  I3 => \u_sdrc_hs_top/Count_init_delay\(1));
\u_sdrc_hs_top/n159_s17\: LUT4
generic map (
  INIT => X"1000"
)
port map (
  F => u_sdrc_hs_top_n159_21,
  I0 => \u_sdrc_hs_top/Count_init_delay\(0),
  I1 => \u_sdrc_hs_top/Count_init_delay\(2),
  I2 => \u_sdrc_hs_top/Count_init_delay\(1),
  I3 => \u_sdrc_hs_top/Count_init_delay\(3));
\u_sdrc_hs_top/u_sdrc_control_fsm/n995_s16\: LUT2
generic map (
  INIT => X"1"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n995_20,
  I0 => I_sdram_power_down,
  I1 => I_sdram_selfrefresh);
\u_sdrc_hs_top/u_sdrc_control_fsm/n995_s18\: LUT4
generic map (
  INIT => X"8F00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n995_22,
  I0 => I_sdrc_cmd(1),
  I1 => I_sdrc_cmd(2),
  I2 => I_sdrc_cmd(0),
  I3 => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1001_s14\: LUT4
generic map (
  INIT => X"B033"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1001_18,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_35,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_ras_n,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n1001_24,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n578_s31\: LUT2
generic map (
  INIT => X"4"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n578_35,
  I0 => I_sdrc_cmd(2),
  I1 => I_sdrc_cmd(0));
\u_sdrc_hs_top/u_sdrc_control_fsm/n580_s26\: LUT4
generic map (
  INIT => X"BF00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n580_30,
  I0 => I_sdrc_data_len(4),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_34,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_35,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n757);
\u_sdrc_hs_top/u_sdrc_control_fsm/n580_s27\: LUT3
generic map (
  INIT => X"10"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n580_31,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(1),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(2),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(0));
\u_sdrc_hs_top/u_sdrc_control_fsm/n580_s28\: LUT4
generic map (
  INIT => X"1000"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n580_32,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_AUTOREFRESH_DELAY\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_INIT\,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n79_30,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_36);
\u_sdrc_hs_top/u_sdrc_control_fsm/n580_s29\: LUT4
generic map (
  INIT => X"0503"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n580_33,
  I0 => NN_0,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_37,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH_EXIT\,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_INIT\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n582_s30\: LUT3
generic map (
  INIT => X"10"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n582_34,
  I0 => I_sdram_power_down,
  I1 => I_sdram_selfrefresh,
  I2 => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/n582_s31\: LUT4
generic map (
  INIT => X"4000"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n582_35,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(3),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_38,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_O_sdram_cke,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_37);
\u_sdrc_hs_top/u_sdrc_control_fsm/n584_s29\: LUT3
generic map (
  INIT => X"40"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n584_33,
  I0 => I_sdrc_data_len(4),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_35,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_34);
\u_sdrc_hs_top/u_sdrc_control_fsm/n998_s16\: LUT4
generic map (
  INIT => X"EF00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n998_20,
  I0 => I_sdrc_cmd(1),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n998_22,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_20,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n998_s17\: LUT4
generic map (
  INIT => X"FE00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n998_21,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH_EXIT\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH\,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_Reset_cmd_count,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n998_23);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1003_s17\: LUT4
generic map (
  INIT => X"EF00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_21,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n757,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_35,
  I2 => I_sdrc_cmd_en,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n995_20);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1003_s18\: LUT3
generic map (
  INIT => X"D0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_22,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_26,
  I1 => I_sdrc_addr(20),
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1003_s19\: LUT4
generic map (
  INIT => X"C35F"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_23,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_O_sdram_cke_8,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1005_s16\: LUT3
generic map (
  INIT => X"D0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1005_20,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_26,
  I1 => I_sdrc_addr(19),
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1007_s17\: LUT4
generic map (
  INIT => X"BBB0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1007_21,
  I0 => I_sdrc_addr(18),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_32,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(10),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_35);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1009_s16\: LUT4
generic map (
  INIT => X"BBB0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1009_20,
  I0 => I_sdrc_addr(17),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_32,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(9),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_35);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1011_s16\: LUT4
generic map (
  INIT => X"BBB0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1011_20,
  I0 => I_sdrc_addr(16),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_32,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(8),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_35);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1013_s16\: LUT3
generic map (
  INIT => X"D0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1013_20,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_34,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n1013_21,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1015_s16\: LUT3
generic map (
  INIT => X"D0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1015_20,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_34,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n1015_21,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1017_s17\: LUT4
generic map (
  INIT => X"EC0C"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1017_21,
  I0 => I_sdrc_cmd(2),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n1017_22,
  I2 => I_sdrc_cmd(1),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1017_23);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1019_s17\: LUT4
generic map (
  INIT => X"EC0C"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1019_21,
  I0 => I_sdrc_cmd(2),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n1019_22,
  I2 => I_sdrc_cmd(1),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n1019_23);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1021_s16\: LUT3
generic map (
  INIT => X"D0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1021_20,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_34,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n1021_21,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1023_s16\: LUT3
generic map (
  INIT => X"D0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1023_20,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_34,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n1023_21,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1025_s16\: LUT3
generic map (
  INIT => X"D0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1025_20,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_34,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n1025_21,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1027_s16\: LUT3
generic map (
  INIT => X"D0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1027_20,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_34,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n1027_21,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n79_s26\: LUT4
generic map (
  INIT => X"0007"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n79_31,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n584_33,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n79_32,
  I2 => NN,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_27);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_wr_data_valid_s7\: LUT4
generic map (
  INIT => X"9009"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_12,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(0),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(5),
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(5));
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_wr_data_valid_s8\: LUT3
generic map (
  INIT => X"41"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_13,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(8),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(7),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(7));
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_wr_data_valid_s9\: LUT4
generic map (
  INIT => X"9009"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_14,
  I0 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(3),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(3),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(4),
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdrc_wrd_len\(4));
\u_sdrc_hs_top/u_sdrc_control_fsm/n578_s32\: LUT4
generic map (
  INIT => X"5CDD"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n578_36,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n79_30,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_AUTOREFRESH_DELAY\,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(3),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_31);
\u_sdrc_hs_top/u_sdrc_control_fsm/n578_s33\: LUT3
generic map (
  INIT => X"D0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n578_37,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_INIT\,
  I1 => NN_0,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_36);
\u_sdrc_hs_top/u_sdrc_control_fsm/n580_s30\: LUT4
generic map (
  INIT => X"0001"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n580_34,
  I0 => I_sdrc_data_len(5),
  I1 => I_sdrc_data_len(6),
  I2 => I_sdrc_data_len(7),
  I3 => I_sdrc_precharge_ctrl);
\u_sdrc_hs_top/u_sdrc_control_fsm/n580_s31\: LUT4
generic map (
  INIT => X"0001"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n580_35,
  I0 => I_sdrc_data_len(0),
  I1 => I_sdrc_data_len(1),
  I2 => I_sdrc_data_len(2),
  I3 => I_sdrc_data_len(3));
\u_sdrc_hs_top/u_sdrc_control_fsm/n580_s32\: LUT4
generic map (
  INIT => X"0777"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n580_36,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH_WAIT\,
  I1 => I_sdram_selfrefresh,
  I2 => I_sdram_power_down,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_POWER_DOWN\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n580_s33\: LUT4
generic map (
  INIT => X"1000"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n580_37,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_AUTOREFRESH_DELAY\,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_Reset_cmd_count,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n991_4,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n79_30);
\u_sdrc_hs_top/u_sdrc_control_fsm/n998_s18\: LUT2
generic map (
  INIT => X"1"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n998_22,
  I0 => I_sdrc_cmd(0),
  I1 => I_sdrc_cmd(2));
\u_sdrc_hs_top/u_sdrc_control_fsm/n998_s19\: LUT2
generic map (
  INIT => X"1"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n998_23,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_SELFREFRESH_WAIT\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_POWER_DOWN\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1013_s17\: LUT4
generic map (
  INIT => X"B0BB"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1013_21,
  I0 => I_sdrc_addr(15),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_32,
  I2 => I_sdrc_addr(7),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n757);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1015_s17\: LUT4
generic map (
  INIT => X"B0BB"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1015_21,
  I0 => I_sdrc_addr(14),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_32,
  I2 => I_sdrc_addr(6),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n757);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1017_s18\: LUT4
generic map (
  INIT => X"F0EE"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1017_22,
  I0 => I_sdrc_cmd(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(5),
  I2 => I_sdrc_addr(5),
  I3 => I_sdrc_cmd(2));
\u_sdrc_hs_top/u_sdrc_control_fsm/n1017_s19\: LUT4
generic map (
  INIT => X"F0BB"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1017_23,
  I0 => I_sdrc_addr(13),
  I1 => I_sdrc_cmd(0),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(5),
  I3 => I_sdrc_cmd(2));
\u_sdrc_hs_top/u_sdrc_control_fsm/n1019_s18\: LUT4
generic map (
  INIT => X"F0EE"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1019_22,
  I0 => I_sdrc_cmd(0),
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(4),
  I2 => I_sdrc_addr(4),
  I3 => I_sdrc_cmd(2));
\u_sdrc_hs_top/u_sdrc_control_fsm/n1019_s19\: LUT4
generic map (
  INIT => X"F0BB"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1019_23,
  I0 => I_sdrc_addr(12),
  I1 => I_sdrc_cmd(0),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Sdram_addr\(4),
  I3 => I_sdrc_cmd(2));
\u_sdrc_hs_top/u_sdrc_control_fsm/n1021_s17\: LUT4
generic map (
  INIT => X"B0BB"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1021_21,
  I0 => I_sdrc_addr(11),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_32,
  I2 => I_sdrc_addr(3),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n757);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1023_s17\: LUT4
generic map (
  INIT => X"B0BB"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1023_21,
  I0 => I_sdrc_addr(10),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_32,
  I2 => I_sdrc_addr(2),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n757);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1025_s17\: LUT4
generic map (
  INIT => X"B0BB"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1025_21,
  I0 => I_sdrc_addr(9),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_32,
  I2 => I_sdrc_addr(1),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n757);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1027_s17\: LUT4
generic map (
  INIT => X"B0BB"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1027_21,
  I0 => I_sdrc_addr(8),
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_32,
  I2 => I_sdrc_addr(0),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n757);
\u_sdrc_hs_top/u_sdrc_control_fsm/n79_s27\: LUT4
generic map (
  INIT => X"4000"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n79_32,
  I0 => I_sdrc_cmd(1),
  I1 => I_sdrc_cmd(2),
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_34);
\u_sdrc_hs_top/n202_s2\: LUT4
generic map (
  INIT => X"0001"
)
port map (
  F => u_sdrc_hs_top_n202,
  I0 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_PRECHARGEALL\,
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG\,
  I2 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH2\,
  I3 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH1\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n582_s33\: LUT4
generic map (
  INIT => X"0100"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n582_38,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_AUTOREFRESH_DELAY\,
  I1 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(1),
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(2),
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(0));
\u_sdrc_hs_top/u_sdrc_control_fsm/n79_s28\: LUT3
generic map (
  INIT => X"01"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n79_34,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_AUTOREFRESH_DELAY\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_PRECHARGE_DELAY\,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_ACTIVE2RW_DELAY\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n578_s34\: LUT4
generic map (
  INIT => X"4500"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n578_39,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_36,
  I1 => u_sdrc_hs_top_u_sdrc_control_fsm_O_sdram_cke_8,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_37);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1001_s17\: LUT4
generic map (
  INIT => X"BF00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1001_22,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_O_sdram_cke_8,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_Sdram_ras_n,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n998_21);
\u_sdrc_hs_top/u_sdrc_control_fsm/n594_s26\: LUT4
generic map (
  INIT => X"BA00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n594_31,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n580_30,
  I1 => I_sdrc_cmd(2),
  I2 => I_sdrc_cmd(0),
  I3 => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/n578_s35\: LUT4
generic map (
  INIT => X"1000"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n578_41,
  I0 => I_sdrc_cmd(1),
  I1 => I_sdrc_cmd(2),
  I2 => I_sdrc_cmd(0),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_40);
\u_sdrc_hs_top/u_sdrc_control_fsm/n995_s19\: LUT3
generic map (
  INIT => X"02"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n995_24,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\,
  I1 => I_sdram_power_down,
  I2 => I_sdram_selfrefresh);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1007_s18\: LUT4
generic map (
  INIT => X"001F"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1007_23,
  I0 => I_sdram_power_down,
  I1 => I_sdram_selfrefresh,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\,
  I3 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_DATAIN2ACTIVE\);
\u_sdrc_hs_top/u_sdrc_control_fsm/n582_s34\: LUT4
generic map (
  INIT => X"0200"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n582_40,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\,
  I1 => I_sdram_power_down,
  I2 => I_sdram_selfrefresh,
  I3 => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1003_s21\: LUT4
generic map (
  INIT => X"BA00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1003_26,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_32,
  I1 => I_sdrc_cmd(1),
  I2 => I_sdrc_cmd(2),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_34);
\u_sdrc_hs_top/u_sdrc_control_fsm/n1001_s18\: LUT3
generic map (
  INIT => X"B0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n1001_24,
  I0 => I_sdrc_cmd(1),
  I1 => I_sdrc_cmd(2),
  I2 => I_sdrc_cmd_en);
\u_sdrc_hs_top/u_sdrc_control_fsm/n584_s30\: LUT4
generic map (
  INIT => X"1000"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n584_35,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_n584_33,
  I1 => I_sdrc_cmd(1),
  I2 => I_sdrc_cmd(2),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n582_40);
\u_sdrc_hs_top/u_sdrc_control_fsm/n757_s3\: LUT4
generic map (
  INIT => X"0400"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n757_9,
  I0 => I_sdrc_cmd(0),
  I1 => I_sdrc_cmd_en,
  I2 => I_sdrc_cmd(1),
  I3 => I_sdrc_cmd(2));
\u_sdrc_hs_top/u_sdrc_control_fsm/n594_s27\: LUT4
generic map (
  INIT => X"AB00"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n594_33,
  I0 => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid_9,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\,
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n578_39);
\u_sdrc_hs_top/u_sdrc_control_fsm/n618_s9\: LUT4
generic map (
  INIT => X"0EE0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n618,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(0),
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(1));
\u_sdrc_hs_top/u_sdrc_control_fsm/n614_s10\: LUT4
generic map (
  INIT => X"0EE0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n614_15,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n614,
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(3));
\u_sdrc_hs_top/u_sdrc_control_fsm/n612_s9\: LUT4
generic map (
  INIT => X"0EE0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n612,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(4),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n610_13);
\u_sdrc_hs_top/u_sdrc_control_fsm/n608_s10\: LUT4
generic map (
  INIT => X"0EE0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n608_15,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\,
  I2 => u_sdrc_hs_top_u_sdrc_control_fsm_n608,
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(6));
\u_sdrc_hs_top/u_sdrc_control_fsm/n606_s9\: LUT4
generic map (
  INIT => X"0EE0"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n606,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\,
  I2 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(7),
  I3 => u_sdrc_hs_top_u_sdrc_control_fsm_n604_15);
\u_sdrc_hs_top/u_sdrc_control_fsm/Ctrl_fsm_addr_col_wrd_7_s5\: LUT3
generic map (
  INIT => X"FE"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_fsm_addr_col_wrd_7_11,
  I0 => I_sdrc_cmd_en,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\);
\u_sdrc_hs_top/Init_cnt_0_s2\: DFFC
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/Init_cnt\(0),
  D => u_sdrc_hs_top_n27,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num_0_s2\: DFFC
generic map (
  INIT => '0'
)
port map (
  Q => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(0),
  D => u_sdrc_hs_top_u_sdrc_control_fsm_n620,
  CLK => I_sdrc_clk,
  CLEAR => u_sdrc_hs_top_n9);
\u_sdrc_hs_top/n27_s3\: LUT2
generic map (
  INIT => X"9"
)
port map (
  F => u_sdrc_hs_top_n27,
  I0 => \u_sdrc_hs_top/Init_cnt\(0),
  I1 => \u_sdrc_hs_top/Init_cnt\(15));
\u_sdrc_hs_top/u_sdrc_control_fsm/n620_s11\: LUT4
generic map (
  INIT => X"01FC"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n620,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\,
  I3 => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_burst_num\(0));
\u_sdrc_hs_top/u_sdrc_control_fsm/n604_s12\: LUT3
generic map (
  INIT => X"FE"
)
port map (
  F => u_sdrc_hs_top_u_sdrc_control_fsm_n604_19,
  I0 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_WRITE_WITHOUT_AUTOPRE\,
  I1 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_READ_WITHOUT_AUTOPRE\,
  I2 => \u_sdrc_hs_top_u_sdrc_control_fsm_Cmd_fsm_state.SDRC_STATE_IDLE\);
\u_sdrc_hs_top/n67_s2\: LUT4
generic map (
  INIT => X"FFFE"
)
port map (
  F => u_sdrc_hs_top_n67,
  I0 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_PRECHARGEALL\,
  I1 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG\,
  I2 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH2\,
  I3 => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_AUTOREFRESH1\);
\u_sdrc_hs_top/n9_s2\: INV
port map (
  O => u_sdrc_hs_top_n9,
  I => I_sdrc_rst_n);
\u_sdrc_hs_top/n207_s2\: INV
port map (
  O => u_sdrc_hs_top_n207,
  I => \u_sdrc_hs_top_Cmd_init_state.INIT_STATE_LOAD_MODEREG\);
\u_sdrc_hs_top/u_sdrc_control_fsm/IO_sdram_dq_0_s3\: INV
port map (
  O => u_sdrc_hs_top_u_sdrc_control_fsm_IO_sdram_dq_0,
  I => u_sdrc_hs_top_u_sdrc_control_fsm_Ctrl_wr_data_valid);
\u_sdrc_hs_top/n66_s2\: INV
port map (
  O => u_sdrc_hs_top_n66,
  I => \u_sdrc_hs_top/Count_init_delay\(0));
\u_sdrc_hs_top/u_sdrc_control_fsm/n86_s2\: INV
port map (
  O => u_sdrc_hs_top_u_sdrc_control_fsm_n86,
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay\(0));
\u_sdrc_hs_top/u_sdrc_control_fsm/n100_s2\: INV
port map (
  O => u_sdrc_hs_top_u_sdrc_control_fsm_n100,
  I => \u_sdrc_hs_top/u_sdrc_control_fsm/Count_cmd_delay2\(0));
\u_sdrc_hs_top/Init_cnt_14_s4\: INV
port map (
  O => u_sdrc_hs_top_Init_cnt_14,
  I => \u_sdrc_hs_top/Init_cnt\(15));
GND_s1: GND
port map (
  G => GND_0);
VCC_s1: VCC
port map (
  V => VCC_0);
GSR_0: GSR
port map (
  GSRI => VCC_0);
  O_sdrc_cmd_ack <= NN;
  O_sdrc_init_done <= NN_0;
end beh;
