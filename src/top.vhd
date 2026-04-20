library ieee;
use ieee.std_logic_1164.all;

entity top_system is
    port (
        clk_i    : in  std_logic;
        rst_i    : in  std_logic;
        ser_tx   : out std_logic;
        ser_rx   : in  std_logic;
        mosi_p   : out std_logic;
        miso_p   : in  std_logic;
        sck_p    : out std_logic;
        cs_p     : out std_logic;
        pwm_10_o : out std_logic;
        pwm_4_o  : out std_logic;
        gpio_1_o : out std_logic;
        jtag_tdi : in  std_logic;
        jtag_tdo : out std_logic;
        jtag_tck : in  std_logic;
        jtag_tms : in  std_logic
    );
end top_system;

architecture behavioral of top_system is

    component gowin_picorv32_top
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
            jtag_tdi        : in  std_logic;
            jtag_tdo        : out std_logic;
            jtag_tck        : in  std_logic;
            jtag_tms        : in  std_logic;
            clk_in          : in  std_logic;
            resetn_in       : in  std_logic
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

    component memory_arbiter
        port (
            wb_clk_i  : in  std_logic;
            wb_rst_i  : in  std_logic;
            -- M0: CPU (low priority)
            m0_cyc_i  : in  std_logic;
            m0_stb_i  : in  std_logic;
            m0_we_i   : in  std_logic;
            m0_adr_i  : in  std_logic_vector(31 downto 0);
            m0_dat_i  : in  std_logic_vector(31 downto 0);
            m0_dat_o  : out std_logic_vector(31 downto 0);
            m0_ack_o  : out std_logic;
            -- M1: DMA (high priority)
            m1_cyc_i  : in  std_logic;
            m1_stb_i  : in  std_logic;
            m1_we_i   : in  std_logic;
            m1_adr_i  : in  std_logic_vector(31 downto 0);
            m1_dat_i  : in  std_logic_vector(31 downto 0);
            m1_dat_o  : out std_logic_vector(31 downto 0);
            m1_ack_o  : out std_logic
        );
    end component;

    component spi_master
        port (
            clk_i : in std_logic; rst_i : in std_logic; cyc_i : in std_logic; stb_i : in std_logic;
            we_i  : in std_logic; adr_i : in std_logic_vector(7 downto 0); dat_i : in std_logic_vector(31 downto 0);
            dat_o : out std_logic_vector(31 downto 0); ack_o : out std_logic; mosi : out std_logic;
            miso  : in std_logic; sck : out std_logic; cs : out std_logic
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

    -- CPU <-> bus
    signal cpu_adr, cpu_wdata, cpu_rdata : std_logic_vector(31 downto 0);
    signal cpu_stb, cpu_we, cpu_cyc, cpu_ack : std_logic;
    signal cpu_sel : std_logic_vector(3 downto 0);

    -- Slave wires
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

    -- WB bus M1 placeholder (future DMA for peripherals)
    signal dummy_m1_adr, dummy_m1_dat_i : std_logic_vector(31 downto 0) := (others => '0');
    signal dummy_m1_stb, dummy_m1_we, dummy_m1_cyc : std_logic := '0';
    signal dummy_m1_sel : std_logic_vector(3 downto 0) := (others => '0');

    -- DMA WB interface to memory_arbiter M1 (placeholder until DMA is added)
    signal dma_cyc, dma_stb, dma_we : std_logic := '0';
    signal dma_adr, dma_wdata       : std_logic_vector(31 downto 0) := (others => '0');
    signal dma_rdata                : std_logic_vector(31 downto 0);
    signal dma_ack                  : std_logic;

    -- Dummy slave (S5..S7 non collegati)
    signal dummy_s_dat_i : std_logic_vector(31 downto 0) := (others => '0');
    signal dummy_s_ack_i : std_logic := '0';

    -- GPIO
    signal gpio_in_v, gpio_out_v : std_logic_vector(0 downto 0);

    -- IRQ non utilizzati
    signal irq_dummy : std_logic_vector(31 downto 20) := (others => '0');



begin

    gpio_in_v <= (others => '0');
    gpio_1_o  <= gpio_out_v(0);

    u_cpu: gowin_picorv32_top
    port map (
        ser_tx          => ser_tx,
        ser_rx          => ser_rx,
        slv_ext_stb_o   => cpu_stb,
        slv_ext_we_o    => cpu_we,
        slv_ext_cyc_o   => cpu_cyc,
        slv_ext_ack_i   => cpu_ack,
        slv_ext_adr_o   => cpu_adr,
        slv_ext_wdata_o => cpu_wdata,
        slv_ext_rdata_i => cpu_rdata,
        slv_ext_sel_o   => cpu_sel,
        irq_in          => irq_dummy,
        jtag_tdi        => jtag_tdi,
        jtag_tdo        => jtag_tdo,
        jtag_tck        => jtag_tck,
        jtag_tms        => jtag_tms,
        clk_in          => clk_i,
        resetn_in       => rst_i
    );

    u_bus: wb_interconnect
    port map (
        m0_adr_i => cpu_adr,       m0_dat_i => cpu_wdata,       m0_dat_o => cpu_rdata,
        m0_we_i  => cpu_we,        m0_sel_i => cpu_sel,         m0_stb_i => cpu_stb,
        m0_cyc_i => cpu_cyc,       m0_ack_o => cpu_ack,
        m1_adr_i => dummy_m1_adr,  m1_dat_i => dummy_m1_dat_i,  m1_dat_o => open,
        m1_we_i  => dummy_m1_we,   m1_sel_i => dummy_m1_sel,    m1_stb_i => dummy_m1_stb,
        m1_cyc_i => dummy_m1_cyc,  m1_ack_o => open,
        s0_adr_o => s0_adr, s0_dat_o => s0_wdata, s0_dat_i => s0_rdata,
        s0_we_o  => s0_we,  s0_sel_o => s0_sel,   s0_stb_o => s0_stb,
        s0_cyc_o => s0_cyc, s0_ack_i => s0_ack,
        s1_adr_o => s1_adr, s1_dat_o => s1_wdata, s1_dat_i => s1_rdata,
        s1_we_o  => s1_we,  s1_sel_o => s1_sel,   s1_stb_o => s1_stb,
        s1_cyc_o => s1_cyc, s1_ack_i => s1_ack,
        s2_adr_o => s2_adr, s2_dat_o => s2_wdata, s2_dat_i => s2_rdata,
        s2_we_o  => s2_we,  s2_sel_o => s2_sel,   s2_stb_o => s2_stb,
        s2_cyc_o => s2_cyc, s2_ack_i => s2_ack,
        s3_adr_o => s3_adr, s3_dat_o => s3_wdata, s3_dat_i => s3_rdata,
        s3_we_o  => s3_we,  s3_sel_o => s3_sel,   s3_stb_o => s3_stb,
        s3_cyc_o => s3_cyc, s3_ack_i => s3_ack,
        s4_adr_o => s4_adr, s4_dat_o => s4_wdata, s4_dat_i => s4_rdata,
        s4_we_o  => s4_we,  s4_sel_o => s4_sel,   s4_stb_o => s4_stb,
        s4_cyc_o => s4_cyc, s4_ack_i => s4_ack,
        s5_adr_o => open, s5_dat_o => open, s5_dat_i => dummy_s_dat_i,
        s5_we_o  => open, s5_sel_o => open, s5_stb_o => open,
        s5_cyc_o => open, s5_ack_i => dummy_s_ack_i,
        s6_adr_o => open, s6_dat_o => open, s6_dat_i => dummy_s_dat_i,
        s6_we_o  => open, s6_sel_o => open, s6_stb_o => open,
        s6_cyc_o => open, s6_ack_i => dummy_s_ack_i,
        s7_adr_o => open, s7_dat_o => open, s7_dat_i => dummy_s_dat_i,
        s7_we_o  => open, s7_sel_o => open, s7_stb_o => open,
        s7_cyc_o => open, s7_ack_i => dummy_s_ack_i
    );

    -- SDRAM arbiter: CPU via WB bus (M0, low prio) + DMA direct (M1, high prio).
    -- All physical SDRAM signals are internal to memory_arbiter.
    u_sdram: memory_arbiter
    port map (
        wb_clk_i  => clk_i,
        wb_rst_i  => rst_i,
        m0_cyc_i  => s0_cyc,
        m0_stb_i  => s0_stb,
        m0_we_i   => s0_we,
        m0_adr_i  => s0_adr,
        m0_dat_i  => s0_wdata,
        m0_dat_o  => s0_rdata,
        m0_ack_o  => s0_ack,
        m1_cyc_i  => dma_cyc,
        m1_stb_i  => dma_stb,
        m1_we_i   => dma_we,
        m1_adr_i  => dma_adr,
        m1_dat_i  => dma_wdata,
        m1_dat_o  => dma_rdata,
        m1_ack_o  => dma_ack
    );

    u_spi: spi_master
    port map (
        clk_i => clk_i, rst_i => rst_i,
        cyc_i => s1_cyc, stb_i => s1_stb, we_i => s1_we,
        adr_i => s1_adr(7 downto 0), dat_i => s1_wdata, dat_o => s1_rdata, ack_o => s1_ack,
        mosi => mosi_p, miso => miso_p, sck => sck_p, cs => cs_p
    );

    u_pwm10: pwm_generic
    generic map ( nbit => 10 )
    port map (
        clk_i => clk_i, rst_i => rst_i,
        cyc_i => s2_cyc, stb_i => s2_stb, we_i => s2_we,
        adr_i => s2_adr(7 downto 0), dat_i => s2_wdata, dat_o => s2_rdata, ack_o => s2_ack,
        pwm_o => pwm_10_o
    );

    u_pwm4: pwm_generic
    generic map ( nbit => 4 )
    port map (
        clk_i => clk_i, rst_i => rst_i,
        cyc_i => s3_cyc, stb_i => s3_stb, we_i => s3_we,
        adr_i => s3_adr(7 downto 0), dat_i => s3_wdata, dat_o => s3_rdata, ack_o => s3_ack,
        pwm_o => pwm_4_o
    );

    u_gpio1: gpio_generic
    generic map ( nbit => 1 )
    port map (
        clk_i => clk_i, rst_i => rst_i,
        cyc_i => s4_cyc, stb_i => s4_stb, we_i => s4_we,
        adr_i => s4_adr(7 downto 0), dat_i => s4_wdata, dat_o => s4_rdata, ack_o => s4_ack,
        gpio_i => gpio_in_v, gpio_o => gpio_out_v
    );

end behavioral;