library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--
-- Register map (WB slave, byte-addressed):
--   0x01 WR: start  -- avvia acquisizione continua SPI
--   0x02 WR: stop   -- ferma acquisizione
--   0x03 WR: base   -- indirizzo SDRAM output FFT (dat[20:0] = word address 21-bit)
--
-- Architettura a DUE macchine a stati indipendenti (due processi VHDL):
--
--   dma_proc  (DMA FSM):
--     SPI → spi_raw_buf (ping-pong 1024×16, Gowin 16K BSRAM)
--     Non tocca mai l'SDRAM, non conosce l'FFT.
--     Ogni 512 campioni pulsa fft_trigger e imposta fft_win_base.
--
--   fft_proc  (FFT FSM):
--     Legge spi_raw_buf[fft_win_base..+511] → alimenta FFT core
--     Cattura xk_re in fft_result_buf (512×16, Gowin 8K BSRAM)
--     Drena fft_result_buf su SDRAM @ base_address..+511
--     Manda IRQ al termine.
--
--   Bus WB condiviso:  DMA ha priorità assoluta.
--     Mux combinatorio: quando dma_cyc='1' il bus è del DMA; altrimenti del FFT.
--     In FS_DRAIN, se DMA prende il bus, l'ack non arriva al FFT → stallo automatico.
--     FFT non può mai essere interrotto durante la lettura BSRAM (FS_FEED1/2)
--     o la scrittura dei risultati (FS_COLLECT): nessun accesso WB in queste fasi.
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

    -- ── FFT core ──────────────────────────────────────────────────────────────
    signal xn_re_s    : std_logic_vector(15 downto 0) := (others => '0');
    signal xk_re_s    : std_logic_vector(15 downto 0);
    signal xk_im_s    : std_logic_vector(15 downto 0);
    signal idx_s      : std_logic_vector(8 downto 0);
    signal fft_start_s : std_logic := '0';
    signal fft_sod_s   : std_logic;
    signal fft_ipd_s   : std_logic;
    signal fft_eod_s   : std_logic;
    signal fft_busy_s  : std_logic;
    signal fft_soud_s  : std_logic;
    signal fft_opd_s   : std_logic;
    signal fft_eoud_s  : std_logic;

    -- ── Ping-pong input BRAM: 1024 campioni SPI, 16-bit (Gowin 16K BSRAM) ────
    type t_spi_raw_buf is array (0 to 1023) of std_logic_vector(15 downto 0);
    signal spi_raw_buf : t_spi_raw_buf := (others => (others => '0'));
    signal spi_wr_ptr  : unsigned(9 downto 0) := (others => '0');

    -- ── FFT result BRAM: 512 bin xk_re, 16-bit (Gowin 8K BSRAM) ─────────────
    type t_fft_result_buf is array (0 to 511) of std_logic_vector(15 downto 0);
    signal fft_result_buf : t_fft_result_buf := (others => (others => '0'));

    -- ── Handshake DMA → FFT ───────────────────────────────────────────────────
    signal fft_trigger  : std_logic := '0';            -- pulse 1 ciclo
    signal fft_win_base : unsigned(9 downto 0) := (others => '0');

    -- ── WB master bus — DMA side (priorità alta) ─────────────────────────────
    signal dma_cyc : std_logic := '0';
    signal dma_stb : std_logic := '0';
    signal dma_we  : std_logic := '0';
    signal dma_adr : std_logic_vector(31 downto 0) := (others => '0');
    signal dma_dat : std_logic_vector(31 downto 0) := (others => '0');

    -- ── WB master bus — FFT side (priorità bassa, solo durante FS_DRAIN) ─────
    signal fft_cyc : std_logic := '0';
    signal fft_stb : std_logic := '0';
    signal fft_we  : std_logic := '0';
    signal fft_adr : std_logic_vector(31 downto 0) := (others => '0');
    signal fft_dat : std_logic_vector(31 downto 0) := (others => '0');

    -- ── DMA FSM ───────────────────────────────────────────────────────────────
    type dma_state_t is (DS_IDLE, DS_OPEN, DS_POLL, DS_READ, DS_CLRDY, DS_STORE);
    signal dma_state : dma_state_t := DS_IDLE;
    signal dma_rdata : std_logic_vector(31 downto 0) := (others => '0');

    -- ── FFT FSM ───────────────────────────────────────────────────────────────
    type fft_state_t is (FS_IDLE, FS_FEED1, FS_COMPUTE, FS_COLLECT, FS_DRAIN, FS_IRQ);
    signal fft_state  : fft_state_t := FS_IDLE;
    signal fft_rd_idx : unsigned(8 downto 0) := (others => '0');
    signal drain_cnt  : unsigned(8 downto 0) := (others => '0');

    -- ── Registri CPU ─────────────────────────────────────────────────────────
    signal start_r      : std_logic := '0';
    signal base_address : unsigned(20 downto 0) := (others => '0');

    signal start_req : std_logic := '0';

