library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dma is
    port (
        clk_i    : in  std_logic;
        rst_i    : in  std_logic;

        s_cyc_i  : in  std_logic;
        s_stb_i  : in  std_logic;
        s_we_i   : in  std_logic;
        s_adr_i  : in  std_logic_vector(31 downto 0);
        s_dat_i  : in  std_logic_vector(31 downto 0);
        s_dat_o  : out std_logic_vector(31 downto 0);
        s_ack_o  : out std_logic;

        m_cyc_o  : out std_logic;
        m_stb_o  : out std_logic;
        m_we_o   : out std_logic;
        m_adr_o  : out std_logic_vector(31 downto 0);
        m_dat_o  : out std_logic_vector(31 downto 0);
        m_dat_i  : in  std_logic_vector(31 downto 0);
        m_ack_i  : in  std_logic;

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
end dma;

architecture behavioral of dma is

    component FFT_Top is
        port (
            idx   : out std_logic_vector(8 downto 0);
            xk_re : out std_logic_vector(15 downto 0);
            xk_im : out std_logic_vector(15 downto 0);
            sod   : out std_logic;
            ipd   : out std_logic;
            eod   : out std_logic;
            busy  : out std_logic;
            soud  : out std_logic;
            opd   : out std_logic;
            eoud  : out std_logic;
            xn_re : in  std_logic_vector(15 downto 0);
            xn_im : in  std_logic_vector(15 downto 0);
            start : in  std_logic;
            clk   : in  std_logic;
            rst   : in  std_logic
        );
    end component;

    signal xn_re_s     : std_logic_vector(15 downto 0) := (others => '0');
    signal xk_re_s     : std_logic_vector(15 downto 0);
    signal xk_im_s     : std_logic_vector(15 downto 0);
    signal idx_s       : std_logic_vector(8 downto 0);
    signal fft_start_s : std_logic := '0';
    signal fft_sod_s   : std_logic;
    signal fft_ipd_s   : std_logic;
    signal fft_eod_s   : std_logic;
    signal fft_busy_s  : std_logic;
    signal fft_soud_s  : std_logic;
    signal fft_opd_s   : std_logic;
    signal fft_eoud_s  : std_logic;

    -- ping pong input buffer, two 512 sample windows in one block ram
    type t_spi_raw_buf is array (0 to 1023) of std_logic_vector(15 downto 0);
    signal spi_raw_buf : t_spi_raw_buf := (others => (others => '0'));
    signal spi_wr_ptr  : unsigned(9 downto 0) := (others => '0');

    type t_fft_result_buf is array (0 to 511) of std_logic_vector(15 downto 0);
    signal fft_result_buf : t_fft_result_buf := (others => (others => '0'));

    signal fft_trigger  : std_logic := '0';
    signal fft_win_base : unsigned(9 downto 0) := (others => '0');

    signal dma_cyc : std_logic := '0';
    signal dma_stb : std_logic := '0';
    signal dma_we  : std_logic := '0';
    signal dma_adr : std_logic_vector(31 downto 0) := (others => '0');
    signal dma_dat : std_logic_vector(31 downto 0) := (others => '0');

    signal fft_cyc : std_logic := '0';
    signal fft_stb : std_logic := '0';
    signal fft_we  : std_logic := '0';
    signal fft_adr : std_logic_vector(31 downto 0) := (others => '0');
    signal fft_dat : std_logic_vector(31 downto 0) := (others => '0');

    type dma_state_t is (DS_IDLE, DS_OPEN, DS_POLL, DS_READ, DS_CLRDY, DS_STORE);
    signal dma_curr_state, dma_next_state : dma_state_t := DS_IDLE;
    signal dma_rdata : std_logic_vector(31 downto 0) := (others => '0');

    type fft_state_t is (FS_IDLE, FS_FEED1, FS_COMPUTE, FS_COLLECT,
                         FS_SDR_SETTLE, FS_SDR_WW, FS_SDR_W,
                         FS_IRQ, FS_SERIAL);
    signal fft_curr_state, fft_next_state : fft_state_t := FS_IDLE;
    signal fft_rd_idx : unsigned(8 downto 0) := (others => '0');

    -- 20 bursts of 26 words cover the 512 bins, one sdram row per burst
    constant SDR_NBURST : integer := 20;
    signal sdr_own     : std_logic := '0';
    signal sdr_wr_n    : std_logic := '1';
    signal sdr_addr    : std_logic_vector(20 downto 0) := (others => '0');
    signal sdr_data    : std_logic_vector(31 downto 0) := (others => '0');
    signal sdr_burst   : integer range 0 to 19 := 0;
    signal sdr_widx    : integer range 0 to 31 := 0;
    signal sdr_timeout : integer range 0 to 255 := 0;
    signal sdr_settle  : integer range 0 to 500000 := 0;
    signal sdr_warm    : std_logic := '1';
    signal sdr_done    : std_logic := '0';

    -- clamp to bin 511, the tail of the last burst repeats the final bin
    function buf_idx(b, i : integer) return integer is
        variable x : integer;
    begin
        x := b * 26 + i;
        if x > 511 then return 511; else return x; end if;
    end function;

    signal start_r      : std_logic := '1';
    signal base_address : unsigned(20 downto 0) := (others => '0');

    signal start_req      : std_logic := '0';
    signal drain_reached  : std_logic := '0';
    signal drain_ack_seen : std_logic := '0';

    signal ser_word_cnt : unsigned(8 downto 0)          := (others => '0');
    signal ser_bit_cnt  : unsigned(3 downto 0)          := (others => '0');
    signal ser_sreg     : std_logic_vector(15 downto 0) := (others => '0');

begin

    sdr_own_o  <= sdr_own;
    sdr_wr_n_o <= sdr_wr_n;
    sdr_addr_o <= sdr_addr;
    sdr_data_o <= sdr_data;

    fft_trigger_o <= fft_trigger;
    fft_dbg_o     <= drain_reached;
    fft_ack_dbg_o <= drain_ack_seen;
    fft_idx_o     <= idx_s;
    fft_xk_re_o   <= xk_re_s;
    fft_opd_o     <= fft_opd_s;

    -- bus master mux: the capture side always wins, the drain side only
    -- advances when it gets the ack, so it stalls by itself
    m_cyc_o <= dma_cyc when dma_cyc = '1' else fft_cyc;
    m_stb_o <= dma_stb when dma_cyc = '1' else fft_stb;
    m_we_o  <= dma_we  when dma_cyc = '1' else fft_we;
    m_adr_o <= dma_adr when dma_cyc = '1' else fft_adr;
    m_dat_o <= dma_dat when dma_cyc = '1' else fft_dat;

    fft_inst_0 : FFT_Top
        port map (
            idx   => idx_s,
            xk_re => xk_re_s,
            xk_im => xk_im_s,
            sod   => fft_sod_s,
            ipd   => fft_ipd_s,
            eod   => fft_eod_s,
            busy  => fft_busy_s,
            soud  => fft_soud_s,
            opd   => fft_opd_s,
            eoud  => fft_eoud_s,
            xn_re => xn_re_s,
            xn_im => (others => '0'),
            start => fft_start_s,
            clk   => clk_i,
            rst   => '0'
        );

    -- control registers seen by the cpu
    wb_slave: process(clk_i)
    begin
        if rising_edge(clk_i) then
            s_ack_o <= '0';
            s_dat_o <= (others => '0');
            if s_cyc_i = '1' and s_stb_i = '1' then
                s_ack_o <= '1';
                if s_we_i = '1' then
                    case s_adr_i(7 downto 0) is
                        when x"04" => start_r      <= '1';
                        when x"08" => start_r      <= '0';
                        when x"0C" => base_address <= unsigned(s_dat_i(20 downto 0));
                        when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process;

    -- capture machine, next state logic
    dma_comb : process(dma_curr_state, start_r, m_ack_i, spi_data_ready_i)
    begin
        dma_next_state <= dma_curr_state;
        case dma_curr_state is
            when DS_IDLE =>
                if start_r = '1' then dma_next_state <= DS_OPEN; end if;
            when DS_OPEN =>
                if m_ack_i = '1' then dma_next_state <= DS_POLL; end if;
            when DS_POLL =>
                if spi_data_ready_i = '1' then dma_next_state <= DS_READ; end if;
            when DS_READ =>
                if m_ack_i = '1' then dma_next_state <= DS_CLRDY; end if;
            when DS_CLRDY =>
                if m_ack_i = '1' then dma_next_state <= DS_STORE; end if;
            when DS_STORE =>
                dma_next_state <= DS_POLL;
        end case;
    end process;

    -- capture machine, one loop per adc sample: read the word over the bus,
    -- clear the ready flag, store the low 12 bits in the ping pong buffer
    dma_sync : process(clk_i)
    begin
        if rising_edge(clk_i) then
            dma_curr_state <= dma_next_state;
            dma_cyc     <= '0';
            dma_stb     <= '0';
            dma_we      <= '0';
            fft_trigger <= '0';

            case dma_curr_state is

                when DS_IDLE =>
                    spi_wr_ptr <= (others => '0');

                when DS_OPEN =>
                    -- enable the adc spi master once
                    dma_cyc <= '1';
                    dma_stb <= '1';
                    dma_we  <= '1';
                    dma_adr <= x"40000004";
                    dma_dat <= x"00000001";

                when DS_POLL =>
                    null;

                when DS_READ =>
                    dma_cyc <= '1';
                    dma_stb <= '1';
                    dma_we  <= '0';
                    dma_adr <= x"40000000";
                    if m_ack_i = '1' then
                        dma_rdata <= m_dat_i;
                    end if;

                when DS_CLRDY =>
                    dma_cyc <= '1';
                    dma_stb <= '1';
                    dma_we  <= '1';
                    dma_adr <= x"4000000C";
                    dma_dat <= (others => '0');

                when DS_STORE =>
                    -- every 512th sample hands the full window to the fft side
                    spi_raw_buf(to_integer(spi_wr_ptr)) <= x"0" & dma_rdata(11 downto 0);
                    if spi_wr_ptr(8 downto 0) = "111111111" then
                        if spi_wr_ptr(9) = '0' then
                            fft_win_base <= (others => '0');
                        else
                            fft_win_base <= to_unsigned(512, 10);
                        end if;
                        fft_trigger <= '1';
                    end if;
                    spi_wr_ptr <= spi_wr_ptr + 1;

            end case;
        end if;
    end process;

    -- fft machine, next state logic
    fft_comb : process(fft_curr_state, fft_trigger, sdr_done, fft_eod_s,
                       fft_eoud_s, sdr_initdone_i, sdr_settle, sdr_busy_n_i,
                       sdr_timeout, sdr_warm, sdr_burst, ser_bit_cnt, ser_word_cnt)
    begin
        fft_next_state <= fft_curr_state;
        case fft_curr_state is
            when FS_IDLE =>
                if fft_trigger = '1' and sdr_done = '0' then
                    fft_next_state <= FS_FEED1;
                end if;
            when FS_FEED1 =>
                if fft_eod_s = '1' then fft_next_state <= FS_COMPUTE; end if;
            when FS_COMPUTE =>
                fft_next_state <= FS_COLLECT;
            when FS_COLLECT =>
                if fft_eoud_s = '1' then fft_next_state <= FS_SDR_SETTLE; end if;
            when FS_SDR_SETTLE =>
                if sdr_initdone_i = '1' and sdr_settle = 200000 then
                    fft_next_state <= FS_SDR_WW;
                end if;
            when FS_SDR_WW =>
                if sdr_busy_n_i = '1' then fft_next_state <= FS_SDR_W; end if;
            when FS_SDR_W =>
                if sdr_timeout = 28 then
                    if sdr_warm = '1' then
                        fft_next_state <= FS_SDR_WW;
                    elsif sdr_burst = SDR_NBURST - 1 then
                        fft_next_state <= FS_IRQ;
                    else
                        fft_next_state <= FS_SDR_WW;
                    end if;
                end if;
            when FS_IRQ =>
                fft_next_state <= FS_SERIAL;
            when FS_SERIAL =>
                if ser_bit_cnt = 15 and ser_word_cnt = 511 then
                    fft_next_state <= FS_IDLE;
                end if;
        end case;
    end process;

    -- fft machine: feed the window to the core, collect the 512 bins, then
    -- drain them to sdram through the dedicated write port and raise the irq;
    -- the feed, collect and drain never touch the wishbone bus
    fft_sync : process(clk_i)
    begin
        if rising_edge(clk_i) then
            fft_curr_state <= fft_next_state;
            fft_cyc     <= '0';
            fft_stb     <= '0';
            fft_we      <= '0';
            irq_o       <= '0';
            fft_ser_o   <= '0';
            fft_start_s <= start_req;
            start_req   <= '0';
            sdr_wr_n    <= '1';

            case fft_curr_state is

                when FS_IDLE =>
                    sdr_own    <= '0';
                    fft_rd_idx <= (others => '0');
                    if fft_trigger = '1' and sdr_done = '0' then
                        start_req <= '1';
                    end if;

                when FS_FEED1 =>
                    if fft_ipd_s = '1' then
                        xn_re_s    <= spi_raw_buf(to_integer(fft_win_base + resize(fft_rd_idx, 10)));
                        fft_rd_idx <= fft_rd_idx + 1;
                    end if;

                when FS_COMPUTE =>
                    null;

                when FS_COLLECT =>
                    if fft_opd_s = '1' then
                        fft_result_buf(to_integer(unsigned(idx_s))) <= xk_re_s;
                    end if;
                    if fft_eoud_s = '1' then
                        drain_reached <= '1';
                        sdr_own    <= '1';
                        sdr_warm   <= '1';
                        sdr_burst  <= 0;
                        sdr_widx   <= 0;
                        sdr_settle <= 0;
                    end if;

                -- settle wait before the first write, kept from the proven
                -- bring up: the first transaction after a quiet spell failed
                when FS_SDR_SETTLE =>
                    sdr_own  <= '1';
                    sdr_wr_n <= '1';
                    if sdr_initdone_i = '1' then
                        sdr_settle <= sdr_settle + 1;
                        if sdr_settle = 200000 then
                            sdr_settle  <= 0;
                            sdr_warm    <= '1';
                            sdr_burst   <= 0;
                            sdr_widx    <= 0;
                            sdr_timeout <= 0;
                        end if;
                    end if;

                -- present word zero, wait for the controller, pulse the strobe
                -- with the row of this burst; the warm up burst goes to row 1
                when FS_SDR_WW =>
                    sdr_own  <= '1';
                    sdr_wr_n <= '1';
                    sdr_widx <= 0;
                    sdr_data <= x"0000" & fft_result_buf(buf_idx(sdr_burst, 0));
                    if sdr_busy_n_i = '1' then
                        sdr_wr_n <= '0';
                        if sdr_warm = '1' then
                            sdr_addr <= "10"
                                      & std_logic_vector(to_unsigned(1, 11))
                                      & "00000101";
                        else
                            sdr_addr <= "10"
                                      & std_logic_vector(to_unsigned(2 + sdr_burst, 11))
                                      & "00000101";
                        end if;
                        sdr_timeout <= 0;
                    end if;

                -- stream one word per cycle for the whole burst
                when FS_SDR_W =>
                    sdr_own  <= '1';
                    sdr_wr_n <= '1';
                    sdr_widx <= sdr_widx + 1;
                    sdr_data <= x"0000"
                              & fft_result_buf(buf_idx(sdr_burst, sdr_widx));
                    sdr_timeout <= sdr_timeout + 1;
                    if sdr_timeout = 28 then
                        sdr_timeout <= 0;
                        if sdr_warm = '1' then
                            sdr_warm  <= '0';
                            sdr_burst <= 0;
                        elsif sdr_burst /= SDR_NBURST - 1 then
                            sdr_burst <= sdr_burst + 1;
                        end if;
                    end if;

                when FS_IRQ =>
                    -- release the write port, the fetch side reads from here on
                    sdr_own      <= '0';
                    sdr_wr_n     <= '1';
                    sdr_done     <= '1';
                    irq_o        <= '1';
                    ser_word_cnt <= (others => '0');
                    ser_bit_cnt  <= (others => '0');
                    ser_sreg     <= fft_result_buf(0);

                -- shift the whole frame out on the debug pin, msb first
                when FS_SERIAL =>
                    fft_ser_o <= ser_sreg(15);
                    if ser_bit_cnt = 15 then
                        ser_bit_cnt <= (others => '0');
                        if ser_word_cnt = 511 then
                            sdr_done <= '0';
                        else
                            ser_word_cnt <= ser_word_cnt + 1;
                            ser_sreg     <= fft_result_buf(to_integer(ser_word_cnt + 1));
                        end if;
                    else
                        ser_sreg    <= ser_sreg(14 downto 0) & '0';
                        ser_bit_cnt <= ser_bit_cnt + 1;
                    end if;

            end case;
        end if;
    end process;

end behavioral;
