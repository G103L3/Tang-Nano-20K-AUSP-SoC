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
        disp_sck_o   : out std_logic;
        disp_sda_o   : out std_logic;
        disp_dc_o    : out std_logic;
        disp_rst_o   : out std_logic;
        disp_cs_o    : out std_logic;
        uart_ext_tx  : out std_logic;
        uart_ext_rx  : in  std_logic;
        flash_sck_o  : out std_logic;
        flash_cs_o   : out std_logic;
        flash_mosi_o : out std_logic;
        flash_miso_i : in  std_logic;
        flash_tx_o   : out std_logic;
        flash_rx_i   : in  std_logic;
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

architecture behavioral of top_system is

    component Gowin_rPLL
        port (
            clkout  : out std_logic;
            clkoutp : out std_logic;
            lock    : out std_logic;
            clkin   : in  std_logic
        );
    end component;

    component wb_interconnect
        port (
            clk_i    : in std_logic;
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
            s7_we_o  : out std_logic; s7_sel_o : out std_logic_vector(3 downto 0); s7_stb_o : out std_logic; s7_cyc_o : out std_logic; s7_ack_i : in std_logic;
            s8_adr_o : out std_logic_vector(31 downto 0); s8_dat_o : out std_logic_vector(31 downto 0); s8_dat_i : in std_logic_vector(31 downto 0);
            s8_we_o  : out std_logic; s8_sel_o : out std_logic_vector(3 downto 0); s8_stb_o : out std_logic; s8_cyc_o : out std_logic; s8_ack_i : in std_logic;
            s9_adr_o : out std_logic_vector(31 downto 0); s9_dat_o : out std_logic_vector(31 downto 0); s9_dat_i : in std_logic_vector(31 downto 0);
            s9_we_o  : out std_logic; s9_sel_o : out std_logic_vector(3 downto 0); s9_stb_o : out std_logic; s9_cyc_o : out std_logic; s9_ack_i : in std_logic
        );
    end component;

    component spi_display
        generic ( PRESCALER : natural := 6 );
        port (
            clk_i : in  std_logic;
            rst_i : in  std_logic;
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            we_i  : in  std_logic;
            adr_i : in  std_logic_vector(7 downto 0);
            dat_i : in  std_logic_vector(31 downto 0);
            dat_o : out std_logic_vector(31 downto 0);
            ack_o : out std_logic;
            SCK_o : out std_logic;
            SDA_o : out std_logic;
            DC_o  : out std_logic;
            RST_o : out std_logic;
            CS_o  : out std_logic
        );
    end component;

    component sdram_controller_fsm
        port (
            O_sdram_clk      : out   std_logic;
            O_sdram_cke      : out   std_logic;
            O_sdram_cs_n     : out   std_logic;
            O_sdram_cas_n    : out   std_logic;
            O_sdram_ras_n    : out   std_logic;
            O_sdram_wen_n    : out   std_logic;
            O_sdram_dqm      : out   std_logic_vector(3 downto 0);
            O_sdram_addr     : out   std_logic_vector(10 downto 0);
            O_sdram_ba       : out   std_logic_vector(1 downto 0);
            IO_sdram_dq      : inout std_logic_vector(31 downto 0);
            I_sdrc_rst_n     : in    std_logic;
            I_sdrc_clk       : in    std_logic;
            I_sdram_clk      : in    std_logic;
            I_sdrc_selfrefresh : in  std_logic;
            I_sdrc_power_down  : in  std_logic;
            I_sdrc_wr_n      : in    std_logic;
            I_sdrc_rd_n      : in    std_logic;
            I_sdrc_addr      : in    std_logic_vector(20 downto 0);
            I_sdrc_data_len  : in    std_logic_vector(7 downto 0);
            I_sdrc_dqm       : in    std_logic_vector(3 downto 0);
            I_sdrc_data      : in    std_logic_vector(31 downto 0);
            O_sdrc_data      : out   std_logic_vector(31 downto 0);
            O_sdrc_init_done : out   std_logic;
            O_sdrc_busy_n    : out   std_logic;
            O_sdrc_rd_valid  : out   std_logic;
            O_sdrc_wrd_ack   : out   std_logic
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
        generic (
            CLK_HZ        : integer := 27_000_000;
            NBIT          : integer := 8;
            PHASE_NBITS   : integer := 24;
            K_RECIP_G     : integer := 10_424_999;
            F1_DEFAULT_HZ : integer := 0;
            F2_DEFAULT_HZ : integer := 0;
            AUTO_START    : boolean := false
        );
        port (
            clk_i : in  std_logic;
            rst_i : in  std_logic;
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            we_i  : in  std_logic;
            adr_i : in  std_logic_vector(7 downto 0);
            dat_i : in  std_logic_vector(31 downto 0);
            dat_o : out std_logic_vector(31 downto 0);
            ack_o : out std_logic;
            pwm_o : out std_logic
        );
    end component;

    component spi_master_generic
        generic (
            PRESCALER  : natural := 16;
            FRAME_BITS : natural := 8
        );
        port (
            clk_i : in  std_logic;
            rst_i : in  std_logic;
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            we_i  : in  std_logic;
            adr_i : in  std_logic_vector(7 downto 0);
            dat_i : in  std_logic_vector(31 downto 0);
            dat_o : out std_logic_vector(31 downto 0);
            ack_o : out std_logic;
            MOSI  : out std_logic;
            MISO  : in  std_logic;
            SCK   : out std_logic;
            CS    : out std_logic
        );
    end component;

    component Gowin_PicoRV32_Top
        port (
            ser_tx          : out std_logic;
            ser_rx          : in  std_logic;
            slv_ext_stb_o   : out std_logic;
            slv_ext_we_o    : out std_logic;
            slv_ext_cyc_o   : out std_logic;
            slv_ext_ack_i   : in  std_logic;
            slv_ext_adr_o   : out std_logic_vector(31 downto 0);
            slv_ext_wdata_o : out std_logic_vector(31 downto 0);
            slv_ext_rdata_i : in  std_logic_vector(31 downto 0);
            slv_ext_sel_o   : out std_logic_vector(3 downto 0);
            irq_in          : in  std_logic_vector(31 downto 20);
            jtag_TDI        : in  std_logic;
            jtag_TDO        : out std_logic;
            jtag_TCK        : in  std_logic;
            jtag_TMS        : in  std_logic;
            clk_in          : in  std_logic;
            resetn_in       : in  std_logic
        );
    end component;

    component UART_GENERIC
        port (
            clk_i : in  std_logic;
            rst_i : in  std_logic;
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            we_i  : in  std_logic;
            adr_i : in  std_logic_vector(7 downto 0);
            dat_i : in  std_logic_vector(31 downto 0);
            dat_o : out std_logic_vector(31 downto 0);
            ack_o : out std_logic;
            TX_o  : out std_logic;
            RX_i  : in  std_logic
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
            sdr_own_o      : out std_logic;
            sdr_wr_n_o     : out std_logic;
            sdr_addr_o     : out std_logic_vector(20 downto 0);
            sdr_data_o     : out std_logic_vector(31 downto 0);
            sdr_busy_n_i   : in  std_logic;
            sdr_initdone_i : in  std_logic;
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

    -- cpu external bus, master m0 of the interconnect
    signal core_slv_stb  : std_logic;
    signal core_slv_we   : std_logic;
    signal core_slv_cyc  : std_logic;
    signal core_slv_ack  : std_logic;
    signal core_slv_adr  : std_logic_vector(31 downto 0);
    signal core_slv_wdat : std_logic_vector(31 downto 0);
    signal core_slv_rdat : std_logic_vector(31 downto 0);
    signal core_slv_sel  : std_logic_vector(3 downto 0);
    signal core_uart_tx  : std_logic;

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

    signal s7_adr, s7_wdata, s7_rdata : std_logic_vector(31 downto 0);
    signal s7_stb, s7_we, s7_cyc, s7_ack : std_logic;
    signal s7_sel : std_logic_vector(3 downto 0);

    signal s8_adr, s8_wdata, s8_rdata : std_logic_vector(31 downto 0);
    signal s8_stb, s8_we, s8_cyc, s8_ack : std_logic;
    signal s8_sel : std_logic_vector(3 downto 0);

    signal s9_adr, s9_wdata, s9_rdata : std_logic_vector(31 downto 0);
    signal s9_stb, s9_we, s9_cyc, s9_ack : std_logic;
    signal s9_sel : std_logic_vector(3 downto 0);

    -- irq bit 20 is the frame done pulse from the audio accelerator
    signal core_irq : std_logic_vector(31 downto 20) := (others => '0');

    -- accelerator master bus and its split between peripherals and sdram
    signal dma_m_adr, dma_m_wdat : std_logic_vector(31 downto 0);
    signal dma_m_we, dma_m_stb, dma_m_cyc : std_logic;
    signal dma_m_rdat  : std_logic_vector(31 downto 0);
    signal dma_m_ack_s : std_logic;
    signal dma_to_sdram : std_logic;
    signal dma_wb_rdat, dma_rdata : std_logic_vector(31 downto 0);
    signal dma_wb_ack, dma_ack : std_logic;
    signal dma_stb_wb : std_logic;
    signal dma_cyc_wb : std_logic;
    signal dma_irq    : std_logic;

    -- direct write port from the accelerator to the sdram controller
    signal dma_sdr_own  : std_logic;
    signal dma_sdr_wr_n : std_logic;
    signal dma_sdr_addr : std_logic_vector(20 downto 0);
    signal dma_sdr_data : std_logic_vector(31 downto 0);
    signal sip_wr_n : std_logic;
    signal sip_rd_n : std_logic;
    signal sip_addr : std_logic_vector(20 downto 0);
    signal sip_data : std_logic_vector(31 downto 0);
    signal dma_fft_trig : std_logic;

    -- fetch fsm, the read side of the sdram port
    type fetch_state_t is (F_IDLE, F_REQ, F_READ, F_DONE);
    signal fetch_curr_state, fetch_next_state : fetch_state_t := F_IDLE;
    signal fetch_rd_n      : std_logic := '1';
    signal fetch_busy_n    : std_logic;
    signal fetch_rd_valid  : std_logic;
    signal fetch_addr      : std_logic_vector(20 downto 0) := (others => '0');
    signal fetch_rd_data   : std_logic_vector(31 downto 0);
    signal fetch_init_done : std_logic;
    signal fetch_timeout   : integer range 0 to 2047 := 0;
    signal fetch_idx       : integer range 0 to 63 := 0;
    signal fetch_burst     : integer range 0 to 19 := 0;
    constant FETCH_NBURST  : integer := 20;
    type fetch_words_t is array(0 to 25) of std_logic_vector(31 downto 0);
    signal fetch_words : fetch_words_t := (others => (others => '0'));

    signal spi_data_ready_s : std_logic;
    signal gpio_in_v, gpio_out_v : std_logic_vector(0 downto 0);
    signal pwm10_s, pwm4_s : std_logic;
    signal pwm_rst_s : std_logic;

    signal clk_sdram   : std_logic;
    signal clk_sdram_p : std_logic;
    signal pll_lock    : std_logic;

    signal dma_irq_prev2 : std_logic := '0';

    -- stable spectrum snapshot for the cpu, filled bin by bin by the fetch fsm
    type fft_bsram_t is array (0 to 511) of std_logic_vector(15 downto 0);
    signal fft_bsram      : fft_bsram_t;
    signal bsram_rdata    : std_logic_vector(15 downto 0) := (others => '0');
    signal bsram_addr_cpu : std_logic_vector(8 downto 0) := (others => '0');
    signal s0_bsram_cnt   : integer range 0 to 2 := 0;
    signal fill_cnt       : unsigned(15 downto 0) := (others => '0');

    constant FRAME_DIV    : integer := 1;
    signal frame_cnt      : integer range 0 to FRAME_DIV - 1 := 0;
    signal decode_frame_s : std_logic := '0';
    signal frame_ready_s  : std_logic := '0';

    -- event counters that tell where the audio chain stops
    signal acc_rdy_cnt  : unsigned(31 downto 0) := (others => '0');
    signal acc_trig_cnt : unsigned(31 downto 0) := (others => '0');
    signal acc_irq_cnt  : unsigned(31 downto 0) := (others => '0');
    signal acc_rdy_prev, acc_trig_prev, acc_irq_prev : std_logic := '0';

begin

    u_pll: Gowin_rPLL
    port map (
        clkin   => clk_i,
        clkout  => clk_sdram,
        clkoutp => clk_sdram_p,
        lock    => pll_lock
    );

    ser_tx    <= '1';
    -- pin 80 gates the 3v3 rail of every peripheral, it must stay high
    gpio_1_o  <= '1';
    gpio_in_v <= (others => '0');

    -- accelerator bus split: peripheral traffic goes to the interconnect,
    -- the sdram range would go to the direct port (not used in practice)
    dma_to_sdram <= '1' when dma_m_adr(31 downto 28) = "0001" else '0';
    dma_stb_wb   <= dma_m_stb and not dma_to_sdram;
    dma_cyc_wb   <= dma_m_cyc and not dma_to_sdram;
    dma_m_ack_s  <= dma_ack   when dma_to_sdram = '1' else dma_wb_ack;
    dma_m_rdat   <= dma_rdata when dma_to_sdram = '1' else dma_wb_rdat;
    dma_ack      <= '0';
    dma_rdata    <= (others => '0');

    u_bus: wb_interconnect
    port map (
        clk_i    => clk_sdram,
        m0_adr_i => core_slv_adr, m0_dat_i => core_slv_wdat, m0_dat_o => core_slv_rdat,
        m0_we_i  => core_slv_we,  m0_sel_i => core_slv_sel,  m0_stb_i => core_slv_stb,
        m0_cyc_i => core_slv_cyc, m0_ack_o => core_slv_ack,
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
        s7_adr_o => s7_adr, s7_dat_o => s7_wdata, s7_dat_i => s7_rdata,
        s7_we_o  => s7_we,  s7_sel_o => s7_sel,   s7_stb_o => s7_stb,  s7_cyc_o => s7_cyc, s7_ack_i => s7_ack,
        s8_adr_o => s8_adr, s8_dat_o => s8_wdata, s8_dat_i => s8_rdata,
        s8_we_o  => s8_we,  s8_sel_o => s8_sel,   s8_stb_o => s8_stb,  s8_cyc_o => s8_cyc, s8_ack_i => s8_ack,
        s9_adr_o => s9_adr, s9_dat_o => s9_wdata, s9_dat_i => s9_rdata,
        s9_we_o  => s9_we,  s9_sel_o => s9_sel,   s9_stb_o => s9_stb,  s9_cyc_o => s9_cyc, s9_ack_i => s9_ack
    );

    -- tft panel on five spare pins, slave s9
    u_disp: spi_display
        generic map ( PRESCALER => 6 )
        port map (
            clk_i => clk_sdram,
            rst_i => pll_lock,
            cyc_i => s9_cyc,
            stb_i => s9_stb,
            we_i  => s9_we,
            adr_i => s9_adr(7 downto 0),
            dat_i => s9_wdata,
            dat_o => s9_rdata,
            ack_o => s9_ack,
            SCK_o => disp_sck_o,
            SDA_o => disp_sda_o,
            DC_o  => disp_dc_o,
            RST_o => disp_rst_o,
            CS_o  => disp_cs_o
        );

    -- slave s0: fetch fsm status, chain counters and the bsram snapshot;
    -- snapshot reads are registered, the ack comes two cycles after the strobe
    s0_proc: process(clk_sdram)
        variable st_v : std_logic_vector(31 downto 0);
    begin
        if rising_edge(clk_sdram) then
            s0_ack <= '0';
            if s0_bsram_cnt = 1 then
                s0_bsram_cnt <= 2;
            elsif s0_bsram_cnt = 2 then
                s0_rdata     <= x"0000" & bsram_rdata;
                s0_ack       <= '1';
                s0_bsram_cnt <= 0;
            elsif s0_cyc = '1' and s0_stb = '1' and s0_ack = '0' then
                if s0_we = '0' and s0_adr(12) = '1' then
                    bsram_addr_cpu <= s0_adr(10 downto 2);
                    s0_bsram_cnt   <= 1;
                else
                    s0_ack <= '1';
                    if s0_we = '0' then
                        case to_integer(unsigned(s0_adr(7 downto 2))) is
                            when 0 to 25 =>
                                s0_rdata <= fetch_words(to_integer(unsigned(s0_adr(7 downto 2))));
                            when 33 =>
                                s0_rdata <= std_logic_vector(acc_rdy_cnt);
                            when 34 =>
                                s0_rdata <= std_logic_vector(acc_trig_cnt);
                            when 35 =>
                                s0_rdata <= std_logic_vector(acc_irq_cnt);
                            when 36 =>
                                s0_rdata <= x"0000" & std_logic_vector(fill_cnt);
                            when others =>
                                st_v := (others => '0');
                                st_v(31) := frame_ready_s;
                                if fetch_curr_state = F_READ then st_v(16) := '1'; end if;
                                st_v(12 downto 8) := std_logic_vector(to_unsigned(fetch_burst, 5));
                                st_v(5 downto 0)  := std_logic_vector(to_unsigned(fetch_idx, 6));
                                s0_rdata <= st_v;
                        end case;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- snapshot write side: each valid word lands at bin = burst * 26 + idx,
    -- so the frame stays still for the cpu until the next fetch
    bsram_proc: process(clk_sdram)
        variable widx : integer;
    begin
        if rising_edge(clk_sdram) then
            if fetch_rd_valid = '1' and fetch_idx < 26 then
                widx := fetch_burst * 26 + fetch_idx;
                if widx < 512 then
                    fft_bsram(widx) <= fetch_rd_data(15 downto 0);
                end if;
            end if;
            bsram_rdata <= fft_bsram(to_integer(unsigned(bsram_addr_cpu)));
        end if;
    end process;

    -- the cpu polls this counter instead of a clear on read flag
    fillcnt_proc: process(clk_sdram)
    begin
        if rising_edge(clk_sdram) then
            if frame_ready_s = '1' then fill_cnt <= fill_cnt + 1; end if;
        end if;
    end process;

    acc_dbg_proc: process(clk_sdram)
    begin
        if rising_edge(clk_sdram) then
            if spi_data_ready_s = '1' and acc_rdy_prev = '0'  then acc_rdy_cnt  <= acc_rdy_cnt  + 1; end if;
            if dma_fft_trig     = '1' and acc_trig_prev = '0' then acc_trig_cnt <= acc_trig_cnt + 1; end if;
            if dma_irq          = '1' and acc_irq_prev = '0'  then acc_irq_cnt  <= acc_irq_cnt  + 1; end if;
            acc_rdy_prev  <= spi_data_ready_s;
            acc_trig_prev <= dma_fft_trig;
            acc_irq_prev  <= dma_irq;
        end if;
    end process;

    -- single command port of the sdram controller: the accelerator owns it
    -- while it drains a frame, the fetch fsm owns it the rest of the time
    sip_wr_n <= dma_sdr_wr_n when dma_sdr_own = '1' else '1';
    sip_rd_n <= fetch_rd_n   when dma_sdr_own = '0' else '1';
    sip_addr <= dma_sdr_addr when dma_sdr_own = '1' else fetch_addr;
    sip_data <= dma_sdr_data when dma_sdr_own = '1' else (others => '0');

    -- data_len 26 gives bursts of 27 words, the capture keeps the first 26
    u_sdram_direct: sdram_controller_fsm
    port map (
        O_sdram_clk      => O_sdram_clk,    O_sdram_cke      => O_sdram_cke,
        O_sdram_cs_n     => O_sdram_cs_n,   O_sdram_cas_n    => O_sdram_cas_n,
        O_sdram_ras_n    => O_sdram_ras_n,  O_sdram_wen_n    => O_sdram_wen_n,
        O_sdram_dqm      => O_sdram_dqm,    O_sdram_addr     => O_sdram_addr,
        O_sdram_ba       => O_sdram_ba,     IO_sdram_dq      => IO_sdram_dq,
        I_sdrc_rst_n     => pll_lock,       I_sdrc_clk       => clk_sdram,
        I_sdram_clk      => clk_sdram_p,
        I_sdrc_selfrefresh => '0',          I_sdrc_power_down  => '0',
        I_sdrc_wr_n      => sip_wr_n,       I_sdrc_rd_n      => sip_rd_n,
        I_sdrc_addr      => sip_addr,       I_sdrc_dqm       => "0000",
        I_sdrc_data      => sip_data,
        I_sdrc_data_len  => x"1A",
        O_sdrc_data      => fetch_rd_data,  O_sdrc_init_done => fetch_init_done,
        O_sdrc_busy_n    => fetch_busy_n,   O_sdrc_rd_valid  => fetch_rd_valid,
        O_sdrc_wrd_ack   => open
    );

    u_dma: dma port map (
        clk_i => clk_sdram,  rst_i => rst_i, s_cyc_i => s5_cyc, s_stb_i => s5_stb, s_we_i  => s5_we,
        s_adr_i => s5_adr, s_dat_i => s5_wdata, s_dat_o => s5_rdata, s_ack_o => s5_ack,
        m_cyc_o => dma_m_cyc, m_stb_o => dma_m_stb, m_we_o => dma_m_we, m_adr_o => dma_m_adr,
        m_dat_o => dma_m_wdat, m_dat_i => dma_m_rdat, m_ack_i => dma_m_ack_s,
        spi_data_ready_i => spi_data_ready_s,
        sdr_own_o => dma_sdr_own, sdr_wr_n_o => dma_sdr_wr_n,
        sdr_addr_o => dma_sdr_addr, sdr_data_o => dma_sdr_data,
        sdr_busy_n_i => fetch_busy_n, sdr_initdone_i => fetch_init_done,
        irq_o => dma_irq, fft_trigger_o => dma_fft_trig,
        fft_dbg_o => open, fft_ack_dbg_o => open, fft_ser_o => open,
        fft_idx_o => open, fft_xk_re_o => open, fft_opd_o => open
    );

    u_spi: spi_master port map (
        clk_i => clk_sdram, rst_i => '1', cyc_i => s1_cyc, stb_i => s1_stb, we_i => s1_we,
        adr_i => s1_adr(7 downto 0), dat_i => s1_wdata, dat_o => s1_rdata, ack_o => s1_ack,
        data_ready_o => spi_data_ready_s, dbg_cap_o => open,
        mosi => mosi_p, miso => miso_p, sck => sck_p, cs => cs_p
    );

    -- pwm reset is high only until the pll locks
    pwm_rst_s <= not pll_lock;

    -- speaker pwm runs on the bus clock so its registers need no cdc
    u_pwm10: pwm_generic
        generic map (
            CLK_HZ        => 40_500_000,
            NBIT          => 8,
            PHASE_NBITS   => 24,
            K_RECIP_G     => 6_949_999,
            F1_DEFAULT_HZ => 0,
            F2_DEFAULT_HZ => 0,
            AUTO_START    => false
        )
        port map (
            clk_i => clk_sdram, rst_i => pwm_rst_s,
            cyc_i => s2_cyc, stb_i => s2_stb, we_i => s2_we,
            adr_i => s2_adr(7 downto 0),
            dat_i => s2_wdata, dat_o => s2_rdata, ack_o => s2_ack,
            pwm_o => pwm10_s
        );

    u_pwm4: pwm_generic
        generic map (
            CLK_HZ        => 27_000_000,
            NBIT          => 8,
            PHASE_NBITS   => 24,
            F1_DEFAULT_HZ => 0,
            F2_DEFAULT_HZ => 0,
            AUTO_START    => false
        )
        port map (
            clk_i => clk_i, rst_i => pwm_rst_s,
            cyc_i => s3_cyc, stb_i => s3_stb, we_i => s3_we,
            adr_i => s3_adr(7 downto 0),
            dat_i => s3_wdata, dat_o => s3_rdata, ack_o => s3_ack,
            pwm_o => pwm4_s
        );

    u_gpio1: gpio_generic generic map (nbit => 1) port map (
        clk_i => clk_sdram, rst_i => pll_lock, cyc_i => s4_cyc, stb_i => s4_stb, we_i => s4_we,
        adr_i => s4_adr(7 downto 0), dat_i => s4_wdata, dat_o => s4_rdata, ack_o => s4_ack,
        gpio_i => gpio_in_v, gpio_o => gpio_out_v
    );

    -- one fetch every FRAME_DIV frame irqs
    process(clk_sdram)
    begin
        if rising_edge(clk_sdram) then
            dma_irq_prev2  <= dma_irq;
            decode_frame_s <= '0';
            if dma_irq_prev2 = '0' and dma_irq = '1' then
                if frame_cnt = FRAME_DIV - 1 then
                    frame_cnt      <= 0;
                    decode_frame_s <= '1';
                else
                    frame_cnt <= frame_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- nor flash path: command uart in (s7), generic spi engine out (s8),
    -- the w25q protocol itself runs in the cpu firmware
    u_nor_uart: UART_GENERIC
        port map (
            clk_i => clk_sdram,
            rst_i => pll_lock,
            cyc_i => s7_cyc,
            stb_i => s7_stb,
            we_i  => s7_we,
            adr_i => s7_adr(7 downto 0),
            dat_i => s7_wdata,
            dat_o => s7_rdata,
            ack_o => s7_ack,
            TX_o  => flash_tx_o,
            RX_i  => flash_rx_i
        );

    -- 40.5 MHz / 64 gives the 633 kHz sck the flash wiring tolerates
    u_nor_spi: spi_master_generic
        generic map ( PRESCALER => 64, FRAME_BITS => 8 )
        port map (
            clk_i => clk_sdram,
            rst_i => pll_lock,
            cyc_i => s8_cyc,
            stb_i => s8_stb,
            we_i  => s8_we,
            adr_i => s8_adr(7 downto 0),
            dat_i => s8_wdata,
            dat_o => s8_rdata,
            ack_o => s8_ack,
            MOSI  => flash_mosi_o,
            MISO  => flash_miso_i,
            SCK   => flash_sck_o,
            CS    => flash_cs_o
        );

    core_irq <= (20 => dma_irq, others => '0');

    u_softcore: Gowin_PicoRV32_Top
        port map (
            ser_tx          => open,
            ser_rx          => '1',
            slv_ext_stb_o   => core_slv_stb,
            slv_ext_we_o    => core_slv_we,
            slv_ext_cyc_o   => core_slv_cyc,
            slv_ext_ack_i   => core_slv_ack,
            slv_ext_adr_o   => core_slv_adr,
            slv_ext_wdata_o => core_slv_wdat,
            slv_ext_rdata_i => core_slv_rdat,
            slv_ext_sel_o   => core_slv_sel,
            irq_in          => core_irq,
            jtag_TDI        => '0',
            jtag_TDO        => open,
            jtag_TCK        => '0',
            jtag_TMS        => '0',
            clk_in          => clk_sdram,
            resetn_in       => pll_lock
        );

    -- character uart to the esp32, slave s6, alone on its pin
    u_core_uart: UART_GENERIC
        port map (
            clk_i => clk_sdram,
            rst_i => pll_lock,
            cyc_i => s6_cyc,
            stb_i => s6_stb,
            we_i  => s6_we,
            adr_i => s6_adr(7 downto 0),
            dat_i => s6_wdata,
            dat_o => s6_rdata,
            ack_o => s6_ack,
            TX_o  => core_uart_tx,
            RX_i  => uart_ext_rx
        );

    pwm_10_o    <= pwm10_s;
    pwm_4_o     <= pwm4_s;
    uart_ext_tx <= core_uart_tx;

    -- fetch fsm, next state logic
    fetch_comb : process(fetch_curr_state, decode_frame_s, fetch_busy_n,
                         fetch_timeout, fetch_burst)
    begin
        fetch_next_state <= fetch_curr_state;
        case fetch_curr_state is
            when F_IDLE =>
                if decode_frame_s = '1' then fetch_next_state <= F_REQ; end if;
            when F_REQ =>
                if fetch_busy_n = '1' then fetch_next_state <= F_READ; end if;
            when F_READ =>
                if fetch_timeout = 200 then
                    if fetch_burst = FETCH_NBURST - 1 then
                        fetch_next_state <= F_DONE;
                    else
                        fetch_next_state <= F_REQ;
                    end if;
                end if;
            when F_DONE =>
                fetch_next_state <= F_IDLE;
        end case;
    end process;

    -- fetch fsm: after each frame irq it reads the 20 row bursts back from
    -- sdram inside a fixed 200 cycle window per burst, the valid words fall
    -- into the bsram snapshot, then it signals the frame and re-arms
    fetch_sync : process(clk_sdram)
    begin
        if rising_edge(clk_sdram) then
            fetch_curr_state <= fetch_next_state;
            frame_ready_s    <= '0';

            if fetch_rd_valid = '1' then
                if fetch_idx < 26 then
                    fetch_words(fetch_idx) <= fetch_rd_data;
                    fetch_idx <= fetch_idx + 1;
                end if;
            end if;

            case fetch_curr_state is

                when F_IDLE =>
                    fetch_rd_n <= '1';
                    if decode_frame_s = '1' then
                        fetch_idx     <= 0;
                        fetch_timeout <= 0;
                        fetch_burst   <= 0;
                    end if;

                when F_REQ =>
                    fetch_rd_n <= '1';
                    if fetch_busy_n = '1' then
                        fetch_rd_n    <= '0';
                        -- the accelerator wrote burst k on row 2 + k of bank 2
                        fetch_addr    <= "10"
                                       & std_logic_vector(to_unsigned(2 + fetch_burst, 11))
                                       & "00000101";
                        fetch_idx     <= 0;
                        fetch_timeout <= 0;
                    end if;

                when F_READ =>
                    fetch_rd_n    <= '1';
                    fetch_timeout <= fetch_timeout + 1;
                    if fetch_timeout = 200 then
                        fetch_timeout <= 0;
                        if fetch_burst = FETCH_NBURST - 1 then
                            frame_ready_s <= '1';
                        else
                            fetch_burst <= fetch_burst + 1;
                        end if;
                    end if;

                when F_DONE =>
                    fetch_rd_n <= '1';

            end case;
        end if;
    end process;

end behavioral;
