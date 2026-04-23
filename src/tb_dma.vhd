library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TestBench is
end TestBench;

architecture TBarch of TestBench is

    component dma is
        port (
            clk_i            : in  std_logic;
            rst_i            : in  std_logic;
            s_cyc_i          : in  std_logic;
            s_stb_i          : in  std_logic;
            s_we_i           : in  std_logic;
            s_adr_i          : in  std_logic_vector(31 downto 0);
            s_dat_i          : in  std_logic_vector(31 downto 0);
            s_dat_o          : out std_logic_vector(31 downto 0);
            s_ack_o          : out std_logic;
            m_cyc_o          : out std_logic;
            m_stb_o          : out std_logic;
            m_we_o           : out std_logic;
            m_adr_o          : out std_logic_vector(31 downto 0);
            m_dat_o          : out std_logic_vector(31 downto 0);
            m_dat_i          : in  std_logic_vector(31 downto 0);
            m_ack_i          : in  std_logic;
            spi_data_ready_i : in  std_logic;
            irq_o            : out std_logic
        );
    end component;

    component SPI_Master is
        port (
            clk_i        : in  std_logic;
            rst_i        : in  std_logic;
            cyc_i        : in  std_logic;
            stb_i        : in  std_logic;
            we_i         : in  std_logic;
            adr_i        : in  std_logic_vector(7 downto 0);
            dat_i        : in  std_logic_vector(31 downto 0);
            dat_o        : out std_logic_vector(31 downto 0);
            ack_o        : out std_logic;
            data_ready_o : out std_logic;
            MOSI         : out std_logic;
            MISO         : in  std_logic;
            SCK          : out std_logic;
            CS           : out std_logic
        );
    end component;

    component wb_interconnect is
        port (
            m0_adr_i : in  std_logic_vector(31 downto 0); m0_dat_i : in  std_logic_vector(31 downto 0); m0_dat_o : out std_logic_vector(31 downto 0);
            m0_we_i  : in  std_logic; m0_sel_i : in  std_logic_vector(3 downto 0); m0_stb_i : in  std_logic; m0_cyc_i : in  std_logic; m0_ack_o : out std_logic;
            m1_adr_i : in  std_logic_vector(31 downto 0); m1_dat_i : in  std_logic_vector(31 downto 0); m1_dat_o : out std_logic_vector(31 downto 0);
            m1_we_i  : in  std_logic; m1_sel_i : in  std_logic_vector(3 downto 0); m1_stb_i : in  std_logic; m1_cyc_i : in  std_logic; m1_ack_o : out std_logic;
            s0_adr_o : out std_logic_vector(31 downto 0); s0_dat_o : out std_logic_vector(31 downto 0); s0_dat_i : in  std_logic_vector(31 downto 0);
            s0_we_o  : out std_logic; s0_sel_o : out std_logic_vector(3 downto 0); s0_stb_o : out std_logic; s0_cyc_o : out std_logic; s0_ack_i : in  std_logic;
            s1_adr_o : out std_logic_vector(31 downto 0); s1_dat_o : out std_logic_vector(31 downto 0); s1_dat_i : in  std_logic_vector(31 downto 0);
            s1_we_o  : out std_logic; s1_sel_o : out std_logic_vector(3 downto 0); s1_stb_o : out std_logic; s1_cyc_o : out std_logic; s1_ack_i : in  std_logic;
            s2_adr_o : out std_logic_vector(31 downto 0); s2_dat_o : out std_logic_vector(31 downto 0); s2_dat_i : in  std_logic_vector(31 downto 0);
            s2_we_o  : out std_logic; s2_sel_o : out std_logic_vector(3 downto 0); s2_stb_o : out std_logic; s2_cyc_o : out std_logic; s2_ack_i : in  std_logic;
            s3_adr_o : out std_logic_vector(31 downto 0); s3_dat_o : out std_logic_vector(31 downto 0); s3_dat_i : in  std_logic_vector(31 downto 0);
            s3_we_o  : out std_logic; s3_sel_o : out std_logic_vector(3 downto 0); s3_stb_o : out std_logic; s3_cyc_o : out std_logic; s3_ack_i : in  std_logic;
            s4_adr_o : out std_logic_vector(31 downto 0); s4_dat_o : out std_logic_vector(31 downto 0); s4_dat_i : in  std_logic_vector(31 downto 0);
            s4_we_o  : out std_logic; s4_sel_o : out std_logic_vector(3 downto 0); s4_stb_o : out std_logic; s4_cyc_o : out std_logic; s4_ack_i : in  std_logic;
            s5_adr_o : out std_logic_vector(31 downto 0); s5_dat_o : out std_logic_vector(31 downto 0); s5_dat_i : in  std_logic_vector(31 downto 0);
            s5_we_o  : out std_logic; s5_sel_o : out std_logic_vector(3 downto 0); s5_stb_o : out std_logic; s5_cyc_o : out std_logic; s5_ack_i : in  std_logic;
            s6_adr_o : out std_logic_vector(31 downto 0); s6_dat_o : out std_logic_vector(31 downto 0); s6_dat_i : in  std_logic_vector(31 downto 0);
            s6_we_o  : out std_logic; s6_sel_o : out std_logic_vector(3 downto 0); s6_stb_o : out std_logic; s6_cyc_o : out std_logic; s6_ack_i : in  std_logic;
            s7_adr_o : out std_logic_vector(31 downto 0); s7_dat_o : out std_logic_vector(31 downto 0); s7_dat_i : in  std_logic_vector(31 downto 0);
            s7_we_o  : out std_logic; s7_sel_o : out std_logic_vector(3 downto 0); s7_stb_o : out std_logic; s7_cyc_o : out std_logic; s7_ack_i : in  std_logic
        );
    end component;

    signal clk_i : std_logic := '0';
    signal rst_i : std_logic := '0';

    signal s_cyc_i : std_logic := '0';
    signal s_stb_i : std_logic := '0';
    signal s_we_i  : std_logic := '0';
    signal s_adr_i : std_logic_vector(31 downto 0) := (others => '0');
    signal s_dat_i : std_logic_vector(31 downto 0) := (others => '0');
    signal s_dat_o : std_logic_vector(31 downto 0);
    signal s_ack_o : std_logic;

    signal m_cyc_o : std_logic;
    signal m_stb_o : std_logic;
    signal m_we_o  : std_logic;
    signal m_adr_o : std_logic_vector(31 downto 0);
    signal m_dat_o : std_logic_vector(31 downto 0);
    signal m_dat_i : std_logic_vector(31 downto 0);
    signal m_ack_i : std_logic;
    signal irq_o             : std_logic;
    signal spi_data_ready_s  : std_logic;

    signal m1_ack_bus    : std_logic := '0'; -- ack dall'interconnect (SPI via s1)
    signal m_ack_sdram   : std_logic := '0'; -- ack BFM diretto SDRAM
    signal sdram_dat_r   : std_logic_vector(31 downto 0) := (others => '0');
    signal m_dat_from_bus: std_logic_vector(31 downto 0); -- dati da SPI via interconnect

    signal s0_adr_s  : std_logic_vector(31 downto 0);
    signal s0_dat_ws : std_logic_vector(31 downto 0);
    signal s0_dat_rs : std_logic_vector(31 downto 0) := (others => '0');
    signal s0_we_s   : std_logic;
    signal s0_sel_s  : std_logic_vector(3 downto 0);
    signal s0_stb_s  : std_logic;
    signal s0_cyc_s  : std_logic;
    signal s0_ack_s  : std_logic := '0';

    signal s1_adr_s  : std_logic_vector(31 downto 0);
    signal s1_dat_ws : std_logic_vector(31 downto 0);
    signal s1_dat_rs : std_logic_vector(31 downto 0);
    signal s1_we_s   : std_logic;
    signal s1_sel_s  : std_logic_vector(3 downto 0);
    signal s1_stb_s  : std_logic;
    signal s1_cyc_s  : std_logic;
    signal s1_ack_s  : std_logic;

    signal MOSI : std_logic;
    signal MISO : std_logic := '0';
    signal SCK  : std_logic;
    signal CS   : std_logic;

