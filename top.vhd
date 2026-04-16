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
            m0_adr_i : in std_logic_vector(31 downto 0);
            m0_dat_i : in std_logic_vector(31 downto 0);
            m0_dat_o : out std_logic_vector(31 downto 0);
            m0_we_i  : in std_logic;
            m0_sel_i : in std_logic_vector(3 downto 0);
            m0_stb_i : in std_logic;
            m0_cyc_i : in std_logic;
            m0_ack_o : out std_logic;
            m1_adr_i : in std_logic_vector(31 downto 0);
            m1_dat_i : in std_logic_vector(31 downto 0);
            m1_dat_o : out std_logic_vector(31 downto 0);
            m1_we_i  : in std_logic;
            m1_sel_i : in std_logic_vector(3 downto 0);
            m1_stb_i : in std_logic;
            m1_cyc_i : in std_logic;
            m1_ack_o : out std_logic;
            s0_adr_o : out std_logic_vector(31 downto 0);
            s0_dat_o : out std_logic_vector(31 downto 0);
            s0_dat_i : in std_logic_vector(31 downto 0);
            s0_we_o  : out std_logic;
            s0_sel_o : out std_logic_vector(3 downto 0);
            s0_stb_o : out std_logic;
            s0_cyc_o : out std_logic;
            s0_ack_i : in std_logic;
            s1_adr_o : out std_logic_vector(31 downto 0);
            s1_dat_o : out std_logic_vector(31 downto 0);
            s1_dat_i : in std_logic_vector(31 downto 0);
            s1_we_o  : out std_logic;
            s1_sel_o : out std_logic_vector(3 downto 0);
            s1_stb_o : out std_logic;
            s1_cyc_o : out std_logic;
            s1_ack_i : in std_logic
        );
    end component;

    component spi_master
        port (
            clk_i : in  std_logic;
            rst_i : in  std_logic;
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            we_i  : in  std_logic;
            dat_i : in  std_logic_vector(31 downto 0);
            dat_o : out std_logic_vector(31 downto 0);
            ack_o : out std_logic;
            mosi  : out std_logic;
            miso  : in  std_logic;
            sck   : out std_logic;
            cs    : out std_logic
        );
    end component;

    signal cpu_adr, cpu_wdata, cpu_rdata : std_logic_vector(31 downto 0);
    signal cpu_stb, cpu_we, cpu_cyc, cpu_ack : std_logic;
    signal cpu_sel : std_logic_vector(3 downto 0);

    signal s1_adr, s1_wdata, s1_rdata : std_logic_vector(31 downto 0);
    signal s1_stb, s1_we, s1_cyc, s1_ack : std_logic;
    signal s1_sel : std_logic_vector(3 downto 0);

    signal dummy_m1_adr, dummy_m1_dat_i, dummy_m1_dat_o : std_logic_vector(31 downto 0) := (others => '0');
    signal dummy_m1_stb, dummy_m1_we, dummy_m1_cyc, dummy_m1_ack : std_logic := '0';
    signal dummy_m1_sel : std_logic_vector(3 downto 0) := (others => '0');

    signal dummy_s0_adr, dummy_s0_dat_o, dummy_s0_dat_i : std_logic_vector(31 downto 0) := (others => '0');
    signal dummy_s0_stb, dummy_s0_we, dummy_s0_cyc, dummy_s0_ack : std_logic := '0';
    signal dummy_s0_sel : std_logic_vector(3 downto 0) := (others => '0');

    signal irq_dummy : std_logic_vector(31 downto 20) := (others => '0');

begin

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
        m0_adr_i => cpu_adr,
        m0_dat_i => cpu_wdata,
        m0_dat_o => cpu_rdata,
        m0_we_i  => cpu_we,
        m0_sel_i => cpu_sel,
        m0_stb_i => cpu_stb,
        m0_cyc_i => cpu_cyc,
        m0_ack_o => cpu_ack,
        
        m1_adr_i => dummy_m1_adr,
        m1_dat_i => dummy_m1_dat_i,
        m1_dat_o => dummy_m1_dat_o,
        m1_we_i  => dummy_m1_we,
        m1_sel_i => dummy_m1_sel,
        m1_stb_i => dummy_m1_stb,
        m1_cyc_i => dummy_m1_cyc,
        m1_ack_o => dummy_m1_ack,

        s0_adr_o => dummy_s0_adr,
        s0_dat_o => dummy_s0_dat_o,
        s0_dat_i => dummy_s0_dat_i,
        s0_we_o  => dummy_s0_we,
        s0_sel_o => dummy_s0_sel,
        s0_stb_o => dummy_s0_stb,
        s0_cyc_o => dummy_s0_cyc,
        s0_ack_i => dummy_s0_ack,
        
        s1_adr_o => s1_adr,
        s1_dat_o => s1_wdata,
        s1_dat_i => s1_rdata,
        s1_we_o  => s1_we,
        s1_sel_o => s1_sel,
        s1_stb_o => s1_stb,
        s1_cyc_o => s1_cyc,
        s1_ack_i => s1_ack
    );

    u_spi: spi_master
    port map (
        clk_i => clk_i,
        rst_i => rst_i,
        cyc_i => s1_cyc,
        stb_i => s1_stb,
        we_i  => s1_we,
        dat_i => s1_wdata,
        dat_o => s1_rdata,
        ack_o => s1_ack,
        mosi  => mosi_p,
        miso  => miso_p,
        sck   => sck_p,
        cs    => cs_p
    );

end behavioral;