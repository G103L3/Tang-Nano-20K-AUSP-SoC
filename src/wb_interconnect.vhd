library ieee;
use ieee.std_logic_1164.all;

entity wb_interconnect is
    port (
        clk_i    : in  std_logic;
        m0_adr_i : in  std_logic_vector(31 downto 0);
        m0_dat_i : in  std_logic_vector(31 downto 0);
        m0_dat_o : out std_logic_vector(31 downto 0);
        m0_we_i  : in  std_logic;
        m0_sel_i : in  std_logic_vector(3 downto 0);
        m0_stb_i : in  std_logic;
        m0_cyc_i : in  std_logic;
        m0_ack_o : out std_logic;
        m1_adr_i : in  std_logic_vector(31 downto 0);
        m1_dat_i : in  std_logic_vector(31 downto 0);
        m1_dat_o : out std_logic_vector(31 downto 0);
        m1_we_i  : in  std_logic;
        m1_sel_i : in  std_logic_vector(3 downto 0);
        m1_stb_i : in  std_logic;
        m1_cyc_i : in  std_logic;
        m1_ack_o : out std_logic;
        s0_adr_o : out std_logic_vector(31 downto 0);
        s0_dat_o : out std_logic_vector(31 downto 0);
        s0_dat_i : in  std_logic_vector(31 downto 0);
        s0_we_o  : out std_logic;
        s0_sel_o : out std_logic_vector(3 downto 0);
        s0_stb_o : out std_logic;
        s0_cyc_o : out std_logic;
        s0_ack_i : in  std_logic;
        s1_adr_o : out std_logic_vector(31 downto 0);
        s1_dat_o : out std_logic_vector(31 downto 0);
        s1_dat_i : in  std_logic_vector(31 downto 0);
        s1_we_o  : out std_logic;
        s1_sel_o : out std_logic_vector(3 downto 0);
        s1_stb_o : out std_logic;
        s1_cyc_o : out std_logic;
        s1_ack_i : in  std_logic;
        s2_adr_o : out std_logic_vector(31 downto 0);
        s2_dat_o : out std_logic_vector(31 downto 0);
        s2_dat_i : in  std_logic_vector(31 downto 0);
        s2_we_o  : out std_logic;
        s2_sel_o : out std_logic_vector(3 downto 0);
        s2_stb_o : out std_logic;
        s2_cyc_o : out std_logic;
        s2_ack_i : in  std_logic;
        s3_adr_o : out std_logic_vector(31 downto 0);
        s3_dat_o : out std_logic_vector(31 downto 0);
        s3_dat_i : in  std_logic_vector(31 downto 0);
        s3_we_o  : out std_logic;
        s3_sel_o : out std_logic_vector(3 downto 0);
        s3_stb_o : out std_logic;
        s3_cyc_o : out std_logic;
        s3_ack_i : in  std_logic;
        s4_adr_o : out std_logic_vector(31 downto 0);
        s4_dat_o : out std_logic_vector(31 downto 0);
        s4_dat_i : in  std_logic_vector(31 downto 0);
        s4_we_o  : out std_logic;
        s4_sel_o : out std_logic_vector(3 downto 0);
        s4_stb_o : out std_logic;
        s4_cyc_o : out std_logic;
        s4_ack_i : in  std_logic;
        s5_adr_o : out std_logic_vector(31 downto 0);
        s5_dat_o : out std_logic_vector(31 downto 0);
        s5_dat_i : in  std_logic_vector(31 downto 0);
        s5_we_o  : out std_logic;
        s5_sel_o : out std_logic_vector(3 downto 0);
        s5_stb_o : out std_logic;
        s5_cyc_o : out std_logic;
        s5_ack_i : in  std_logic;
        s6_adr_o : out std_logic_vector(31 downto 0);
        s6_dat_o : out std_logic_vector(31 downto 0);
        s6_dat_i : in  std_logic_vector(31 downto 0);
        s6_we_o  : out std_logic;
        s6_sel_o : out std_logic_vector(3 downto 0);
        s6_stb_o : out std_logic;
        s6_cyc_o : out std_logic;
        s6_ack_i : in  std_logic;
        s7_adr_o : out std_logic_vector(31 downto 0);
        s7_dat_o : out std_logic_vector(31 downto 0);
        s7_dat_i : in  std_logic_vector(31 downto 0);
        s7_we_o  : out std_logic;
        s7_sel_o : out std_logic_vector(3 downto 0);
        s7_stb_o : out std_logic;
        s7_cyc_o : out std_logic;
        s7_ack_i : in  std_logic;
        s8_adr_o : out std_logic_vector(31 downto 0);
        s8_dat_o : out std_logic_vector(31 downto 0);
        s8_dat_i : in  std_logic_vector(31 downto 0);
        s8_we_o  : out std_logic;
        s8_sel_o : out std_logic_vector(3 downto 0);
        s8_stb_o : out std_logic;
        s8_cyc_o : out std_logic;
        s8_ack_i : in  std_logic;
        s9_adr_o : out std_logic_vector(31 downto 0);
        s9_dat_o : out std_logic_vector(31 downto 0);
        s9_dat_i : in  std_logic_vector(31 downto 0);
        s9_we_o  : out std_logic;
        s9_sel_o : out std_logic_vector(3 downto 0);
        s9_stb_o : out std_logic;
        s9_cyc_o : out std_logic;
        s9_ack_i : in  std_logic
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

    -- slave index decoded from addr[31:27], index 10 is the unmapped sink
    signal slv_idx : integer range 0 to 10;

    signal slv_dat : std_logic_vector(31 downto 0);
    signal slv_ack : std_logic;

    type dat_array_t is array(0 to 10) of std_logic_vector(31 downto 0);
    type ack_array_t is array(0 to 10) of std_logic;
    signal slv_dat_arr : dat_array_t;
    signal slv_ack_arr : ack_array_t;

    -- cpu bus watchdog: if a cpu (m0) access is not answered in time, force one
    -- ack so a dead or gated slave (adc spi ack gated on data_ready, or an
    -- unmapped address = slave 10) can never hang the soft core. TIMEOUT_MAX is
    -- deliberately wide: every real access (sdram, spi, uart) completes in at
    -- most a few hundred bus clocks, so this never fires on a legit transfer.
    constant TIMEOUT_MAX : integer := 200_000;   -- ~5 ms at 40.5 MHz
    signal wd_cnt      : integer range 0 to TIMEOUT_MAX := 0;
    signal wd_ack      : std_logic := '0';
    signal m0_real_ack : std_logic;

begin

    -- the accelerator master always wins over the cpu
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
            -- the 0x0 to 0x1 range is internal to the cpu ip, external
            -- reads there never complete, so the sdram sits at 0x4800_0000
            when "01001" => slv_idx <= 0;  -- 0x4800_0000  sdram snapshot
            when "00100" => slv_idx <= 6;  -- 0x2000_0000  character uart
            when "00101" => slv_idx <= 7;  -- 0x2800_0000  nor command uart
            when "00110" => slv_idx <= 5;  -- 0x3000_0000  audio accelerator
            when "00111" => slv_idx <= 8;  -- 0x3800_0000  nor flash spi
            when "01000" => slv_idx <= 1;  -- 0x4000_0000  adc spi
            when "01010" => slv_idx <= 2;  -- 0x5000_0000  speaker pwm
            when "01011" => slv_idx <= 9;  -- 0x5800_0000  tft display spi
            when "01100" => slv_idx <= 3;  -- 0x6000_0000  led pwm
            when "01110" => slv_idx <= 4;  -- 0x7000_0000  gpio
            when others  => slv_idx <= 10;
        end case;
    end process;

    -- address and data go to everyone, only the selected slave gets the strobe
    s0_adr_o <= sel_adr; s0_dat_o <= sel_dat; s0_we_o <= sel_we; s0_sel_o <= sel_sel;
    s1_adr_o <= sel_adr; s1_dat_o <= sel_dat; s1_we_o <= sel_we; s1_sel_o <= sel_sel;
    s2_adr_o <= sel_adr; s2_dat_o <= sel_dat; s2_we_o <= sel_we; s2_sel_o <= sel_sel;
    s3_adr_o <= sel_adr; s3_dat_o <= sel_dat; s3_we_o <= sel_we; s3_sel_o <= sel_sel;
    s4_adr_o <= sel_adr; s4_dat_o <= sel_dat; s4_we_o <= sel_we; s4_sel_o <= sel_sel;
    s5_adr_o <= sel_adr; s5_dat_o <= sel_dat; s5_we_o <= sel_we; s5_sel_o <= sel_sel;
    s6_adr_o <= sel_adr; s6_dat_o <= sel_dat; s6_we_o <= sel_we; s6_sel_o <= sel_sel;
    s7_adr_o <= sel_adr; s7_dat_o <= sel_dat; s7_we_o <= sel_we; s7_sel_o <= sel_sel;
    s8_adr_o <= sel_adr; s8_dat_o <= sel_dat; s8_we_o <= sel_we; s8_sel_o <= sel_sel;
    s9_adr_o <= sel_adr; s9_dat_o <= sel_dat; s9_we_o <= sel_we; s9_sel_o <= sel_sel;

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
    s9_stb_o <= sel_stb when slv_idx = 9 else '0';
    s9_cyc_o <= sel_cyc when slv_idx = 9 else '0';

    slv_dat_arr(0) <= s0_dat_i; slv_ack_arr(0) <= s0_ack_i;
    slv_dat_arr(1) <= s1_dat_i; slv_ack_arr(1) <= s1_ack_i;
    slv_dat_arr(2) <= s2_dat_i; slv_ack_arr(2) <= s2_ack_i;
    slv_dat_arr(3) <= s3_dat_i; slv_ack_arr(3) <= s3_ack_i;
    slv_dat_arr(4) <= s4_dat_i; slv_ack_arr(4) <= s4_ack_i;
    slv_dat_arr(5) <= s5_dat_i; slv_ack_arr(5) <= s5_ack_i;
    slv_dat_arr(6) <= s6_dat_i; slv_ack_arr(6) <= s6_ack_i;
    slv_dat_arr(7) <= s7_dat_i; slv_ack_arr(7) <= s7_ack_i;
    slv_dat_arr(8) <= s8_dat_i; slv_ack_arr(8) <= s8_ack_i;
    slv_dat_arr(9) <= s9_dat_i; slv_ack_arr(9) <= s9_ack_i;
    slv_dat_arr(10) <= (others => '0'); slv_ack_arr(10) <= '0';

    slv_dat <= slv_dat_arr(slv_idx);
    slv_ack <= slv_ack_arr(slv_idx);

    m0_dat_o <= slv_dat;
    m1_dat_o <= slv_dat;
    m0_real_ack <= slv_ack and not sel_m1;
    m0_ack_o    <= m0_real_ack or wd_ack;
    m1_ack_o    <= slv_ack and sel_m1;

    -- count while the cpu holds a request that is not being acked (whether it is
    -- stalled behind m1 or waiting on a slave that never acks); at TIMEOUT_MAX
    -- pulse one ack for a single cycle so the transaction always completes. Only
    -- m0 is guarded: m1 (accelerator) self stalls by design and must not be forced.
    cpu_watchdog : process(clk_i)
    begin
        if rising_edge(clk_i) then
            wd_ack <= '0';
            if m0_cyc_i = '1' and m0_stb_i = '1' and m0_real_ack = '0' then
                if wd_cnt >= TIMEOUT_MAX then
                    wd_ack <= '1';
                    wd_cnt <= 0;
                else
                    wd_cnt <= wd_cnt + 1;
                end if;
            else
                wd_cnt <= 0;
            end if;
        end if;
    end process;

end behavioral;
