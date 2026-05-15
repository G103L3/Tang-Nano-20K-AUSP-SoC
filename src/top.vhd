library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_system is
    port (
        clk_i        : in  std_logic;
        rst_i        : in  std_logic;
        ser_tx       : out std_logic;
        ser_rx       : in  std_logic;
        mosi_p       : out std_logic;
        miso_p       : in  std_logic;
        sck_p        : out std_logic;
        cs_p         : out std_logic;
        pwm_10_o     : out std_logic;
        pwm_4_o      : out std_logic;
        gpio_1_o     : out std_logic;
        irq_led_o    : out std_logic;
        fft_trig_led_o : out std_logic;
        ausp_dbg_o   : out std_logic;
        sdram_nz_o   : out std_logic;
        uart_ext_tx  : out std_logic;
        uart_ext_rx  : in  std_logic;
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

-- ATTENZIONE: rst_i (pin 88, active-low) risulta stuck a '0' sulla scheda in uso.
-- Qualsiasi processo con "if rst_i = '0' then" rimane bloccato in reset per sempre.
-- Non usare rst_i come condizione nei processi: usare solo inizializzazione VHDL (signal := ...).
--
-- CLOCK: clk_i = 27 MHz (pin 4). rPLL → clk_sdram 108 MHz per memory_arbiter/SDRAM.
-- Tutto il resto (CPU, DMA, SPI, PWM, GPIO) gira a 27 MHz.
architecture behavioral of top_system is

    component Gowin_rPLL
        port (
            clkout : out std_logic;
            lock   : out std_logic;
            clkin  : in  std_logic
        );
    end component;

    component wb_interconnect
        port (
            m0_adr_i : in std_logic_vector(31 downto 0); m0_dat_i : in std_logic_vector(31 downto 0); m0_dat_o : out std_logic_vector(31 downto 0);
            m0_we_i  : in std_logic; m0_sel_i : in std_logic_vector(3 downto 0); m0_stb_i : in std_logic; m0_cyc_i : in std_logic; m0_ack_o : out std_logic;
            m1_adr_i : in std_logic_vector(31 downto 0); m1_dat_i : in std_logic_vector(31 downto 0); m1_dat_o : out std_logic_vector(31 downto 0);
            m1_we_i  : in std_logic; m1_sel_i : in std_logic_vector(3 downto 0); m1_stb_i : in std_logic; m1_cyc_i : in std_logic; m1_ack_o : out std_logic;
            s0_adr_o : out std_logic_vector(31 downto 0); s0_dat_o : out std_logic_vector(31 downto 0); s0_dat_i : in std_logic_vector(31 downto 0);
            s0_we_o  : out std_logic; s0_sel_o : out std_logic_vector(3 downto 0); s0_stb_o : out std_logic; s0_cyc_o : out std_logic; s0_ack_i : in std_logic;
            s1_adr_o : out std_logic_vector(31 downto 0); s1_dat_o : out std_logic_vector(31 downto 0); s1_dat_i : in std_logic_vector(31 downto 0);
            s1_we_o  : out std_logic; s1_sel_o : out std_logic_vector(3 downto 0); s1_stb_o : out std_logic; s1_cyc_o : out std_logic; s1_ack_i : in std_logic;
            s2_adr_o : out std_logic_vector(31 downto 0); s2_dat_o : out std_logic_vector(31 downto 0); s2_dat_i : in std_logic_vector(31 downto 0);
            s2_we_o  : out std_logic; s2_sel_o : out std_logic_vector(3 downto 0); s2_stb_o : out std_logic; s2_cyc_o : out std_logic; s2_ack_i : in std_logic;
            s3_adr_o : out std_logic_vector(31 downto 0); s3_dat_o : out std_logic_vector(31 downto 0); s3_dat_i : in std_logic_vector(31 downto 0);
            s3_we_o  : out std_logic; s3_sel_o : out std_logic_vector(3 downto 0); s3_stb_o : out std_logic; s3_cyc_o : out std_logic; s3_ack_i : in std_logic;
            s4_adr_o : out std_logic_vector(31 downto 0); s4_dat_o : out std_logic_vector(31 downto 0); s4_dat_i : in std_logic_vector(31 downto 0);
            s4_we_o  : out std_logic; s4_sel_o : out std_logic_vector(3 downto 0); s4_stb_o : out std_logic; s4_cyc_o : out std_logic; s4_ack_i : in std_logic;
            s5_adr_o : out std_logic_vector(31 downto 0); s5_dat_o : out std_logic_vector(31 downto 0); s5_dat_i : in std_logic_vector(31 downto 0);
            s5_we_o  : out std_logic; s5_sel_o : out std_logic_vector(3 downto 0); s5_stb_o : out std_logic; s5_cyc_o : out std_logic; s5_ack_i : in std_logic;
            s6_adr_o : out std_logic_vector(31 downto 0); s6_dat_o : out std_logic_vector(31 downto 0); s6_dat_i : in std_logic_vector(31 downto 0);
            s6_we_o  : out std_logic; s6_sel_o : out std_logic_vector(3 downto 0); s6_stb_o : out std_logic; s6_cyc_o : out std_logic; s6_ack_i : in std_logic;
            s7_adr_o : out std_logic_vector(31 downto 0); s7_dat_o : out std_logic_vector(31 downto 0); s7_dat_i : in std_logic_vector(31 downto 0);
            s7_we_o  : out std_logic; s7_sel_o : out std_logic_vector(3 downto 0); s7_stb_o : out std_logic; s7_cyc_o : out std_logic; s7_ack_i : in std_logic
        );
    end component;

    -- memory_arbiter commentato: test diretto SDRAM inline in top.vhd
    -- component memory_arbiter ... end component;

    component SDRAM_Controller_HS_Top
        port (
            O_sdram_clk           : out   std_logic;
            O_sdram_cke           : out   std_logic;
            O_sdram_cs_n          : out   std_logic;
            O_sdram_cas_n         : out   std_logic;
            O_sdram_ras_n         : out   std_logic;
            O_sdram_wen_n         : out   std_logic;
            O_sdram_dqm           : out   std_logic_vector(3 downto 0);
            O_sdram_addr          : out   std_logic_vector(10 downto 0);
            O_sdram_ba            : out   std_logic_vector(1 downto 0);
            IO_sdram_dq           : inout std_logic_vector(31 downto 0);
            I_sdrc_rst_n          : in    std_logic;
            I_sdrc_clk            : in    std_logic;
            I_sdram_clk           : in    std_logic;
            I_sdrc_cmd_en         : in    std_logic;
            I_sdrc_cmd            : in    std_logic_vector(2 downto 0);
            I_sdrc_precharge_ctrl : in    std_logic;
            I_sdram_power_down    : in    std_logic;
            I_sdram_selfrefresh   : in    std_logic;
            I_sdrc_addr           : in    std_logic_vector(20 downto 0);
            I_sdrc_dqm            : in    std_logic_vector(3 downto 0);
            I_sdrc_data           : in    std_logic_vector(31 downto 0);
            I_sdrc_data_len       : in    std_logic_vector(7 downto 0);
            O_sdrc_data           : out   std_logic_vector(31 downto 0);
            O_sdrc_init_done      : out   std_logic;
            O_sdrc_cmd_ack        : out   std_logic
        );
    end component;

    component spi_master
        port (
            clk_i : in std_logic; rst_i : in std_logic; cyc_i : in std_logic; stb_i : in std_logic;
            we_i  : in std_logic; adr_i : in std_logic_vector(7 downto 0); dat_i : in std_logic_vector(31 downto 0);
            dat_o : out std_logic_vector(31 downto 0); ack_o : out std_logic;
            data_ready_o : out std_logic;
            dbg_cap_o : out std_logic;
            mosi : out std_logic; miso : in std_logic; sck : out std_logic; cs : out std_logic
        );
    end component;

    component pwm_generic
        generic ( nbit : integer := 10 );
        port (
            clk_i : in std_logic; rst_i : in std_logic; cyc_i : in std_logic; stb_i : in std_logic;
            we_i  : in std_logic; adr_i : in std_logic_vector(7 downto 0); dat_i : in std_logic_vector(31 downto 0);
            dat_o : out std_logic_vector(31 downto 0); ack_o : out std_logic; pwm_o : out std_logic
        );
    end component;

    component gpio_generic
        generic ( nbit : integer := 8 );
        port (
            clk_i : in std_logic; rst_i : in std_logic; cyc_i : in std_logic; stb_i : in std_logic;
            we_i  : in std_logic; adr_i : in std_logic_vector(7 downto 0); dat_i : in std_logic_vector(31 downto 0);
            dat_o : out std_logic_vector(31 downto 0); ack_o : out std_logic;
            gpio_i : in std_logic_vector(nbit-1 downto 0); gpio_o : out std_logic_vector(nbit-1 downto 0)
        );
    end component;

    component dma
        port (
            clk_i   : in  std_logic; rst_i   : in  std_logic;
            s_cyc_i : in  std_logic; s_stb_i : in  std_logic; s_we_i  : in  std_logic;
            s_adr_i : in  std_logic_vector(31 downto 0); s_dat_i : in  std_logic_vector(31 downto 0);
            s_dat_o : out std_logic_vector(31 downto 0); s_ack_o : out std_logic;
            m_cyc_o : out std_logic; m_stb_o : out std_logic; m_we_o  : out std_logic;
            m_adr_o : out std_logic_vector(31 downto 0); m_dat_o : out std_logic_vector(31 downto 0);
            m_dat_i : in  std_logic_vector(31 downto 0); m_ack_i : in  std_logic;
            spi_data_ready_i : in  std_logic;
            irq_o          : out std_logic;
            fft_trigger_o  : out std_logic;
            fft_dbg_o      : out std_logic;
            fft_ack_dbg_o  : out std_logic;
            fft_ser_o      : out std_logic;
            fft_idx_o      : out std_logic_vector(8 downto 0);
            fft_xk_re_o    : out std_logic_vector(15 downto 0);
            fft_opd_o      : out std_logic
        );
    end component;

    -- ── Slave wires ────────────────────────────────────────────────────────────
    signal s0_adr, s0_wdata, s0_rdata : std_logic_vector(31 downto 0);
    signal s0_stb, s0_we, s0_cyc, s0_ack : std_logic;
    signal s0_sel : std_logic_vector(3 downto 0);

    signal s1_adr, s1_wdata, s1_rdata : std_logic_vector(31 downto 0);
    signal s1_stb, s1_we, s1_cyc, s1_ack : std_logic;
    signal s1_sel : std_logic_vector(3 downto 0);

    signal s2_adr, s2_wdata, s2_rdata : std_logic_vector(31 downto 0);
    signal s2_stb, s2_we, s2_cyc, s2_ack : std_logic;
    signal s2_sel : std_logic_vector(3 downto 0);

    signal s3_adr, s3_wdata, s3_rdata : std_logic_vector(31 downto 0);
    signal s3_stb, s3_we, s3_cyc, s3_ack : std_logic;
    signal s3_sel : std_logic_vector(3 downto 0);

    signal s4_adr, s4_wdata, s4_rdata : std_logic_vector(31 downto 0);
    signal s4_stb, s4_we, s4_cyc, s4_ack : std_logic;
    signal s4_sel : std_logic_vector(3 downto 0);

    signal s5_adr, s5_wdata, s5_rdata : std_logic_vector(31 downto 0);
    signal s5_stb, s5_we, s5_cyc, s5_ack : std_logic;
    signal s5_sel : std_logic_vector(3 downto 0);

    signal s6_adr, s6_wdata, s6_rdata : std_logic_vector(31 downto 0);
    signal s6_stb, s6_we, s6_cyc, s6_ack : std_logic;
    signal s6_sel : std_logic_vector(3 downto 0);

    signal dummy_dat : std_logic_vector(31 downto 0) := (others => '0');

    -- ── DMA master bus ─────────────────────────────────────────────────────────
    signal dma_m_adr, dma_m_wdat : std_logic_vector(31 downto 0);
    signal dma_m_we, dma_m_stb, dma_m_cyc : std_logic;
    signal dma_m_rdat  : std_logic_vector(31 downto 0);
    signal dma_m_ack_s : std_logic;
    signal dma_to_sdram : std_logic;
    signal dma_wb_rdat, dma_rdata : std_logic_vector(31 downto 0);
    signal dma_wb_ack, dma_ack : std_logic;
    signal dma_cyc_s, dma_stb_s, dma_we_s : std_logic;
    signal dma_adr_s, dma_wdata_s : std_logic_vector(31 downto 0);
    signal dma_irq        : std_logic;
    signal dma_fft_trig   : std_logic;
    signal sdram_init_done : std_logic;
    signal fft_trig_led_s : std_logic := '0';
    signal wr_ack_seen_s   : std_logic;
    signal rd_ack_seen_s   : std_logic;

    -- ── Test diretto SDRAM (inline in top.vhd, bypassa memory_arbiter) ──────────
    -- FSM: scrive 0xA55A1234 ad addr 0, rilegge ogni 0.3s, manda hex via UART
    signal tst_cmd_en   : std_logic := '0';
    signal tst_cmd      : std_logic_vector(2 downto 0) := "111";
    signal tst_addr     : std_logic_vector(20 downto 0) := (others => '0');
    signal tst_wr_data  : std_logic_vector(31 downto 0) := (others => '0');
    signal tst_rd_data  : std_logic_vector(31 downto 0);
    signal tst_init_done : std_logic;
    -- FSM state
    type tst_st_t is (TS_INIT, TS_WRITE, TS_WR_WAIT, TS_READ, TS_RD_WAIT, TS_TX, TS_PAUSE);
    signal tst_st       : tst_st_t := TS_INIT;
    signal tst_timer    : unsigned(25 downto 0) := (others => '0');
    signal tst_rd_latch    : std_logic_vector(31 downto 0) := (others => '0');
    signal tst_rd_latch_8  : std_logic_vector(31 downto 0) := (others => '0');
    signal tst_rd_latch_10 : std_logic_vector(31 downto 0) := (others => '0');
    signal tst_rd_latch_12 : std_logic_vector(31 downto 0) := (others => '0');
    signal tst_rd_latch_14 : std_logic_vector(31 downto 0) := (others => '0');
    signal tst_tx_seq   : integer range 0 to 47 := 0;
    -- UART TX @ 108 MHz: divisore 937 per 115200 baud
    signal tst_baud_cnt  : unsigned(9 downto 0) := (others => '0');  -- max 1023, serve 936
    signal tst_baud_tick : std_logic := '0';
    signal tst_tx_sr     : std_logic_vector(9 downto 0) := (others => '1');
    signal tst_tx_cnt    : unsigned(3 downto 0) := (others => '0');
    signal tst_tx_busy   : std_logic := '0';
    signal tst_tx_load   : std_logic := '0';
    signal tst_tx_byte   : std_logic_vector(7 downto 0) := (others => '0');
    signal test_uart_s   : std_logic;
    signal tst_cmd_ack_s     : std_logic;
    signal tst_wr_ack_latched : std_logic := '0';

    signal spi_data_ready_s : std_logic;
    signal gpio_in_v, gpio_out_v : std_logic_vector(0 downto 0);
    signal pwm10_s, pwm4_s : std_logic;
    signal tone4k_cnt : unsigned(11 downto 0) := (others => '0');
    signal tone4k_out : std_logic := '0';

    -- ── Diagnostic: latch ADC non-zero ───────────────────────────────────────
    signal adc_nonzero : std_logic := '0';

    -- ── AUSP lettura diretta SDRAM (bypassa WB, stesso CDC del DMA m1) ────────
    signal ausp_cyc  : std_logic := '0';
    signal ausp_stb  : std_logic := '0';
    signal ausp_adr  : std_logic_vector(31 downto 0) := (others => '0');
    signal ausp_rdat : std_logic_vector(31 downto 0);
    signal ausp_ack  : std_logic;

    -- ── HW WB master (replaces CPU M0) — inattivo, WB bus idle ──────────────
    signal hm_adr   : std_logic_vector(31 downto 0) := (others => '0');
    signal hm_wdat  : std_logic_vector(31 downto 0) := (others => '0');
    signal hm_stb   : std_logic := '0';
    signal hm_cyc   : std_logic := '0';
    signal hm_we    : std_logic := '0';
    signal hm_rdat  : std_logic_vector(31 downto 0);
    signal hm_ack   : std_logic;


    -- ── FFT magnitude buffer ──────────────────────────────────────────────────
    type mag_array_t is array(0 to 511) of unsigned(14 downto 0);
    signal mag : mag_array_t := (others => (others => '0'));

    -- ── PWM period tables ──────────────────────────────────────────────────────
    -- f_data = 1000 + code*400 Hz,  period = 27_000_000 / f_data
    type data_period_t is array(0 to 17) of integer range 0 to 27001;
    constant C_DP : data_period_t := (
        27000, 19286, 15000, 12273, 10385, 9000, 7941, 7105,
        6429,  5870,  5400,  5000,  4655,  4355, 4091, 3857, 3649, 3462
    );
    -- f_carrier = 8200 + channel*400 Hz,  period = 27_000_000 / f_carrier
    type carr_period_t is array(0 to 2) of integer range 0 to 3294;
    constant C_CP : carr_period_t := (3293, 3140, 3000);

    -- ── AUSP main FSM ──────────────────────────────────────────────────────────
    type ausp_st_t is (
        ST_BOOT_START, ST_BOOT_DATA, ST_BOOT_STOP,
        ST_TX_LOOP_DELAY,
        ST_DMA_INIT, ST_DMA_ACK,
        ST_IDLE,
        ST_RD_ISSUE, ST_RD_WAIT,
        ST_NOISE_CALC,
        ST_PEAK_SCAN,
        ST_PARAB_CALC,
        ST_DECODE,
        ST_TX_CHAR_START, ST_TX_CHAR_DATA, ST_TX_CHAR_STOP,
        ST_RXDEC,
        ST_PWM_STOP0, ST_PWM_STOP0_ACK,
        ST_PWM_START_T, ST_PWM_START_ACK,
        ST_TONE_WAIT,
        ST_PWM_FINAL, ST_PWM_FINAL_ACK,
        ST_SILENCE
    );
    signal ausp_st : ausp_st_t := ST_BOOT_START;

    -- ── LED: conta IRQ DMA, bit 6 del contatore → toggle ogni 64 IRQ ≈ 700ms ──
    -- IRQ rate ≈ 46875/512 ≈ 91 Hz → bit6 toglla ogni 64/91 ≈ 0.7s (visibile)
    signal irq_cnt    : unsigned(6 downto 0) := (others => '0');
    signal led_mode   : std_logic := '0';
    signal led_cnt    : unsigned(23 downto 0) := (others => '0');
    signal blink_led  : std_logic := '0';
    signal pwm4_duty  : unsigned(5 downto 0) := (others => '0');
    -- signal pwm4_ctr  : unsigned(5 downto 0) := (others => '0');  -- [LED PWM6 commentato]
    -- signal pwm4_out  : std_logic := '0';                          -- [LED PWM6 commentato]
    signal dma_stb_wb : std_logic;
    signal dma_cyc_wb : std_logic;
    signal irq_led_s  : std_logic := '0';
    signal fft_dbg_s      : std_logic := '0';
    signal fft_ack_dbg_s  : std_logic := '0';
    signal fft_ser_s      : std_logic := '0';
    signal fft_idx_s      : std_logic_vector(8 downto 0);
    signal fft_xk_re_s    : std_logic_vector(15 downto 0);
    signal fft_opd_s      : std_logic;
    signal ausp_irq_prev  : std_logic := '0';

    -- ── AUSP debug output ──────────────────────────────────────────────────────
    signal ausp_result  : std_logic_vector(31 downto 0) := (others => '0');
    signal ausp_dbg_s   : std_logic := '0';
    signal sdram_nz_s   : std_logic := '0';
    signal spi_dbg_cap  : std_logic := '0';

    -- ── AUSP multi-bin scan ────────────────────────────────────────────────────
    -- Signal code 8 = 4200 Hz → bins 44-47 (resolution 91.55 Hz/bin)
    -- Master Carrier  = 8200 Hz → bins 88-91
    signal rd_scan_idx   : integer range 0 to 7 := 0;
    signal sig_max_u     : unsigned(14 downto 0) := (others => '0');
    signal carr_max_u    : unsigned(14 downto 0) := (others => '0');
    constant C_DETECT_THR     : unsigned(14 downto 0) := to_unsigned(3, 15);

    -- ── Carrier square-wave: 8200 Hz, half-period = 1646 cycles @ 27 MHz ─────
    signal carr_cnt  : unsigned(10 downto 0) := (others => '0');
    signal carr_out  : std_logic := '0';

    -- ── UART TX (shared: boot string + decoded chars) ─────────────────────────
    constant C_BAUD_DIV : integer := 234;
    signal utx_pin  : std_logic := '1';
    signal utx_baud : integer range 0 to 233 := 0;
    signal utx_bitc : integer range 0 to 7   := 0;
    signal utx_sreg : std_logic_vector(7 downto 0) := (others => '1');
    signal utx_byte : std_logic_vector(7 downto 0) := (others => '1');

    constant C_BOOT_LEN : integer := 13;
    type boot_rom_t is array(0 to 12) of std_logic_vector(7 downto 0);
    constant C_BOOT_STR : boot_rom_t := (
        x"0D", x"0A",
        x"5B", x"42", x"4F", x"4F", x"54", x"5D",
        x"20", x"6F", x"6B",
        x"0D", x"0A"
    );
    signal boot_idx : integer range 0 to 12 := 0;

    -- ── UART RX ────────────────────────────────────────────────────────────────
    type urx_st_t is (RX_IDLE, RX_START, RX_DATA, RX_STOP);
    signal urx_st   : urx_st_t := RX_IDLE;
    signal urx_baud : integer range 0 to 350 := 0;
    signal urx_bitc : integer range 0 to 7   := 0;
    signal urx_sreg : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_char  : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_valid : std_logic := '0';

    -- ── FFT analysis signals ───────────────────────────────────────────────────
    signal bin_idx   : integer range 0 to 511 := 0;
    signal mag_sum   : unsigned(24 downto 0) := (others => '0');
    signal noise_thr : unsigned(18 downto 0) := (others => '0');

    signal peak_d_bin : integer range 0 to 511 := 0;
    signal peak_d_mag : unsigned(14 downto 0) := (others => '0');
    signal peak_c_bin : integer range 0 to 511 := 0;
    signal peak_c_mag : unsigned(14 downto 0) := (others => '0');
    signal scan_i     : integer range 0 to 511 := 0;

    signal eff_d_bin : integer range 0 to 511 := 0;
    signal eff_c_bin : integer range 0 to 511 := 0;
    signal tx_char_r : std_logic_vector(7 downto 0) := (others => '0');

    -- ── PWM tone emission ──────────────────────────────────────────────────────
    signal tone_channel : integer range 0 to 2  := 0;
    signal tone_code    : integer range 0 to 17 := 0;
    signal tone_pair    : integer range 0 to 24 := 0;  -- 12 pairs × 2 phases
    signal tone_cnt     : unsigned(21 downto 0) := (others => '0');

    signal dma_irq_prev   : std_logic := '0';
    signal clk_sdram_cnt  : unsigned(26 downto 0) := (others => '0');

    -- ── Standalone UART TX: "FPGA ON\r\n" @ 115200 8N1 ───────────────────────
    -- Baud divisor = 27_000_000 / 115200 = 234 cicli/bit
    type boot_tx_st_t is (BTX_START, BTX_DATA, BTX_STOP, BTX_NEXT, BTX_DONE);
    signal boot_tx_st   : boot_tx_st_t := BTX_START;
    signal boot_tx_pin  : std_logic := '1';
    signal boot_tx_baud : integer range 0 to 233 := 0;
    signal boot_tx_bitc : integer range 0 to 7   := 0;
    signal boot_tx_sreg : std_logic_vector(7 downto 0) := (others => '1');
    signal boot_tx_idx  : integer range 0 to 8  := 0;

    constant C_BOOT_TX_LEN : integer := 9;
    type boot_tx_rom_t is array(0 to 8) of std_logic_vector(7 downto 0);
    -- "FPGA ON\r\n"
    constant C_BOOT_TX_STR : boot_tx_rom_t := (
        x"46", x"50", x"47", x"41", x"20", x"4F", x"4E", x"0D", x"0A"
    );

    -- ── Results UART TX: bin AUSP → ASCII decimale ───────────────────────────
    signal boot_done         : std_logic := '0';
    type ausp_mag_t is array(0 to 7) of unsigned(14 downto 0);
    signal ausp_mag_buf      : ausp_mag_t := (others => (others => '0'));
    signal fft_direct_buf    : ausp_mag_t := (others => (others => '0'));
    signal ausp_results_rdy  : std_logic := '0';
    signal ausp_results_ltch : std_logic := '0';

    type rtx_st_t is (
        RTX_IDLE, RTX_CONV, RTX_NEXT_DIGIT,
        RTX_BYTE_START, RTX_BYTE_BITS, RTX_BYTE_STOP,
        RTX_AFTER_SEP, RTX_AFTER_CR
    );
    signal rtx_st      : rtx_st_t := RTX_IDLE;
    signal rtx_next_st : rtx_st_t := RTX_IDLE;
    signal rtx_pin     : std_logic := '1';
    signal rtx_baud    : integer range 0 to 233 := 0;
    signal rtx_bitc    : integer range 0 to 7   := 0;
    signal rtx_sreg    : std_logic_vector(7 downto 0) := (others => '1');
    signal rtx_val_idx : integer range 0 to 7 := 0;
    signal rtx_dig_idx : integer range 0 to 5 := 0;
    type rtx_dig_t is array(0 to 4) of std_logic_vector(7 downto 0);
    signal rtx_digs    : rtx_dig_t := (others => x"30");

    -- ── PLL clock (108 MHz) e lock ─────────────────────────────────────────────
    signal clk_sdram : std_logic;
    signal pll_lock  : std_logic;

begin

    -- ── PLL: 27 MHz → 108 MHz ────────────────────────────────────────────────
    u_pll: Gowin_rPLL
    port map (
        clkin  => clk_i,
        clkout => clk_sdram,
        lock   => pll_lock
    );

    -- ── Fixed outputs ──────────────────────────────────────────────────────────
    ser_tx      <= '1';
    gpio_1_o    <= '1';
    --pwm_4_o     <= irq_cnt(6);  -- toglla ogni 64 DMA-IRQ ≈ 0.7s
    --pwm_10_o    <= pwm10_s;
    --uart_ext_tx <= utx_pin;
    --s6_ack      <= '0';
    --s6_rdata    <= (others => '0');
    gpio_in_v   <= (others => '0');

    -- ── DMA routing: 0x1xxxxxxx → SDRAM arbiter m1, remasto → WB interconnect ──
    dma_to_sdram <= '1' when dma_m_adr(31 downto 28) = "0001" else '0';
    dma_stb_wb   <= dma_m_stb and not dma_to_sdram;
    dma_cyc_wb   <= dma_m_cyc and not dma_to_sdram;
    dma_m_ack_s  <= dma_ack   when dma_to_sdram = '1' else dma_wb_ack;
    dma_m_rdat   <= dma_rdata when dma_to_sdram = '1' else dma_wb_rdat;
    dma_cyc_s    <= dma_m_cyc and dma_to_sdram;
    dma_stb_s    <= dma_m_stb and dma_to_sdram;
    dma_we_s     <= dma_m_we;
    dma_adr_s    <= dma_m_adr;
    dma_wdata_s  <= dma_m_wdat;

    -- ── WB Interconnect ───────────────────────────────────────────────────────
    u_bus: wb_interconnect
    port map (
        m0_adr_i => hm_adr,   m0_dat_i => hm_wdat,  m0_dat_o => hm_rdat,
        m0_we_i  => hm_we,    m0_sel_i => "1111",   m0_stb_i => hm_stb,
        m0_cyc_i => hm_cyc,   m0_ack_o => hm_ack,
        m1_adr_i => dma_m_adr,  m1_dat_i => dma_m_wdat,  m1_dat_o => dma_wb_rdat,
        m1_we_i  => dma_m_we,   m1_sel_i => "1111",
        m1_stb_i => dma_stb_wb,
        m1_cyc_i => dma_cyc_wb,
        m1_ack_o => dma_wb_ack,
        s0_adr_o => s0_adr, s0_dat_o => s0_wdata, s0_dat_i => s0_rdata,
        s0_we_o  => s0_we,  s0_sel_o => s0_sel,   s0_stb_o => s0_stb,  s0_cyc_o => s0_cyc, s0_ack_i => s0_ack,
        s1_adr_o => s1_adr, s1_dat_o => s1_wdata, s1_dat_i => s1_rdata,
        s1_we_o  => s1_we,  s1_sel_o => s1_sel,   s1_stb_o => s1_stb,  s1_cyc_o => s1_cyc, s1_ack_i => s1_ack,
        s2_adr_o => s2_adr, s2_dat_o => s2_wdata, s2_dat_i => s2_rdata,
        s2_we_o  => s2_we,  s2_sel_o => s2_sel,   s2_stb_o => s2_stb,  s2_cyc_o => s2_cyc, s2_ack_i => s2_ack,
        s3_adr_o => s3_adr, s3_dat_o => s3_wdata, s3_dat_i => s3_rdata,
        s3_we_o  => s3_we,  s3_sel_o => s3_sel,   s3_stb_o => s3_stb,  s3_cyc_o => s3_cyc, s3_ack_i => s3_ack,
        s4_adr_o => s4_adr, s4_dat_o => s4_wdata, s4_dat_i => s4_rdata,
        s4_we_o  => s4_we,  s4_sel_o => s4_sel,   s4_stb_o => s4_stb,  s4_cyc_o => s4_cyc, s4_ack_i => s4_ack,
        s5_adr_o => s5_adr, s5_dat_o => s5_wdata, s5_dat_i => s5_rdata,
        s5_we_o  => s5_we,  s5_sel_o => s5_sel,   s5_stb_o => s5_stb,  s5_cyc_o => s5_cyc, s5_ack_i => s5_ack,
        s6_adr_o => s6_adr, s6_dat_o => s6_wdata, s6_dat_i => s6_rdata,
        s6_we_o  => s6_we,  s6_sel_o => s6_sel,   s6_stb_o => s6_stb,  s6_cyc_o => s6_cyc, s6_ack_i => s6_ack,
        s7_adr_o => open, s7_dat_o => open, s7_dat_i => dummy_dat,
        s7_we_o  => open, s7_sel_o => open, s7_stb_o => open, s7_cyc_o => open, s7_ack_i => '0'
    );

    -- s0 port (SDRAM slave slot) unused
    s0_rdata <= (others => '0');
    s0_ack   <= '0';

    -- ── Test diretto SDRAM (niente wishbone, niente arbiter) ──────────────────
    test_uart_s <= tst_tx_sr(0);
    u_sdram_direct: SDRAM_Controller_HS_Top
    port map (
        O_sdram_clk           => O_sdram_clk,
        O_sdram_cke           => O_sdram_cke,
        O_sdram_cs_n          => O_sdram_cs_n,
        O_sdram_cas_n         => O_sdram_cas_n,
        O_sdram_ras_n         => O_sdram_ras_n,
        O_sdram_wen_n         => O_sdram_wen_n,
        O_sdram_dqm           => O_sdram_dqm,
        O_sdram_addr          => O_sdram_addr,
        O_sdram_ba            => O_sdram_ba,
        IO_sdram_dq           => IO_sdram_dq,
        I_sdrc_rst_n          => pll_lock,
        I_sdrc_clk            => clk_sdram,
        I_sdram_clk           => clk_sdram,
        I_sdrc_cmd_en         => tst_cmd_en,
        I_sdrc_cmd            => tst_cmd,
        I_sdrc_precharge_ctrl => '1',
        I_sdram_power_down    => '0',
        I_sdram_selfrefresh   => '0',
        I_sdrc_addr           => tst_addr,
        I_sdrc_dqm            => "0000",
        I_sdrc_data           => tst_wr_data,
        I_sdrc_data_len       => x"00",
        O_sdrc_data           => tst_rd_data,
        O_sdrc_init_done      => tst_init_done,
        O_sdrc_cmd_ack        => tst_cmd_ack_s
    );
    -- Segnali ex-memory_arbiter: default (DMA e AUSP fermi, non interferiscono)
    sdram_init_done <= tst_init_done;
    ausp_ack        <= '0';
    ausp_rdat       <= (others => '0');
    dma_ack         <= '0';
    dma_rdata       <= (others => '0');
    wr_ack_seen_s   <= '0';
    rd_ack_seen_s   <= '0';

    -- ── DMA ───────────────────────────────────────────────────────────────────
    u_dma: dma
    port map (
        clk_i => clk_i,  rst_i => rst_i,
        s_cyc_i => s5_cyc, s_stb_i => s5_stb, s_we_i  => s5_we,
        s_adr_i => s5_adr, s_dat_i => s5_wdata, s_dat_o => s5_rdata, s_ack_o => s5_ack,
        m_cyc_o => dma_m_cyc, m_stb_o => dma_m_stb, m_we_o => dma_m_we,
        m_adr_o => dma_m_adr, m_dat_o => dma_m_wdat,
        m_dat_i => dma_m_rdat, m_ack_i => dma_m_ack_s,
        spi_data_ready_i => spi_data_ready_s,
        irq_o         => dma_irq,
        fft_trigger_o => dma_fft_trig,
        fft_dbg_o     => fft_dbg_s,
        fft_ack_dbg_o => fft_ack_dbg_s,
        fft_ser_o     => fft_ser_s,
        fft_idx_o     => fft_idx_s,
        fft_xk_re_o   => fft_xk_re_s,
        fft_opd_o     => fft_opd_s
    );

    -- ── SPI ───────────────────────────────────────────────────────────────────
    u_spi: spi_master
    port map (
        clk_i => clk_i, rst_i => '1',
        cyc_i => s1_cyc, stb_i => s1_stb, we_i => s1_we,
        adr_i => s1_adr(7 downto 0), dat_i => s1_wdata, dat_o => s1_rdata, ack_o => s1_ack,
        data_ready_o => spi_data_ready_s,
        dbg_cap_o    => spi_dbg_cap,
        mosi => mosi_p, miso => miso_p, sck => sck_p, cs => cs_p
    );

    -- ── PWM10 (audio) ─────────────────────────────────────────────────────────
    u_pwm10: pwm_generic
    generic map ( nbit => 15 )
    port map (
        clk_i => clk_i, rst_i => rst_i,
        cyc_i => s2_cyc, stb_i => s2_stb, we_i => s2_we,
        adr_i => s2_adr(7 downto 0), dat_i => s2_wdata, dat_o => s2_rdata, ack_o => s2_ack,
        pwm_o => pwm10_s
    );

    -- ── PWM4 (LED) ────────────────────────────────────────────────────────────
    u_pwm4: pwm_generic
    generic map ( nbit => 4 )
    port map (
        clk_i => clk_i, rst_i => rst_i,
        cyc_i => s3_cyc, stb_i => s3_stb, we_i => s3_we,
        adr_i => s3_adr(7 downto 0), dat_i => s3_wdata, dat_o => s3_rdata, ack_o => s3_ack,
        pwm_o => pwm4_s
    );

    -- ── GPIO ──────────────────────────────────────────────────────────────────
    u_gpio1: gpio_generic
    generic map ( nbit => 1 )
    port map (
        clk_i => clk_i, rst_i => rst_i,
        cyc_i => s4_cyc, stb_i => s4_stb, we_i => s4_we,
        adr_i => s4_adr(7 downto 0), dat_i => s4_wdata, dat_o => s4_rdata, ack_o => s4_ack,
        gpio_i => gpio_in_v, gpio_o => gpio_out_v
    );

    -- ================================================================
    -- DEBUG FFT+SDRAM: conta IRQ DMA (dopo FFT completa + drain SDRAM)
    -- bit6 toglia ogni 64 IRQ ≈ 0.7s → LED lampeggia = FFT+SDRAM funzionano
    -- ================================================================
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            dma_irq_prev <= dma_irq;
            if dma_irq = '1' and dma_irq_prev = '0' then
                irq_cnt <= irq_cnt + 1;
            end if;
        end if;
    end process;

    -- ================================================================
    -- PWM4 blink: 1 Hz (half-period = 13_500_000 @ 27 MHz)
    -- ================================================================
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if led_cnt >= to_unsigned(13_500_000 - 1, 24) then
                led_cnt   <= (others => '0');
                blink_led <= not blink_led;
            else
                led_cnt <= led_cnt + 1;
            end if;
        end if;
    end process;

    irq_led_o <= pll_lock;  -- ON quando PLL locked (diagnosi: se OFF pll non si blocca)

    -- ================================================================
    -- DEBUG: irq_cnt(6) toglia ogni 64 IRQ DMA ≈ 0.7s
    -- LED LAMPEGGIA → SPI+FFT+SDRAM+IRQ tutti funzionanti (pipeline completa!)
    -- LED FISSO/SPENTO → pipeline bloccata (drain non completa le 512 scritture)
    -- ================================================================
    -- fft_trig_led_o <= irq_cnt(6);

    -- ================================================================
    -- DEBUG SPI: bit 11 (MSB) dell'ultimo campione ADC (s1_rdata = dat_o SPI master)
    -- LED ON  → ADC legge valore ≥ 2048 (sopra metà scala)
    -- LED OFF → ADC legge valore < 2048 (sotto metà scala)
    -- Lampeggio veloce → segnale ADC variabile (microfono attivo, rumore, ecc.)
    -- ================================================================
    -- fft_trig_led_o <= s1_rdata(11);

    -- ================================================================
    -- DEBUG SPI bit0 (LSB): verifica se il dato ADC ha qualsiasi variazione
    -- Flicker → ADC funziona, il valore varia (bit11 saturato ma dati validi)
    -- Fisso ON/OFF → MISO stuck o ADC bloccato
    -- ================================================================
    -- fft_trig_led_o <= s1_rdata(0);

    -- ================================================================
    -- DEBUG MISO raw: LED = segnale fisico MISO (pin 85) in tempo reale
    -- Il LED segue esattamente ogni bit trasmesso dall'MCP3201
    -- ================================================================
    -- fft_trig_led_o <= miso_p;

    -- ================================================================
    -- DEBUG FFT serial: stream bit-per-bit dell'output FFT su pin 53
    -- Formato: 512 word x 16 bit, MSB per primo, 1 bit/ciclo @ 27 MHz (37 ns/bit)
    -- Frame: 8192 cicli = 303 µs ON, poi ~10.6 ms OFF → trigger su fronte di salita
    -- Per leggere: oscilloscopio/LA a ≥ 54 MHz sample rate, trigger su rising edge
    -- ================================================================
    -- DEBUG: pin 53 = wr_ack_seen (cmd_ack WRITE confermato)
    --         pin 86 = rd_ack_seen (M0_RD_WAIT raggiunto = AUSP ottiene il bus)
    -- Se 53 ON, 86 OFF → AUSP non ottiene mai il bus (M1 sempre prioritario?)
    -- Se entrambi ON → write OK + AUSP legge → UART dovrebbe mostrare "32767"
    -- clk_sdram heartbeat: se lampeggia ~0.6s → clk_sdram gira a 108 MHz
    --                       se lampeggia ~2.4s → clk_sdram gira a 27 MHz (PLL non cambiato)
    --                       se fisso         → clk_sdram non toglia (PLL morto)
    fft_trig_led_o <= clk_sdram_cnt(26);

    -- ================================================================
    -- PWM10: onda quadra 4200 Hz — Signal Code 8 (half-period = 3214 @ 27 MHz)
    -- 27e6 / (2*3214) = 4199.75 Hz ≈ 4200 Hz
    -- ================================================================
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if tone4k_cnt >= to_unsigned(3214 - 1, 12) then
                tone4k_cnt <= (others => '0');
                tone4k_out <= not tone4k_out;
            else
                tone4k_cnt <= tone4k_cnt + 1;
            end if;
        end if;
    end process;

    -- ================================================================
    -- PWM4: onda quadra 8200 Hz — Master Carrier ch0 (half-period = 1646 @ 27 MHz)
    -- 27e6 / (2*1646) = 8200.49 Hz ≈ 8200 Hz
    -- Pin 77 temporaneamente riproposto da blink LED a carrier tone per test AUSP
    -- ================================================================
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if carr_cnt >= to_unsigned(1646 - 1, 11) then
                carr_cnt <= (others => '0');
                carr_out <= not carr_out;
            else
                carr_cnt <= carr_cnt + 1;
            end if;
        end if;
    end process;

    pwm_10_o <= tone4k_out;  -- 4200 Hz signal code 8
    pwm_4_o  <= carr_out;    -- 8200 Hz master carrier

    uart_ext_tx  <= test_uart_s;  -- solo test SDRAM; boot msg rimosso per eliminare AND tra domini diversi

    -- pin 49: MISO gated sulla finestra di cattura (bit_cnt 2..13, CS basso)
    -- Media attesa = stessa del raw MISO dopo partitore se timing SPI corretto
    -- ausp_dbg_o <= ausp_dbg_s;   -- AUSP dual-frequency detection
    -- ausp_dbg_o <= miso_p;       -- MISO raw wire
    ausp_dbg_o <= spi_dbg_cap;
    sdram_nz_o <= rd_ack_seen_s;  -- pin 86: cmd_ack visto in READ

    -- WB master m0 inattivo (nessun CPU)
    hm_cyc <= '0';
    hm_stb <= '0';

    -- ================================================================
    -- Standalone UART TX: invia "FPGA ON\r\n" una sola volta all'avvio.
    -- 115200 8N1 @ 27 MHz: 234 cicli/bit. Sconnessa da tutto il resto.
    -- ================================================================
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            case boot_tx_st is

                -- Bit di START: linea bassa per 234 cicli
                when BTX_START =>
                    boot_tx_pin  <= '0';
                    boot_tx_sreg <= C_BOOT_TX_STR(boot_tx_idx);
                    boot_tx_bitc <= 0;
                    if boot_tx_baud = 233 then
                        boot_tx_baud <= 0;
                        boot_tx_st   <= BTX_DATA;
                    else
                        boot_tx_baud <= boot_tx_baud + 1;
                    end if;

                -- 8 bit dati, LSB per primo
                when BTX_DATA =>
                    boot_tx_pin <= boot_tx_sreg(0);
                    if boot_tx_baud = 233 then
                        boot_tx_baud <= 0;
                        boot_tx_sreg <= '1' & boot_tx_sreg(7 downto 1);
                        if boot_tx_bitc = 7 then
                            boot_tx_st <= BTX_STOP;
                        else
                            boot_tx_bitc <= boot_tx_bitc + 1;
                        end if;
                    else
                        boot_tx_baud <= boot_tx_baud + 1;
                    end if;

                -- Bit di STOP: linea alta per 234 cicli
                when BTX_STOP =>
                    boot_tx_pin <= '1';
                    if boot_tx_baud = 233 then
                        boot_tx_baud <= 0;
                        boot_tx_st   <= BTX_NEXT;
                    else
                        boot_tx_baud <= boot_tx_baud + 1;
                    end if;

                when BTX_NEXT =>
                    if boot_tx_idx = C_BOOT_TX_LEN - 1 then
                        boot_tx_st <= BTX_DONE;
                    else
                        boot_tx_idx <= boot_tx_idx + 1;
                        boot_tx_st  <= BTX_START;
                    end if;

                when BTX_DONE =>
                    boot_tx_pin <= '1';
                    boot_done   <= '1';

            end case;
        end if;
    end process;

    -- ================================================================
    -- Cattura diretta FFT: salva |xk_re| dei bin 0-7 appena escono dall'FFT core.
    -- Bypassa completamente la SDRAM — diagnostica pura sul calcolo FFT.
    -- ================================================================
    process(clk_i)
        variable abs_v : unsigned(14 downto 0);
    begin
        if rising_edge(clk_i) then
            if fft_opd_s = '1' and unsigned(fft_idx_s) <= 7 then
                if fft_xk_re_s(15) = '0' then
                    abs_v := unsigned(fft_xk_re_s(14 downto 0));
                else
                    abs_v := unsigned(not fft_xk_re_s(14 downto 0)) + 1;
                end if;
                fft_direct_buf(to_integer(unsigned(fft_idx_s))) <= abs_v;
            end if;
        end if;
    end process;

    -- ================================================================
    -- Results UART TX: dopo "FPGA ON\r\n", ad ogni batch AUSP converte i 8 bin
    -- in decimale ASCII e trasmette "DDDDD,DDDDD,...,DDDDD\r\n" su uart_ext_tx.
    -- Condivide il pin via AND con boot_tx_pin (entrambi '1' quando idle).
    -- ================================================================
    process(clk_i)
        variable v : integer range 0 to 32767;
    begin
        if rising_edge(clk_i) then
            if ausp_results_rdy = '1' then
                ausp_results_ltch <= '1';
            end if;

            case rtx_st is

                when RTX_IDLE =>
                    if boot_done = '1' and ausp_results_ltch = '1' then
                        ausp_results_ltch <= '0';
                        rtx_val_idx <= 0;
                        rtx_st      <= RTX_CONV;
                    end if;

                -- Converte bin corrente in 5 cifre ASCII (sempre 5 digit, zero-padded)
                -- Sorgente: cattura diretta FFT (bypass SDRAM) — diagnostica
                when RTX_CONV =>
                    v := to_integer(ausp_mag_buf(rtx_val_idx));
                    rtx_digs(0) <= std_logic_vector(to_unsigned(v / 10000        + 48, 8));
                    rtx_digs(1) <= std_logic_vector(to_unsigned(v / 1000  mod 10 + 48, 8));
                    rtx_digs(2) <= std_logic_vector(to_unsigned(v / 100   mod 10 + 48, 8));
                    rtx_digs(3) <= std_logic_vector(to_unsigned(v / 10    mod 10 + 48, 8));
                    rtx_digs(4) <= std_logic_vector(to_unsigned(v         mod 10 + 48, 8));
                    rtx_dig_idx <= 0;
                    rtx_st      <= RTX_NEXT_DIGIT;

                -- Seleziona prossima cifra da mandare, poi separatore o CRLF
                when RTX_NEXT_DIGIT =>
                    rtx_baud <= 0;
                    rtx_bitc <= 0;
                    if rtx_dig_idx <= 4 then
                        rtx_sreg    <= rtx_digs(rtx_dig_idx);
                        rtx_dig_idx <= rtx_dig_idx + 1;
                        rtx_next_st <= RTX_NEXT_DIGIT;
                        rtx_st      <= RTX_BYTE_START;
                    elsif rtx_val_idx < 7 then
                        rtx_sreg    <= x"2C";          -- ','
                        rtx_next_st <= RTX_AFTER_SEP;
                        rtx_st      <= RTX_BYTE_START;
                    else
                        rtx_sreg    <= x"0D";          -- CR
                        rtx_next_st <= RTX_AFTER_CR;
                        rtx_st      <= RTX_BYTE_START;
                    end if;

                when RTX_AFTER_SEP =>
                    rtx_val_idx <= rtx_val_idx + 1;
                    rtx_st      <= RTX_CONV;

                when RTX_AFTER_CR =>
                    rtx_sreg    <= x"0A";              -- LF
                    rtx_next_st <= RTX_IDLE;
                    rtx_baud    <= 0;
                    rtx_bitc    <= 0;
                    rtx_st      <= RTX_BYTE_START;

                -- Bit di START: '0' per 234 cicli
                when RTX_BYTE_START =>
                    rtx_pin <= '0';
                    if rtx_baud = 233 then
                        rtx_baud <= 0;
                        rtx_st   <= RTX_BYTE_BITS;
                    else
                        rtx_baud <= rtx_baud + 1;
                    end if;

                -- 8 bit dati LSB-first, 234 cicli ciascuno
                when RTX_BYTE_BITS =>
                    rtx_pin <= rtx_sreg(0);
                    if rtx_baud = 233 then
                        rtx_baud <= 0;
                        rtx_sreg <= '1' & rtx_sreg(7 downto 1);
                        if rtx_bitc = 7 then
                            rtx_st <= RTX_BYTE_STOP;
                        else
                            rtx_bitc <= rtx_bitc + 1;
                        end if;
                    else
                        rtx_baud <= rtx_baud + 1;
                    end if;

                -- Bit di STOP: '1' per 234 cicli
                when RTX_BYTE_STOP =>
                    rtx_pin <= '1';
                    if rtx_baud = 233 then
                        rtx_baud <= 0;
                        rtx_st   <= rtx_next_st;
                    else
                        rtx_baud <= rtx_baud + 1;
                    end if;

            end case;
        end if;
    end process;

    -- ================================================================
    -- AUSP: legge 8 bin da SDRAM dopo ogni IRQ DMA (write-then-read per spec)
    --   Scansiona: sig bins 44-47 (4200 Hz, Signal Code 8),
    --              carr bins 88-91 (8200 Hz, Master Carrier ch0)
    --   Pin 49 ON se entrambi i massimi > C_DETECT_THR
    -- ================================================================
    process(clk_i)
        variable v_u15 : unsigned(14 downto 0);
    begin
        if rising_edge(clk_i) then
            ausp_irq_prev    <= dma_irq;
            ausp_cyc         <= '0';
            ausp_stb         <= '0';
            ausp_results_rdy <= '0';

            case ausp_st is

                when ST_IDLE =>
                    if dma_irq = '1' and ausp_irq_prev = '0' then
                        ausp_dbg_s  <= '0';
                        sdram_nz_s  <= '0';
                        rd_scan_idx <= 0;
                        sig_max_u   <= (others => '0');
                        carr_max_u  <= (others => '0');
                        ausp_st     <= ST_RD_ISSUE;
                    end if;

                when ST_RD_ISSUE =>
                    -- DIAGNOSTICA: bin 0-7 (DC e bassi) per verificare FFT+SDRAM
                    ausp_adr <= std_logic_vector(
                        to_unsigned(16#10000000# + rd_scan_idx, 32));
                    ausp_cyc <= '1';
                    ausp_stb <= '1';
                    ausp_st  <= ST_RD_WAIT;

                when ST_RD_WAIT =>
                    ausp_cyc <= '1';
                    ausp_stb <= '1';
                    if ausp_ack = '1' then
                        ausp_cyc <= '0';
                        ausp_stb <= '0';
                        if ausp_rdat(15) = '0' then
                            v_u15 := unsigned(ausp_rdat(14 downto 0));
                        else
                            v_u15 := unsigned(not ausp_rdat(14 downto 0)) + 1;
                        end if;
                        -- pin 86 verde solo se magnitudine reale > 0 (esclude -1 e 0)
                        if v_u15 /= 0 then
                            sdram_nz_s <= '1';
                        end if;
                        ausp_mag_buf(rd_scan_idx) <= v_u15;
                        if rd_scan_idx < 4 then
                            if v_u15 > sig_max_u then sig_max_u <= v_u15; end if;
                        else
                            if v_u15 > carr_max_u then carr_max_u <= v_u15; end if;
                        end if;
                        if rd_scan_idx = 7 then
                            ausp_st <= ST_NOISE_CALC;
                        else
                            rd_scan_idx <= rd_scan_idx + 1;
                            ausp_st     <= ST_RD_ISSUE;
                        end if;
                    end if;

                when ST_NOISE_CALC =>
                    if sig_max_u > C_DETECT_THR and carr_max_u > C_DETECT_THR then
                        ausp_dbg_s <= '1';
                    else
                        ausp_dbg_s <= '0';
                    end if;
                    ausp_results_rdy <= '1';
                    ausp_st <= ST_IDLE;

                when others =>
                    ausp_st <= ST_IDLE;

            end case;
        end if;
    end process;

    -- ================================================================
    -- DIAGNOSTIC: pin 49 reattivo (non sticky) — mostra ogni campione ADC.
    -- A 46875 Hz l'occhio media automaticamente → luminosità ∝ segnale ADC.
    -- Soglia > 5 per escludere rumore. Con audio: pin 49 più luminoso.
    -- Senza audio / ADC silente: pin 49 spento o molto dim.
    -- ================================================================
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if s1_cyc = '1' and s1_stb = '1' and s1_ack = '1' and s1_we = '0' then
                if unsigned(s1_rdata(11 downto 0)) > 2000 then
                    adc_nonzero <= '1';
                else
                    adc_nonzero <= '0';
                end if;
            end if;
        end if;
    end process;

    -- ================================================================
    -- TEST DIRETTO SDRAM: scrive 0xDEADBEEF ad addr 0, rilegge ogni 0.3s.
    -- Campiona O_sdrc_data a 4 istanti: timer=8,10,12,14 cicli da cmd READ.
    -- Output: "A:TTTTTTTT TTTTTTTT TTTTTTTT TTTTTTTT\r\n"
    --   A/N = cmd_ack WRITE visto (A) o no (N)
    --   4 valori hex = snapshot @T8 @T10 @T12 @T14
    -- Atteso: almeno uno ≠ 00000000 → write funziona, si vede la finestra valida
    --         tutti 00000000 → write non funziona
    -- ================================================================

    -- clk_sdram heartbeat counter
    process(clk_sdram)
    begin
        if rising_edge(clk_sdram) then
            clk_sdram_cnt <= clk_sdram_cnt + 1;
        end if;
    end process;

    -- Baud tick @ 108 MHz / 937 = 115261 baud ≈ 115200
    process(clk_sdram)
    begin
        if rising_edge(clk_sdram) then
            tst_baud_tick <= '0';
            if tst_baud_cnt = 936 then
                tst_baud_cnt  <= (others => '0');
                tst_baud_tick <= '1';
            else
                tst_baud_cnt <= tst_baud_cnt + 1;
            end if;
        end if;
    end process;

    -- UART shift register @ 54 MHz
    process(clk_sdram)
    begin
        if rising_edge(clk_sdram) then
            if tst_baud_tick = '1' and tst_tx_busy = '1' then
                tst_tx_sr  <= '1' & tst_tx_sr(9 downto 1);
                tst_tx_cnt <= tst_tx_cnt + 1;
                if tst_tx_cnt = 9 then
                    tst_tx_busy <= '0';
                    tst_tx_cnt  <= (others => '0');
                end if;
            end if;
            if tst_tx_load = '1' and tst_tx_busy = '0' then
                tst_tx_sr   <= '1' & tst_tx_byte & '0';  -- {stop, data[7:0], start}
                tst_tx_busy <= '1';
                tst_tx_cnt  <= (others => '0');
            end if;
        end if;
    end process;

    -- FSM test SDRAM @ 54 MHz (stesso dominio del controller: nessun CDC)
    process(clk_sdram)
        variable nibble : unsigned(3 downto 0);

        procedure send_nibble(n : unsigned(3 downto 0)) is
        begin
            if n < 10 then
                tst_tx_byte <= std_logic_vector(to_unsigned(48 + to_integer(n), 8));
            else
                tst_tx_byte <= std_logic_vector(to_unsigned(55 + to_integer(n), 8));
            end if;
        end procedure;
    begin
        if rising_edge(clk_sdram) then
            tst_cmd_en  <= '0';
            tst_cmd     <= "111";  -- NOP default
            tst_tx_load <= '0';

            case tst_st is

                when TS_INIT =>
                    tst_timer <= tst_timer + 1;
                    -- Procede se init completa O dopo ~0.31s @ 27 MHz (bit 23 = 2^23/27M = 0.31s)
                    if tst_init_done = '1' or tst_timer(23) = '1' then
                        tst_timer <= (others => '0');
                        tst_st    <= TS_WRITE;
                    end if;

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

                when TS_WR_WAIT =>
                    tst_timer <= tst_timer + 1;
                    if tst_timer = 200 then
                        tst_timer <= (others => '0');
                        tst_st <= TS_READ;
                    end if;

                when TS_READ =>
                    tst_cmd_en <= '1';
                    tst_cmd    <= "101";
                    tst_addr   <= (others => '0');
                    if tst_cmd_ack_s = '1' then
                        tst_timer <= (others => '0');
                        tst_st    <= TS_RD_WAIT;
                    end if;

                when TS_RD_WAIT =>
                    tst_timer <= tst_timer + 1;
                    -- Campiona a 4 istanti anticipati: finestra valida attesa @CL=3+tRCD=3 ≈ t=3..9
                    if tst_timer = 3 then
                        tst_rd_latch_8  <= tst_rd_data;
                    elsif tst_timer = 5 then
                        tst_rd_latch_10 <= tst_rd_data;
                    elsif tst_timer = 7 then
                        tst_rd_latch_12 <= tst_rd_data;
                    elsif tst_timer = 9 then
                        tst_rd_latch_14 <= tst_rd_data;
                        tst_tx_seq      <= 0;
                        tst_st          <= TS_TX;
                    end if;

                when TS_TX =>
                    -- Output: 'A'/'N' + ':' + T8(hex8) + ' ' + T10(hex8) + ' ' + T12(hex8) + ' ' + T14(hex8) + CR + LF
                    if tst_tx_busy = '0' and tst_tx_load = '0' and (tst_tx_seq > 0 or tst_baud_tick = '1') then
                        tst_tx_load <= '1';
                        tst_tx_seq  <= tst_tx_seq + 1;
                        case tst_tx_seq is
                            when 0  =>
                                if tst_wr_ack_latched = '1' then
                                    tst_tx_byte <= x"41";  -- 'A'
                                else
                                    tst_tx_byte <= x"4E";  -- 'N'
                                end if;
                            when 1  => tst_tx_byte <= x"3A";  -- ':'
                            -- latch @timer=8
                            when 2  => send_nibble(unsigned(tst_rd_latch_8(31 downto 28)));
                            when 3  => send_nibble(unsigned(tst_rd_latch_8(27 downto 24)));
                            when 4  => send_nibble(unsigned(tst_rd_latch_8(23 downto 20)));
                            when 5  => send_nibble(unsigned(tst_rd_latch_8(19 downto 16)));
                            when 6  => send_nibble(unsigned(tst_rd_latch_8(15 downto 12)));
                            when 7  => send_nibble(unsigned(tst_rd_latch_8(11 downto 8)));
                            when 8  => send_nibble(unsigned(tst_rd_latch_8(7 downto 4)));
                            when 9  => send_nibble(unsigned(tst_rd_latch_8(3 downto 0)));
                            when 10 => tst_tx_byte <= x"20";  -- ' '
                            -- latch @timer=10
                            when 11 => send_nibble(unsigned(tst_rd_latch_10(31 downto 28)));
                            when 12 => send_nibble(unsigned(tst_rd_latch_10(27 downto 24)));
                            when 13 => send_nibble(unsigned(tst_rd_latch_10(23 downto 20)));
                            when 14 => send_nibble(unsigned(tst_rd_latch_10(19 downto 16)));
                            when 15 => send_nibble(unsigned(tst_rd_latch_10(15 downto 12)));
                            when 16 => send_nibble(unsigned(tst_rd_latch_10(11 downto 8)));
                            when 17 => send_nibble(unsigned(tst_rd_latch_10(7 downto 4)));
                            when 18 => send_nibble(unsigned(tst_rd_latch_10(3 downto 0)));
                            when 19 => tst_tx_byte <= x"20";  -- ' '
                            -- latch @timer=12
                            when 20 => send_nibble(unsigned(tst_rd_latch_12(31 downto 28)));
                            when 21 => send_nibble(unsigned(tst_rd_latch_12(27 downto 24)));
                            when 22 => send_nibble(unsigned(tst_rd_latch_12(23 downto 20)));
                            when 23 => send_nibble(unsigned(tst_rd_latch_12(19 downto 16)));
                            when 24 => send_nibble(unsigned(tst_rd_latch_12(15 downto 12)));
                            when 25 => send_nibble(unsigned(tst_rd_latch_12(11 downto 8)));
                            when 26 => send_nibble(unsigned(tst_rd_latch_12(7 downto 4)));
                            when 27 => send_nibble(unsigned(tst_rd_latch_12(3 downto 0)));
                            when 28 => tst_tx_byte <= x"20";  -- ' '
                            -- latch @timer=14
                            when 29 => send_nibble(unsigned(tst_rd_latch_14(31 downto 28)));
                            when 30 => send_nibble(unsigned(tst_rd_latch_14(27 downto 24)));
                            when 31 => send_nibble(unsigned(tst_rd_latch_14(23 downto 20)));
                            when 32 => send_nibble(unsigned(tst_rd_latch_14(19 downto 16)));
                            when 33 => send_nibble(unsigned(tst_rd_latch_14(15 downto 12)));
                            when 34 => send_nibble(unsigned(tst_rd_latch_14(11 downto 8)));
                            when 35 => send_nibble(unsigned(tst_rd_latch_14(7 downto 4)));
                            when 36 => send_nibble(unsigned(tst_rd_latch_14(3 downto 0)));
                            when 37 => tst_tx_byte <= x"0D";  -- CR
                            when 38 => tst_tx_byte <= x"0A";  -- LF
                            when others =>
                                tst_tx_load <= '0';
                                tst_timer   <= (others => '0');
                                tst_st      <= TS_PAUSE;
                        end case;
                    end if;

                when TS_PAUSE =>
                    tst_timer <= tst_timer + 1;
                    if tst_timer(25) = '1' then
                        tst_timer <= (others => '0');
                        tst_st <= TS_WRITE;
                    end if;

            end case;
        end if;
    end process;

end behavioral;
