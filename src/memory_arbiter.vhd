library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Dual-port Wishbone→SDRAM bridge.
-- M1 (DMA write) ha priorità su M0 (AUSP read).
-- Usa SDRAM_Controller_HS_Top (SDRC_HS IP) a 108 MHz.
--
-- Protocollo SDRC_HS (da analisi netlist .vo + SDRAM_Controller_HS_Top.v):
--   I_sdrc_cmd[2:0] = {RAS_n, CAS_n, WE_n} (commento esplicito nel sorgente IP).
--   Il controller gestisce ACTIVATE (tRCD) e precharge internamente.
--   L'utente emette solo WRITE ("100") o READ ("101").
--
--   IMPORTANTE: O_sdrc_cmd_ack ha INIT='0' → resta '0' fino al primo comando.
--   NON controllare cmd_ack in IDLE prima del primo comando (deadlock).
--   cmd_ack scatta al ciclo ~4 (Count_cmd_delay=4) ANCHE per WRITE (non solo READ).
--
--   Sequenza WRITE:
--     1. Aspettare init_done='1'.
--     2. Emettere WRITE (cmd_en='1' per 1 ciclo) quando stb='1'.
--     3. Aspettare SOLO il timer (128 cicli) — NON cmd_ack (troppo presto per write).
--
--   Sequenza READ:
--     1. Emettere READ (cmd_en='1' per 1 ciclo).
--     2. Aspettare cmd_ack='1', poi attendere CL=3 cicli → dato valido (rd_latch_dly=4).
--
-- FSM: IDLE → M1_WR_WAIT → M1_ACK → IDLE
--      IDLE → M0_RD_WAIT → M0_ACK → IDLE
entity memory_arbiter is
    port (
        wb_clk_i    : in  std_logic;
        wb_rst_i    : in  std_logic;
        pll_lock_i  : in  std_logic;
        m0_cyc_i    : in  std_logic;
        m0_stb_i    : in  std_logic;
        m0_we_i     : in  std_logic;
        m0_adr_i    : in  std_logic_vector(31 downto 0);
        m0_dat_i    : in  std_logic_vector(31 downto 0);
        m0_dat_o    : out std_logic_vector(31 downto 0);
        m0_ack_o    : out std_logic;
        m1_cyc_i    : in  std_logic;
        m1_stb_i    : in  std_logic;
        m1_we_i     : in  std_logic;
        m1_adr_i    : in  std_logic_vector(31 downto 0);
        m1_dat_i    : in  std_logic_vector(31 downto 0);
        m1_dat_o    : out std_logic_vector(31 downto 0);
        m1_ack_o    : out std_logic;
        init_done_o   : out std_logic;
        wr_ack_seen_o : out std_logic;
        rd_ack_seen_o : out std_logic;
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
end memory_arbiter;

architecture structural of memory_arbiter is

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

    signal sdrc_cmd_ack   : std_logic;
    signal sdrc_data_out  : std_logic_vector(31 downto 0);
    signal sdrc_init_done : std_logic;

    signal sdrc_cmd_en : std_logic := '0';
    signal sdrc_cmd    : std_logic_vector(2 downto 0) := "111";  -- NOP default
    signal sdrc_addr_r : std_logic_vector(20 downto 0) := (others => '0');
    signal sdrc_data_r : std_logic_vector(31 downto 0) := (others => '0');

    type arb_t is (
        IDLE,
        M0_RD_WAIT, M0_ACK,
        M1_WR_WAIT, M1_ACK
    );
    signal arb_state : arb_t := IDLE;
    signal state_ack : std_logic := '0';

    -- Timer WRITE: cmd_ack scatta a Count_cmd_delay=4 (ACTIVATE phase) anche per WRITE.
    -- Se usassimo cmd_ack per uscire da M1_WR_WAIT, usciremmo al ciclo ~4 prima che
    -- WRITE+tWR+PRECHARGE+tRP completino (~12 cicli). Solo timer a 128 cicli.
    signal wr_timer : unsigned(6 downto 0) := (others => '0');

    -- Timer READ: cmd_ack NON scatta per READ (confermato: pin 86 OFF nel test).
    -- Usiamo timer fisso: ACTIVATE=4 + tRCD interno + CL=3 = ~8 cicli per dato valido.
    -- Latch a rd_timer=12 (ciclo 13 da cmd_en): ampio margine, sdrc_data_out mantiene
    -- il dato catturato fino alla transazione successiva anche dopo precharge.
    -- Budget: 512 read × 20 cicli = 10240 cicli@108MHz = 95µs << 10.9ms frame.
    signal rd_timer : unsigned(4 downto 0) := (others => '0');

    signal m0_rd_data_lat : std_logic_vector(31 downto 0) := (others => '0');

    -- wr_ack_seen: cmd_ack visto durante M1_WR_WAIT (WRITE accettato da SDRC_HS).
    -- rd_ack_seen: '1' la prima volta che l'arbiter entra in M0_RD_WAIT (READ richiesta).
    --   Semantica cambiata dopo test: cmd_ack per READ non arriva mai → usiamo timer.
    --   Ora indica se AUSP riesce ad ottenere il bus (pin 86 ON = M0_RD_WAIT raggiunto).
    signal wr_ack_seen : std_logic := '0';
    signal rd_ack_seen : std_logic := '0';

begin

    init_done_o   <= sdrc_init_done;
    wr_ack_seen_o <= wr_ack_seen;
    rd_ack_seen_o <= rd_ack_seen;
    m0_dat_o      <= m0_rd_data_lat;
    m1_dat_o      <= sdrc_data_out;

    m0_ack_o <= state_ack when arb_state = M0_ACK else '0';
    m1_ack_o <= state_ack when arb_state = M1_ACK else '0';

    -- =========================================================
    -- Arbiter FSM a 108 MHz
    --
    -- NOTA CRITICA: cmd_ack ha INIT='0'. Non controllarlo prima del
    -- primo comando — non andrà mai a '1' da solo dopo l'init.
    -- Lo controlliamo solo in RD_WAIT (dopo aver emesso il comando READ).
    --
    -- Per WRITE: NON usare cmd_ack (scatta ~ciclo 4, troppo presto).
    --   Usare solo timer=128 cicli: garantisce WRITE+tWR+PRECHARGE+tRP completati.
    -- Per READ: cmd_ack scatta ~ciclo 4, poi aspettare CL=3 cicli per dato valido.
    -- =========================================================
    process(wb_clk_i)
    begin
        if rising_edge(wb_clk_i) then
            sdrc_cmd_en <= '0';
            sdrc_cmd    <= "111";  -- NOP
            state_ack   <= '0';

            case arb_state is

                -- ── IDLE ─────────────────────────────────────────────────
                -- Attende init_done='1'. NON controlla cmd_ack (è '0' di default).
                -- Priorità M1 (DMA write) > M0 (AUSP read).
                when IDLE =>
                    wr_timer <= (others => '0');
                    rd_timer <= (others => '0');
                    if sdrc_init_done = '1' then
                        if m1_cyc_i = '1' and m1_stb_i = '1' then
                            sdrc_addr_r <= m1_adr_i(20 downto 0);
                            sdrc_data_r <= m1_dat_i;
                            sdrc_cmd_en <= '1';
                            sdrc_cmd    <= "100";  -- WRITE
                            arb_state   <= M1_WR_WAIT;
                        elsif m0_cyc_i = '1' and m0_stb_i = '1' then
                            rd_ack_seen <= '1';  -- latch: M0_RD_WAIT raggiunto (pin 86)
                            sdrc_addr_r <= m0_adr_i(20 downto 0);
                            sdrc_cmd_en <= '1';
                            sdrc_cmd    <= "101";  -- READ
                            arb_state   <= M0_RD_WAIT;
                        end if;
                    end if;

                -- ── M1: attesa completamento WRITE ───────────────────────
                -- Solo timer a 128 cicli @ 108 MHz ≈ 1.2 µs.
                -- NON usare cmd_ack: scatta al ciclo ~4 (ACTIVATE phase) anche per WRITE,
                -- prima che WRITE+tWR+PRECHARGE+tRP completino (~12 cicli).
                -- Emettere il comando successivo al ciclo ~8 causerebbe cmd_en ignorato.
                -- wr_ack_seen: latch se cmd_ack arriva (diagnosi: SDRC_HS risponde a WRITE?)
                when M1_WR_WAIT =>
                    wr_timer <= wr_timer + 1;
                    if sdrc_cmd_ack = '1' then
                        wr_ack_seen <= '1';
                    end if;
                    if wr_timer = 127 then
                        state_ack <= '1';
                        arb_state <= M1_ACK;
                        wr_timer  <= (others => '0');
                    elsif m1_cyc_i = '0' or m1_stb_i = '0' then
                        arb_state <= IDLE;
                        wr_timer  <= (others => '0');
                    end if;

                -- ── M1: hold ack finché DMA deasserta stb ────────────────
                when M1_ACK =>
                    state_ack <= '1';
                    if m1_cyc_i = '0' or m1_stb_i = '0' then
                        arb_state <= IDLE;
                        state_ack <= '0';
                    end if;

                -- ── M0: attesa completamento READ ────────────────────────
                -- cmd_ack NON scatta per READ (confermato empiricamente: pin 86 OFF).
                -- Timer fisso: ACTIVATE(4)+CL(3)+margine → latch a rd_timer=12 (ciclo 13
                -- da cmd_en). sdrc_data_out mantiene il dato catturato dopo il burst.
                -- Non dipende da cmd_ack: timer parte sempre, ack sempre garantito.
                when M0_RD_WAIT =>
                    rd_timer <= rd_timer + 1;
                    if rd_timer = 12 then
                        m0_rd_data_lat <= sdrc_data_out;
                        state_ack      <= '1';
                        arb_state      <= M0_ACK;
                        rd_timer       <= (others => '0');
                    elsif m0_cyc_i = '0' or m0_stb_i = '0' then
                        arb_state <= IDLE;
                        rd_timer  <= (others => '0');
                    end if;

                -- ── M0: hold ack finché AUSP deasserta stb ───────────────
                when M0_ACK =>
                    state_ack <= '1';
                    if m0_cyc_i = '0' or m0_stb_i = '0' then
                        arb_state <= IDLE;
                        state_ack <= '0';
                    end if;

            end case;
        end if;
    end process;

    u_sdram: SDRAM_Controller_HS_Top
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
        I_sdrc_rst_n          => pll_lock_i,
        I_sdrc_clk            => wb_clk_i,
        I_sdram_clk           => wb_clk_i,
        I_sdrc_cmd_en         => sdrc_cmd_en,
        I_sdrc_cmd            => sdrc_cmd,
        I_sdrc_precharge_ctrl => '1',
        I_sdram_power_down    => '0',
        I_sdram_selfrefresh   => '0',
        I_sdrc_addr           => sdrc_addr_r,
        I_sdrc_dqm            => "0000",
        I_sdrc_data           => sdrc_data_r,
        I_sdrc_data_len       => x"00",  -- length-1: x"00"=1 word (x"01" era errato=2 word)
        O_sdrc_data           => sdrc_data_out,
        O_sdrc_init_done      => sdrc_init_done,
        O_sdrc_cmd_ack        => sdrc_cmd_ack
    );

end structural;
