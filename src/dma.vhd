library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--
-- Register map (WB slave, byte-addressed, offset from 0x30000000):
--   0x01  WR: start   -- avvia acquisizione continua SPI->SDRAM
--   0x02  WR: stop    -- ferma acquisizione
--   0x03  WR: base    -- imposta indirizzo base SDRAM (dat[20:0] = word address 21-bit)
--
-- SPI: MCP3201 12-bit ADC, 16 periodi SCK x 36 clk = 576 clk/campione (~46.875 kHz)
-- Il DMA scrive 1 parola da 16 bit per campione (bit[11:0] = dato ADC, bit[15:12] = 0).
-- Ogni 512 parole scatta la FFT a 512 punti sul blocco appena completato.
-- Risultati FFT (xk_re) scritti in SDRAM a partire da word address 0x1300.
-- IRQ (bit 20) generato alla fine della FFT.
-- Ping-pong: blocco A = base..base+511, blocco B = base+512..base+1023.
-- Dopo il blocco B l'indirizzo torna a base automaticamente.
-- Durante la FFT (tutti gli stati FFT_*) se arriva un nuovo campione SPI
-- il DMA lo scrive subito in SDRAM con priorita' assoluta.
--

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

        irq_o    : out std_logic
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

    signal xn_re_s  : std_logic_vector(15 downto 0) := (others => '0');
    signal xk_re_s  : std_logic_vector(15 downto 0);
    signal xk_im_s  : std_logic_vector(15 downto 0);
    signal idx_s    : std_logic_vector(8 downto 0);
    signal fft_start_s, fft_sod_s, fft_ipd_s, fft_eod_s : std_logic;
    signal fft_busy_s, fft_soud_s, fft_opd_s, fft_eoud_s : std_logic;

    constant FFT_OUT_BASE : unsigned(20 downto 0) := to_unsigned(16#1300#, 21);

    type state_type is (
        S_IDLE, S_OPEN, S_CLOSE,
        S_READ_1, S_R_DEV, S_WRITE_1, S_IRQ,
        S_FFT_READ1, S_FFT_READ2,
        S_FFT_BUSY, S_FFT_BUSY_RD, S_FFT_BUSY_CLRDY, S_FFT_BUSY_WR,
        S_FFT_SPI_RD, S_FFT_SPI_CLRDY, S_FFT_SPI_WR,
        S_FFT_WRITE, S_FFT_WRITE_WAIT,
        S_FFT_END
    );

    signal curr_state      : state_type;
    signal data            : std_logic_vector(31 downto 0) := (others => '0');
    signal address_local   : unsigned(20 downto 0) := (others => '0');
    signal base_address    : unsigned(20 downto 0) := (others => '0');
    signal start           : std_logic := '0';

    signal fft_sdram_base  : unsigned(20 downto 0) := (others => '0');
    signal fft_rd_idx      : unsigned(8 downto 0)  := (others => '0');
    signal fft_wr_cnt      : unsigned(8 downto 0)  := (others => '0');
    signal fft_spi_return  : state_type;
    signal fft_out_waddr   : unsigned(20 downto 0) := (others => '0');
    signal fft_out_data    : std_logic_vector(15 downto 0) := (others => '0');
    signal fft_eoud_seen   : std_logic := '0';

begin

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
            rst   => rst_i
        );

    seq_clk: process(clk_i)
    begin
        if rising_edge(clk_i) then
            s_ack_o <= '0';
            s_dat_o <= (others => '0');
            m_cyc_o <= '0';
            m_stb_o <= '0';
            m_we_o  <= '0';
            irq_o   <= '0';

            if rst_i = '0' then
                curr_state     <= S_IDLE;
                m_adr_o        <= (others => '0');
                m_dat_o        <= (others => '0');
                start          <= '0';
                base_address   <= (others => '0');
                address_local  <= (others => '0');
                data           <= (others => '0');
                fft_start_s    <= '0';
                xn_re_s        <= (others => '0');
                fft_rd_idx     <= (others => '0');
                fft_wr_cnt     <= (others => '0');
                fft_sdram_base <= (others => '0');
                fft_out_waddr  <= (others => '0');
                fft_out_data   <= (others => '0');
                fft_eoud_seen  <= '0';
            else
                if s_cyc_i = '1' and s_stb_i = '1' then
                    s_ack_o <= '1';
                    if s_we_i = '1' then
                        if s_adr_i(7 downto 0) = x"03" then
                            base_address <= unsigned(s_dat_i(20 downto 0));
                        elsif s_adr_i(7 downto 0) = x"01" then
                            start <= '1';
                        elsif s_adr_i(7 downto 0) = x"02" then
                            start <= '0';
                        end if;
                    end if;
                end if;

                case curr_state is

                    when S_IDLE =>
                        address_local <= base_address;
                        fft_start_s   <= '0';
                        if start = '1' then
                            curr_state <= S_OPEN;
                        end if;

                    when S_OPEN =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '1';
                        m_adr_o <= x"40000001";
                        m_dat_o <= x"00000001";
                        if m_ack_i = '1' then
                            m_cyc_o    <= '0';
                            m_stb_o    <= '0';
                            curr_state <= S_READ_1;
                        end if;

                    -- Read 12-bit sample from SPI (WB stalls until data_ready)
                    when S_READ_1 =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '0';
                        m_adr_o <= x"40000000";
                        if m_ack_i = '1' then
                            data       <= m_dat_i;
                            m_cyc_o    <= '0';
                            m_stb_o    <= '0';
                            curr_state <= S_R_DEV;
                        end if;

                    when S_R_DEV =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '1';
                        m_adr_o <= x"40000003";
                        m_dat_o <= (others => '0');
                        if m_ack_i = '1' then
                            m_cyc_o    <= '0';
                            m_stb_o    <= '0';
                            curr_state <= S_WRITE_1;
                        end if;

                    -- One write per sample: 12-bit ADC value in bits[11:0]
                    when S_WRITE_1 =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '1';
                        m_adr_o <= "0001" & "0000000" & std_logic_vector(address_local);
                        m_dat_o <= x"00000" & data(11 downto 0);
                        if m_ack_i = '1' then
                            m_cyc_o <= '0';
                            m_stb_o <= '0';
                            address_local <= address_local + 1;
                            if to_integer(address_local + 1 - base_address) mod 512 = 0 then
                                -- 512-sample window just completed: trigger FFT
                                fft_sdram_base <= address_local - 510;
                                fft_rd_idx     <= (others => '0');
                                fft_wr_cnt     <= (others => '0');
                                fft_eoud_seen  <= '0';
                                fft_start_s    <= '1';
                                -- Wrap address at 1024 (ping-pong boundary)
                                if to_integer(address_local + 1 - base_address) = 1024 then
                                    address_local <= base_address;
                                end if;
                                curr_state <= S_FFT_READ1;
                            else
                                curr_state <= S_READ_1;
                            end if;
                        end if;

                    when S_FFT_READ1 =>
                        if spi_data_ready_i = '1' then
                            fft_spi_return <= S_FFT_READ1;
                            curr_state     <= S_FFT_SPI_RD;
                        else
                            m_cyc_o <= '1';
                            m_stb_o <= '1';
                            m_we_o  <= '0';
                            m_adr_o <= "0001" & "0000000" &
                                       std_logic_vector(fft_sdram_base + fft_rd_idx);
                            if m_ack_i = '1' then
                                xn_re_s    <= x"0" & m_dat_i(11 downto 0);
                                m_cyc_o    <= '0';
                                m_stb_o    <= '0';
                                curr_state <= S_FFT_READ2;
                            end if;
                        end if;

                    --  wait for FFT to accept (ipd pulse)
                    when S_FFT_READ2 =>
                        if spi_data_ready_i = '1' then
                            fft_spi_return <= S_FFT_READ2;
                            curr_state     <= S_FFT_SPI_RD;
                        elsif fft_ipd_s = '1' then
                            fft_rd_idx <= fft_rd_idx + 1;
                            if fft_eod_s = '1' then
                                fft_start_s <= '0';
                                curr_state  <= S_FFT_BUSY;
                            else
                                curr_state <= S_FFT_READ1;
                            end if;
                        end if;

                    when S_FFT_BUSY =>
                        fft_start_s <= '0';
                        if spi_data_ready_i = '1' then
                            curr_state <= S_FFT_BUSY_RD;
                            --Dopo che è busy quindi il BUSY_RD legge i falori dal FFT per poi scriverli
                        elsif fft_busy_s = '0' then
                            curr_state <= S_FFT_WRITE;
                        end if;

                    when S_FFT_BUSY_RD =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '0';
                        m_adr_o <= x"40000000";
                        if m_ack_i = '1' then
                            data       <= m_dat_i;
                            m_cyc_o    <= '0';
                            m_stb_o    <= '0';
                            curr_state <= S_FFT_BUSY_CLRDY;
                        end if;

                    when S_FFT_BUSY_CLRDY =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '1';
                        m_adr_o <= x"40000003";
                        m_dat_o <= (others => '0');
                        if m_ack_i = '1' then
                            m_cyc_o    <= '0';
                            m_stb_o    <= '0';
                            curr_state <= S_FFT_BUSY_WR;
                        end if;

                    when S_FFT_BUSY_WR =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '1';
                        m_adr_o <= "0001" & "0000000" & std_logic_vector(address_local);
                        m_dat_o <= x"00000" & data(11 downto 0);
                        if m_ack_i = '1' then
                            address_local <= address_local + 1;
                            m_cyc_o       <= '0';
                            m_stb_o       <= '0';
                            curr_state    <= S_FFT_BUSY;
                        end if;

                    when S_FFT_SPI_RD =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '0';
                        m_adr_o <= x"40000000";
                        if m_ack_i = '1' then
                            data       <= m_dat_i;
                            m_cyc_o    <= '0';
                            m_stb_o    <= '0';
                            curr_state <= S_FFT_SPI_CLRDY;
                        end if;

                    when S_FFT_SPI_CLRDY =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '1';
                        m_adr_o <= x"40000003";
                        m_dat_o <= (others => '0');
                        if m_ack_i = '1' then
                            m_cyc_o    <= '0';
                            m_stb_o    <= '0';
                            curr_state <= S_FFT_SPI_WR;
                        end if;

                    when S_FFT_SPI_WR =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '1';
                        m_adr_o <= "0001" & "0000000" & std_logic_vector(address_local);
                        m_dat_o <= x"00000" & data(11 downto 0);
                        if m_ack_i = '1' then
                            address_local <= address_local + 1;
                            m_cyc_o       <= '0';
                            m_stb_o       <= '0';
                            curr_state    <= fft_spi_return;
                        end if;

                    -- --------------------------------------------------------
                    -- FFT OUTPUT PHASE: write xk_re bins to SDRAM @ 0x1300+idx
                    -- --------------------------------------------------------
                    when S_FFT_WRITE =>
                        if fft_eoud_s = '1' then
                            fft_eoud_seen <= '1';
                        end if;
                        if spi_data_ready_i = '1' then
                            fft_spi_return <= S_FFT_WRITE;
                            curr_state     <= S_FFT_SPI_RD;
                        elsif fft_opd_s = '1' then
                            fft_out_waddr <= FFT_OUT_BASE + resize(unsigned(idx_s), 21);
                            fft_out_data  <= xk_re_s;
                            curr_state    <= S_FFT_WRITE_WAIT;
                        elsif fft_eoud_seen = '1' then
                            curr_state <= S_FFT_END;
                        end if;

                    when S_FFT_WRITE_WAIT =>
                        if fft_eoud_s = '1' then
                            fft_eoud_seen <= '1';
                        end if;
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '1';
                        m_adr_o <= "0001" & "0000000" & std_logic_vector(fft_out_waddr);
                        m_dat_o <= x"0000" & fft_out_data;
                        if m_ack_i = '1' then
                            m_cyc_o    <= '0';
                            m_stb_o    <= '0';
                            fft_wr_cnt <= fft_wr_cnt + 1;
                            if fft_eoud_seen = '1' or
                               to_integer(fft_wr_cnt) = 511 then
                                curr_state <= S_FFT_END;
                            else
                                curr_state <= S_FFT_WRITE;
                            end if;
                        end if;

                    when S_FFT_END =>
                        curr_state <= S_IRQ;

                    -- --------------------------------------------------------
                    -- IRQ: notifica CPU, riprende campionamento
                    -- --------------------------------------------------------
                    when S_IRQ =>
                        irq_o      <= '1';
                        curr_state <= S_READ_1;

                    when S_CLOSE =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '1';
                        m_adr_o <= x"40000002";
                        m_dat_o <= x"00000000";
                        if m_ack_i = '1' then
                            m_cyc_o    <= '0';
                            m_stb_o    <= '0';
                            curr_state <= S_IDLE;
                        end if;

                    when others =>
                        curr_state <= S_IDLE;

                end case;
            end if;
        end if;
    end process;

end behavioral;
