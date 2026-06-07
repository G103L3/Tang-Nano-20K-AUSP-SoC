library ieee;
use ieee.std_logic_1164.all;

-- Wishbone shared-bus crossbar: 2 masters (M0 CPU, M1 audio accelerator), 9 slaves.
-- Priority: M1 > M0 when both active simultaneously.
--
-- Decode su 5 bit addr[31:27]: 9 slave non stanno nei 7 nibble raggiungibili dalla
-- CPU (bit31=0, 0x1..0x7), quindi un bit in piu' da 14 finestre da 128 MB.
--   0x4800_0000  01001  S0  SDRAM (via FSM tst_)  [NON 0x1000_0000: range interno IP]
--   0x2000_0000  00100  S6  UART_GENERIC  (caratteri, pin 17/18)
--   0x2800_0000  00101  S7  UART_GENERIC  (comandi NOR dall'ESP32, pin 72/20)
--   0x3000_0000  00110  S5  DMA / audio accelerator control regs
--   0x3800_0000  00111  S8  spi_master_generic (SPI verso chip NOR, pin 42/41/51/48)
--   0x4000_0000  01000  S1  SPI Master (ADC)
--   0x5000_0000  01010  S2  PWM 10-bit
--   0x6000_0000  01100  S3  PWM 4-bit
--   0x7000_0000  01110  S4  GPIO
-- La CPU riceve i comandi storage da S7 (UART) e li esegue su S8 (SPI), come flash_ctrl.
entity wb_interconnect is
    port (
        -- Master 0 (CPU)
        m0_adr_i : in  std_logic_vector(31 downto 0);
        m0_dat_i : in  std_logic_vector(31 downto 0);
        m0_dat_o : out std_logic_vector(31 downto 0);
        m0_we_i  : in  std_logic;
        m0_sel_i : in  std_logic_vector(3 downto 0);
        m0_stb_i : in  std_logic;
        m0_cyc_i : in  std_logic;
        m0_ack_o : out std_logic;
        -- Master 1 (DMA – peripheral access; SDRAM goes directly via memory_arbiter M1)
        m1_adr_i : in  std_logic_vector(31 downto 0);
        m1_dat_i : in  std_logic_vector(31 downto 0);
        m1_dat_o : out std_logic_vector(31 downto 0);
        m1_we_i  : in  std_logic;
        m1_sel_i : in  std_logic_vector(3 downto 0);
        m1_stb_i : in  std_logic;
        m1_cyc_i : in  std_logic;
        m1_ack_o : out std_logic;
        -- Slave 0 – SDRAM arbiter M0
        s0_adr_o : out std_logic_vector(31 downto 0);
        s0_dat_o : out std_logic_vector(31 downto 0);
        s0_dat_i : in  std_logic_vector(31 downto 0);
        s0_we_o  : out std_logic;
        s0_sel_o : out std_logic_vector(3 downto 0);
        s0_stb_o : out std_logic;
        s0_cyc_o : out std_logic;
        s0_ack_i : in  std_logic;
        -- Slave 1 – SPI Master
        s1_adr_o : out std_logic_vector(31 downto 0);
        s1_dat_o : out std_logic_vector(31 downto 0);
        s1_dat_i : in  std_logic_vector(31 downto 0);
        s1_we_o  : out std_logic;
        s1_sel_o : out std_logic_vector(3 downto 0);
        s1_stb_o : out std_logic;
        s1_cyc_o : out std_logic;
        s1_ack_i : in  std_logic;
        -- Slave 2 – PWM 10-bit
        s2_adr_o : out std_logic_vector(31 downto 0);
        s2_dat_o : out std_logic_vector(31 downto 0);
        s2_dat_i : in  std_logic_vector(31 downto 0);
        s2_we_o  : out std_logic;
        s2_sel_o : out std_logic_vector(3 downto 0);
        s2_stb_o : out std_logic;
        s2_cyc_o : out std_logic;
        s2_ack_i : in  std_logic;
        -- Slave 3 – PWM 4-bit
        s3_adr_o : out std_logic_vector(31 downto 0);
        s3_dat_o : out std_logic_vector(31 downto 0);
        s3_dat_i : in  std_logic_vector(31 downto 0);
        s3_we_o  : out std_logic;
        s3_sel_o : out std_logic_vector(3 downto 0);
        s3_stb_o : out std_logic;
        s3_cyc_o : out std_logic;
        s3_ack_i : in  std_logic;
        -- Slave 4 – GPIO
        s4_adr_o : out std_logic_vector(31 downto 0);
        s4_dat_o : out std_logic_vector(31 downto 0);
        s4_dat_i : in  std_logic_vector(31 downto 0);
        s4_we_o  : out std_logic;
        s4_sel_o : out std_logic_vector(3 downto 0);
        s4_stb_o : out std_logic;
        s4_cyc_o : out std_logic;
        s4_ack_i : in  std_logic;
        -- Slave 5 – DMA control registers
        s5_adr_o : out std_logic_vector(31 downto 0);
        s5_dat_o : out std_logic_vector(31 downto 0);
        s5_dat_i : in  std_logic_vector(31 downto 0);
        s5_we_o  : out std_logic;
        s5_sel_o : out std_logic_vector(3 downto 0);
        s5_stb_o : out std_logic;
        s5_cyc_o : out std_logic;
        s5_ack_i : in  std_logic;
        -- Slave 6 – reserved
        s6_adr_o : out std_logic_vector(31 downto 0);
        s6_dat_o : out std_logic_vector(31 downto 0);
        s6_dat_i : in  std_logic_vector(31 downto 0);
        s6_we_o  : out std_logic;
        s6_sel_o : out std_logic_vector(3 downto 0);
        s6_stb_o : out std_logic;
        s6_cyc_o : out std_logic;
        s6_ack_i : in  std_logic;
        -- Slave 7 – reserved
        s7_adr_o : out std_logic_vector(31 downto 0);
        s7_dat_o : out std_logic_vector(31 downto 0);
        s7_dat_i : in  std_logic_vector(31 downto 0);
        s7_we_o  : out std_logic;
        s7_sel_o : out std_logic_vector(3 downto 0);
        s7_stb_o : out std_logic;
        s7_cyc_o : out std_logic;
        s7_ack_i : in  std_logic;
        -- Slave 8 – NOR flash SPI engine (spi_master_generic)
        s8_adr_o : out std_logic_vector(31 downto 0);
        s8_dat_o : out std_logic_vector(31 downto 0);
        s8_dat_i : in  std_logic_vector(31 downto 0);
        s8_we_o  : out std_logic;
        s8_sel_o : out std_logic_vector(3 downto 0);
        s8_stb_o : out std_logic;
        s8_cyc_o : out std_logic;
        s8_ack_i : in  std_logic
    );
end wb_interconnect;

architecture behavioral of wb_interconnect is

    signal sel_adr : std_logic_vector(31 downto 0);
    signal sel_dat : std_logic_vector(31 downto 0);
    signal sel_we  : std_logic;
    signal sel_sel : std_logic_vector(3 downto 0);
    signal sel_stb : std_logic;
    signal sel_cyc : std_logic;
    signal sel_m1  : std_logic;

    -- Slave index (0-8) decoded from address bits [31:27] (5 bit -> 9 slaves + sink).
    -- 9 slave non stanno in 7 nibble (4 bit, CPU raggiunge 0x1..0x7): un bit in piu'
    -- spezza ogni nibble in due finestre da 128 MB. Index 9 = sink non mappato.
    signal slv_idx : integer range 0 to 9;

    signal slv_dat : std_logic_vector(31 downto 0);
    signal slv_ack : std_logic;

    type dat_array_t is array(0 to 9) of std_logic_vector(31 downto 0);
    type ack_array_t is array(0 to 9) of std_logic;
    signal slv_dat_arr : dat_array_t;
    signal slv_ack_arr : ack_array_t;

begin

    -- Il Mux M1 (DMA) vince su M0 (CPU)
    sel_m1  <= '1' when (m1_cyc_i = '1' and m1_stb_i = '1') else '0';
    sel_adr <= m1_adr_i when sel_m1 = '1' else m0_adr_i;
    sel_dat <= m1_dat_i when sel_m1 = '1' else m0_dat_i;
    sel_we  <= m1_we_i  when sel_m1 = '1' else m0_we_i;
    sel_sel <= m1_sel_i when sel_m1 = '1' else m0_sel_i;
    sel_stb <= m1_stb_i when sel_m1 = '1' else m0_stb_i;
    sel_cyc <= m1_cyc_i when sel_m1 = '1' else m0_cyc_i;

    process(sel_adr)
    begin
        case sel_adr(31 downto 27) is
            when "01001" => slv_idx <= 0;  -- 0x4800_0000  SDRAM (FSM tst_). NB: NON 0x1000_0000:
                                           -- gli indirizzi con adr[31:29]=000 (0x0..0x1FFF_FFFF)
                                           -- sono il range INTERNO dell'IP (DTCM/ITCM/simpleuart)
                                           -- e le letture esterne li' non completano mai (hang).
            when "00100" => slv_idx <= 6;  -- 0x2000_0000  UART_GENERIC (caratteri)
            when "00101" => slv_idx <= 7;  -- 0x2800_0000  UART_GENERIC (comandi NOR)
            when "00110" => slv_idx <= 5;  -- 0x3000_0000  DMA / audio accelerator
            when "00111" => slv_idx <= 8;  -- 0x3800_0000  spi_master_generic (SPI NOR)
            when "01000" => slv_idx <= 1;  -- 0x4000_0000  SPI (ADC)
            when "01010" => slv_idx <= 2;  -- 0x5000_0000  PWM10
            when "01100" => slv_idx <= 3;  -- 0x6000_0000  PWM4
            when "01110" => slv_idx <= 4;  -- 0x7000_0000  GPIO
            when others  => slv_idx <= 9;  -- non mappato -> sink
        end case;
    end process;

    -- Broadcast address/data/we to all slaves; gate stb/cyc per slave
    s0_adr_o <= sel_adr; s0_dat_o <= sel_dat; s0_we_o <= sel_we; s0_sel_o <= sel_sel;
    s1_adr_o <= sel_adr; s1_dat_o <= sel_dat; s1_we_o <= sel_we; s1_sel_o <= sel_sel;
    s2_adr_o <= sel_adr; s2_dat_o <= sel_dat; s2_we_o <= sel_we; s2_sel_o <= sel_sel;
    s3_adr_o <= sel_adr; s3_dat_o <= sel_dat; s3_we_o <= sel_we; s3_sel_o <= sel_sel;
    s4_adr_o <= sel_adr; s4_dat_o <= sel_dat; s4_we_o <= sel_we; s4_sel_o <= sel_sel;
    s5_adr_o <= sel_adr; s5_dat_o <= sel_dat; s5_we_o <= sel_we; s5_sel_o <= sel_sel;
    s6_adr_o <= sel_adr; s6_dat_o <= sel_dat; s6_we_o <= sel_we; s6_sel_o <= sel_sel;
    s7_adr_o <= sel_adr; s7_dat_o <= sel_dat; s7_we_o <= sel_we; s7_sel_o <= sel_sel;
    s8_adr_o <= sel_adr; s8_dat_o <= sel_dat; s8_we_o <= sel_we; s8_sel_o <= sel_sel;

    s0_stb_o <= sel_stb when slv_idx = 0 else '0';
    s0_cyc_o <= sel_cyc when slv_idx = 0 else '0';
    s1_stb_o <= sel_stb when slv_idx = 1 else '0';
    s1_cyc_o <= sel_cyc when slv_idx = 1 else '0';
    s2_stb_o <= sel_stb when slv_idx = 2 else '0';
    s2_cyc_o <= sel_cyc when slv_idx = 2 else '0';
    s3_stb_o <= sel_stb when slv_idx = 3 else '0';
    s3_cyc_o <= sel_cyc when slv_idx = 3 else '0';
    s4_stb_o <= sel_stb when slv_idx = 4 else '0';
    s4_cyc_o <= sel_cyc when slv_idx = 4 else '0';
    s5_stb_o <= sel_stb when slv_idx = 5 else '0';
    s5_cyc_o <= sel_cyc when slv_idx = 5 else '0';
    s6_stb_o <= sel_stb when slv_idx = 6 else '0';
    s6_cyc_o <= sel_cyc when slv_idx = 6 else '0';
    s7_stb_o <= sel_stb when slv_idx = 7 else '0';
    s7_cyc_o <= sel_cyc when slv_idx = 7 else '0';
    s8_stb_o <= sel_stb when slv_idx = 8 else '0';
    s8_cyc_o <= sel_cyc when slv_idx = 8 else '0';

    -- Slave read-data/ack arrays for clean mux
    slv_dat_arr(0) <= s0_dat_i; slv_ack_arr(0) <= s0_ack_i;
    slv_dat_arr(1) <= s1_dat_i; slv_ack_arr(1) <= s1_ack_i;
    slv_dat_arr(2) <= s2_dat_i; slv_ack_arr(2) <= s2_ack_i;
    slv_dat_arr(3) <= s3_dat_i; slv_ack_arr(3) <= s3_ack_i;
    slv_dat_arr(4) <= s4_dat_i; slv_ack_arr(4) <= s4_ack_i;
    slv_dat_arr(5) <= s5_dat_i; slv_ack_arr(5) <= s5_ack_i;
    slv_dat_arr(6) <= s6_dat_i; slv_ack_arr(6) <= s6_ack_i;
    slv_dat_arr(7) <= s7_dat_i; slv_ack_arr(7) <= s7_ack_i;
    slv_dat_arr(8) <= s8_dat_i; slv_ack_arr(8) <= s8_ack_i;
    slv_dat_arr(9) <= (others => '0'); slv_ack_arr(9) <= '0';  -- sink non mappato

    slv_dat <= slv_dat_arr(slv_idx);
    slv_ack <= slv_ack_arr(slv_idx);

    m0_dat_o <= slv_dat;
    m1_dat_o <= slv_dat;
    m0_ack_o <= slv_ack and not sel_m1;
    m1_ack_o <= slv_ack and     sel_m1;

end behavioral;