begin

    -- ── WB master mux: DMA ha priorità assoluta ───────────────────────────────
    -- Quando dma_cyc='1' il bus è del DMA; altrimenti è del FFT.
    -- L'ack torna a entrambi, ma fft_proc avanza solo se dma_cyc='0' (vedi FS_DRAIN).
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
            rst   => rst_i
        );

    -- ── WB slave: registri di configurazione CPU ──────────────────────────────
    wb_slave: process(clk_i)
    begin
        if rising_edge(clk_i) then
            s_ack_o <= '0';
            s_dat_o <= (others => '0');
            if rst_i = '0' then
                start_r      <= '0';
                base_address <= (others => '0');
            elsif s_cyc_i = '1' and s_stb_i = '1' then
                s_ack_o <= '1';
                if s_we_i = '1' then
                    case s_adr_i(7 downto 0) is
                        when x"01" => start_r      <= '1';
                        when x"02" => start_r      <= '0';
                        when x"03" => base_address <= unsigned(s_dat_i(20 downto 0));
                        when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process;

    -- ── DMA FSM ───────────────────────────────────────────────────────────────
    -- Compito unico: leggere campioni SPI e scriverli in spi_raw_buf.
    -- Non conosce l'FFT, non accede mai all'SDRAM.
    -- Ogni 512 campioni: pulsa fft_trigger + imposta fft_win_base.
    dma_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            dma_cyc     <= '0';
            dma_stb     <= '0';
            dma_we      <= '0';
            fft_trigger <= '0';

            if rst_i = '0' then
                dma_state  <= DS_IDLE;
                spi_wr_ptr <= (others => '0');
            else
                case dma_state is

                    when DS_IDLE =>
                        spi_wr_ptr <= (others => '0');
                        if start_r = '1' then
                            dma_state <= DS_OPEN;
                        end if;

                    -- Abilita SPI master: write 0x40000001 ← 1
                    when DS_OPEN =>
                        dma_cyc <= '1';
                        dma_stb <= '1';
                        dma_we  <= '1';
                        dma_adr <= x"40000001";
                        dma_dat <= x"00000001";
                        if m_ack_i = '1' then
                            dma_state <= DS_POLL;
                        end if;

                    -- Attende DATA_READY dall'SPI master
                    when DS_POLL =>
                        if spi_data_ready_i = '1' then
                            dma_state <= DS_READ;
                        end if;

                    -- Legge dato SPI: read 0x40000000
                    when DS_READ =>
                        dma_cyc <= '1';
                        dma_stb <= '1';
                        dma_we  <= '0';
                        dma_adr <= x"40000000";
                        if m_ack_i = '1' then
                            dma_rdata <= m_dat_i;
                            dma_state <= DS_CLRDY;
                        end if;

                    -- Pulisce DATA_READY: write 0x40000003 ← 0 toglie il flag ack_o = 1
                    when DS_CLRDY =>
                        dma_cyc <= '1';
                        dma_stb <= '1';
                        dma_we  <= '1';
                        dma_adr <= x"40000003";
                        dma_dat <= (others => '0');
                        if m_ack_i = '1' then
                            dma_state <= DS_STORE;
                        end if;

                    -- Scrive campione in spi_raw_buf (1 ciclo, nessun WB)
                    -- Ogni 512 campioni: seleziona blocco completato e pulsa fft_trigger
                    when DS_STORE =>
                        spi_raw_buf(to_integer(spi_wr_ptr)) <= x"0" & dma_rdata(11 downto 0);
                        if spi_wr_ptr(8 downto 0) = "111111111" then
                            if spi_wr_ptr(9) = '0' then
                                fft_win_base <= (others => '0');       -- blocco A: 0-511
                            else
                                fft_win_base <= to_unsigned(512, 10);  -- blocco B: 512-1023
                            end if;
                            fft_trigger <= '1';
                        end if;
                        spi_wr_ptr <= spi_wr_ptr + 1;
                        dma_state  <= DS_POLL;

                end case;
            end if;
        end if;
    end process;

    -- ── FFT FSM ───────────────────────────────────────────────────────────────
    -- Compito: aspetta fft_trigger → legge BSRAM → alimenta FFT → cattura risultati
    --          → drena su SDRAM → IRQ.
    -- Non interagisce mai con l'SPI master.
    -- Le fasi FS_FEED1/2 e FS_COLLECT non usano il WB: impossibile interferire
    -- con il DMA durante la lettura/scrittura BSRAM.
    -- In FS_DRAIN: se DMA prende il bus (dma_cyc='1'), il mux devia il bus al DMA;
    --              l'ack non arriva al FFT → drain_cnt non avanza → stallo automatico.
    fft_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            fft_cyc     <= '0';
            fft_stb     <= '0';
            fft_we      <= '0';
            irq_o       <= '0';
            fft_start_s <= start_req; 
            start_req   <= '0';

            if rst_i = '0' then
                fft_state   <= FS_IDLE;
                fft_rd_idx  <= (others => '0');
                drain_cnt   <= (others => '0');
            else
                case fft_state is

                    when FS_IDLE =>
                        fft_rd_idx <= (others => '0');
                        if fft_trigger = '1' then
                            fft_state <= FS_FEED1;
                            start_req <= '1';
                            xn_re_s     <= spi_raw_buf(to_integer(fft_win_base + resize(fft_rd_idx, 10)));
                            fft_rd_idx <= fft_rd_idx + 1;
                        end if;

                    -- Presenta xn_re e pulsa start='1' per esattamente 1 ciclo di clock
                    when FS_FEED1 =>
                        start_req <= '1';
                        xn_re_s     <= spi_raw_buf(to_integer(fft_win_base + resize(fft_rd_idx, 10)));
                        fft_rd_idx <= fft_rd_idx + 1;
                            if fft_eod_s = '1' then
                                fft_state <= FS_COMPUTE;
                            elsif fft_ipd_s = '1' and fft_eod_s = '0' then
                                fft_state <= FS_FEED1;
                            end if;

                    -- Attende fine calcolo FFT (busy='0')
                    when FS_COMPUTE =>
                        fft_state <= FS_COLLECT;

                    -- Cattura i 512 bin FFT in fft_result_buf (nessun WB)
                    -- Impossibile essere interrotti: nessun accesso WB in questo stato
                    when FS_COLLECT =>
                        if fft_opd_s = '1' then
                            fft_result_buf(to_integer(unsigned(idx_s))) <= xk_re_s;
                        end if;
                        if fft_eoud_s = '1' then
                            drain_cnt <= (others => '0');
                            fft_state <= FS_DRAIN;
                        end if;

                    -- Drena fft_result_buf su SDRAM @ base_address..base_address+511
                    -- DMA ha priorità: se dma_cyc='1' il mux toglie il bus al FFT,
                    -- l'ack non viene mai ricevuto → ciclo WB si ripete il clock dopo.
                    when FS_DRAIN =>
                        fft_adr <= "0001" & "0000000" &
                                   std_logic_vector(base_address + resize(drain_cnt, 21));
                        fft_dat <= x"0000" & fft_result_buf(to_integer(drain_cnt));
                        if dma_cyc = '0' then
                            fft_cyc <= '1';
                            fft_stb <= '1';
                            fft_we  <= '1';
                            if m_ack_i = '1' then
                                -- Abbassa CYC prima di cambiare stato (last-assignment wins)
                                fft_cyc <= '0';
                                fft_stb <= '0';
                                if drain_cnt = 511 then
                                    fft_state <= FS_IRQ;
                                else
                                    drain_cnt <= drain_cnt + 1;
                                end if;
                            end if;
                        end if;

                    when FS_IRQ =>
                        irq_o     <= '1';
                        fft_state <= FS_IDLE;

                end case;
            end if;
        end if;
    end process;

end behavioral;