begin

    clk_i <= not clk_i after 5 ns;

    u_dma: dma
    port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        s_cyc_i => s_cyc_i,
        s_stb_i => s_stb_i,
        s_we_i  => s_we_i,
        s_adr_i => s_adr_i,
        s_dat_i => s_dat_i,
        s_dat_o => s_dat_o,
        s_ack_o => s_ack_o,
        m_cyc_o => m_cyc_o,
        m_stb_o => m_stb_o,
        m_we_o  => m_we_o,
        m_adr_o => m_adr_o,
        m_dat_o => m_dat_o,
        m_dat_i          => m_dat_i,
        m_ack_i          => m_ack_i,
        spi_data_ready_i => spi_data_ready_s,
        irq_o            => irq_o
    );

    u_bus: wb_interconnect
    port map (
        m0_adr_i => (others => '0'), m0_dat_i => (others => '0'), m0_dat_o => open,
        m0_we_i  => '0',             m0_sel_i => "0000",           m0_stb_i => '0', m0_cyc_i => '0', m0_ack_o => open,
        m1_adr_i => m_adr_o,         m1_dat_i => m_dat_o,          m1_dat_o => m_dat_from_bus,
        m1_we_i  => m_we_o,          m1_sel_i => "1111",            m1_stb_i => m_stb_o, m1_cyc_i => m_cyc_o, m1_ack_o => m1_ack_bus,
        s0_adr_o => s0_adr_s,  s0_dat_o => s0_dat_ws, s0_dat_i => s0_dat_rs,
        s0_we_o  => s0_we_s,   s0_sel_o => s0_sel_s,  s0_stb_o => s0_stb_s, s0_cyc_o => s0_cyc_s, s0_ack_i => s0_ack_s,
        s1_adr_o => s1_adr_s,  s1_dat_o => s1_dat_ws, s1_dat_i => s1_dat_rs,
        s1_we_o  => s1_we_s,   s1_sel_o => s1_sel_s,  s1_stb_o => s1_stb_s, s1_cyc_o => s1_cyc_s, s1_ack_i => s1_ack_s,
        s2_adr_o => open, s2_dat_o => open, s2_dat_i => (others => '0'),
        s2_we_o  => open, s2_sel_o => open, s2_stb_o => open, s2_cyc_o => open, s2_ack_i => '0',
        s3_adr_o => open, s3_dat_o => open, s3_dat_i => (others => '0'),
        s3_we_o  => open, s3_sel_o => open, s3_stb_o => open, s3_cyc_o => open, s3_ack_i => '0',
        s4_adr_o => open, s4_dat_o => open, s4_dat_i => (others => '0'),
        s4_we_o  => open, s4_sel_o => open, s4_stb_o => open, s4_cyc_o => open, s4_ack_i => '0',
        s5_adr_o => open, s5_dat_o => open, s5_dat_i => (others => '0'),
        s5_we_o  => open, s5_sel_o => open, s5_stb_o => open, s5_cyc_o => open, s5_ack_i => '0',
        s6_adr_o => open, s6_dat_o => open, s6_dat_i => (others => '0'),
        s6_we_o  => open, s6_sel_o => open, s6_stb_o => open, s6_cyc_o => open, s6_ack_i => '0',
        s7_adr_o => open, s7_dat_o => open, s7_dat_i => (others => '0'),
        s7_we_o  => open, s7_sel_o => open, s7_stb_o => open, s7_cyc_o => open, s7_ack_i => '0'
    );

    u_spi: SPI_Master
    port map (
        clk_i => clk_i,
        rst_i => rst_i,
        cyc_i => s1_cyc_s,
        stb_i => s1_stb_s,
        we_i  => s1_we_s,
        adr_i => s1_adr_s(7 downto 0),
        dat_i => s1_dat_ws,
        dat_o        => s1_dat_rs,
        ack_o        => s1_ack_s,
        data_ready_o => spi_data_ready_s,
        MOSI         => MOSI,
        MISO         => MISO,
        SCK          => SCK,
        CS           => CS
    );

    -- s0 BFM minimale: solo ack (dati SDRAM gestiti dal BFM diretto sotto)
    s0_dat_rs <= (others => '0');
    sdram_s0_ack: process(clk_i)
    begin
        if rising_edge(clk_i) then
            s0_ack_s <= '0';
            if s0_cyc_s = '1' and s0_stb_s = '1' then
                s0_ack_s <= '1';
            end if;
        end if;
    end process;

    -- BFM SDRAM diretto: bypassa l'interconnect per SDRAM (bit[31:28]=0001).
    -- Array 8192x32-bit: campioni 256..1279, risultati FFT 0x1300..0x14FF.
    sdram_bfm: process(clk_i)
        type mem_t is array (0 to 8191) of std_logic_vector(31 downto 0);
        variable mem  : mem_t := (others => (others => '0'));
        variable addr : integer range 0 to 8191;
    begin
        if rising_edge(clk_i) then
            m_ack_sdram <= '0';
            sdram_dat_r <= (others => '0');
            if m_cyc_o = '1' and m_stb_o = '1' and
               m_adr_o(31 downto 28) = "0001" then
                m_ack_sdram <= '1';
                addr := to_integer(unsigned(m_adr_o(12 downto 0)));
                if m_we_o = '1' then
                    mem(addr) := m_dat_o;
                else
                    sdram_dat_r <= mem(addr);
                end if;
            end if;
        end if;
    end process;

    -- Ack: SPI dall'interconnect, SDRAM dal BFM diretto
    m_ack_i <= m1_ack_bus or m_ack_sdram;
    -- Data: SPI dall'interconnect (SPI master via s1), SDRAM dal BFM diretto
    m_dat_i <= m_dat_from_bus when m_adr_o(31 downto 28) = "0100" else sdram_dat_r;

    process(SCK)
    begin
        if falling_edge(SCK) then
            MISO <= not MISO;
        end if;
    end process;

    process
    begin
        rst_i <= '0';
        wait for 20 ns;
        rst_i <= '1';
        wait for 20 ns;

        wait until rising_edge(clk_i);
        s_cyc_i <= '1'; s_stb_i <= '1'; s_we_i <= '1';
        s_adr_i <= x"00000003";
        s_dat_i <= x"00000100";
        wait until rising_edge(clk_i);
        s_cyc_i <= '0'; s_stb_i <= '0'; s_we_i <= '0';

        wait until rising_edge(clk_i);

        wait until rising_edge(clk_i);
        s_cyc_i <= '1'; s_stb_i <= '1'; s_we_i <= '1';
        s_adr_i <= x"00000001";
        s_dat_i <= x"00000001";
        wait until rising_edge(clk_i);
        s_cyc_i <= '0'; s_stb_i <= '0'; s_we_i <= '0';

        wait for 6000 us;

        wait until rising_edge(clk_i);
        wait for 10000 ns;
        s_cyc_i <= '1'; s_stb_i <= '1'; s_we_i <= '1';
        s_adr_i <= x"00000002";
        s_dat_i <= x"00000000";
        wait for 10000 ns;
        wait until rising_edge(clk_i);
        s_cyc_i <= '0'; s_stb_i <= '0'; s_we_i <= '0';

        wait for 10000 ns;

        assert false report "=== SIMULAZIONE COMPLETATA ===" severity failure;
        wait;
    end process;

end TBarch;
