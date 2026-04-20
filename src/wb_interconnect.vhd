library ieee;
use ieee.std_logic_1164.all;

-- Wishbone shared-bus crossbar: 2 masters, 8 slaves.
-- Priority: M1 > M0 when both active simultaneously.
--
-- Address map (bits [31:28] of address):
--   0x1xxxxxxx  S0  SDRAM (via memory_arbiter M0)   [C: 0x10000000]
--   0x3xxxxxxx  S5  DMA control registers            [C: 0x30000000]
--   0x4xxxxxxx  S1  SPI Master                       [C: 0x40000000]
--   0x5xxxxxxx  S2  PWM 10-bit                       [C: 0x50000000]
--   0x6xxxxxxx  S3  PWM 4-bit                        [C: 0x60000000]
--   0x7xxxxxxx  S4  GPIO                             [C: 0x70000000]
--
-- NOTE: CPU WB interface activates for mem_addr[31:28] > 0 AND mem_addr[31]=0,
-- so 0x0xxxxxxx (DTCM/ITCM range) and 0x8xxxxxxx (bit31=1) CANNOT be used here.
--   others      --  unmapped (ack=0, dat=0)
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
        s7_ack_i : in  std_logic
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

    -- Slave index (0-7) decoded from address bits [31:28]
    signal slv_idx : integer range 0 to 7;

    signal slv_dat : std_logic_vector(31 downto 0);
    signal slv_ack : std_logic;

    type dat_array_t is array(0 to 7) of std_logic_vector(31 downto 0);
    type ack_array_t is array(0 to 7) of std_logic;
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
        case sel_adr(31 downto 28) is
            when "0001" => slv_idx <= 0;  -- 0x1xxxxxxx  SDRAM
            when "0011" => slv_idx <= 5;  -- 0x3xxxxxxx  DMA
            when "0100" => slv_idx <= 1;  -- 0x4xxxxxxx  SPI
            when "0101" => slv_idx <= 2;  -- 0x5xxxxxxx  PWM10
            when "0110" => slv_idx <= 3;  -- 0x6xxxxxxx  PWM4
            when "0111" => slv_idx <= 4;  -- 0x7xxxxxxx  GPIO
            when others => slv_idx <= 6;  -- unmapped
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
    s7_stb_o <= '0';
    s7_cyc_o <= '0';

    -- Slave read-data/ack arrays for clean mux
    slv_dat_arr(0) <= s0_dat_i; slv_ack_arr(0) <= s0_ack_i;
    slv_dat_arr(1) <= s1_dat_i; slv_ack_arr(1) <= s1_ack_i;
    slv_dat_arr(2) <= s2_dat_i; slv_ack_arr(2) <= s2_ack_i;
    slv_dat_arr(3) <= s3_dat_i; slv_ack_arr(3) <= s3_ack_i;
    slv_dat_arr(4) <= s4_dat_i; slv_ack_arr(4) <= s4_ack_i;
    slv_dat_arr(5) <= s5_dat_i; slv_ack_arr(5) <= s5_ack_i;
    slv_dat_arr(6) <= (others => '0'); slv_ack_arr(6) <= '0';
    slv_dat_arr(7) <= (others => '0'); slv_ack_arr(7) <= '0';

    slv_dat <= slv_dat_arr(slv_idx);
    slv_ack <= slv_ack_arr(slv_idx);

    m0_dat_o <= slv_dat;
    m1_dat_o <= slv_dat;
    m0_ack_o <= slv_ack and not sel_m1;
    m1_ack_o <= slv_ack and     sel_m1;

end behavioral;
