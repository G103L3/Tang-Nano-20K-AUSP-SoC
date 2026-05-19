library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Dual-port Wishbone→SDRAM bridge.
-- M1 (DMA write) ha priorità su M0 (AUSP read).
-- Usa SDRAM_Controller_HS_Top (SDRC_HS IP) a 108 MHz.
--
-- Protocollo SDRC_HS:
--   I_sdrc_cmd[2:0] = {RAS_n, CAS_n, WE_n}
--   cmd_en DEVE essere tenuto HIGH fino a cmd_ack='1' (non pulsato 1 solo ciclo).
--   cmd_ack scatta al ciclo ~4 sia per WRITE che per READ.
--
--   Sequenza WRITE: stati M1_CMD (tieni cmd_en='1') → M1_WR_WAIT (conta 14 cicli
--     da cmd_ack per completare WRITE+tWR+PRECHARGE+tRP) → M1_ACK
--
--   Sequenza READ: stati M0_CMD (tieni cmd_en='1') → M0_RD_WAIT (conta 5 cicli
--     da cmd_ack, CL=3+margine, dato valido su O_sdrc_data) → M0_ACK
--
-- FSM: IDLE → M1_CMD → M1_WR_WAIT → M1_ACK → IDLE
--      IDLE → M0_CMD → M0_RD_WAIT → M0_ACK → IDLE
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
    signal sdrc_cmd    : std_logic_vector(2 downto 0) := "111";
    signal sdrc_addr_r : std_logic_vector(20 downto 0) := (others => '0');
    signal sdrc_data_r : std_logic_vector(31 downto 0) := (others => '0');

    type arb_t is (
        IDLE,
        M1_CMD, M1_WR_WAIT, M1_FLUSH_CMD, M1_FLUSH_WAIT, M1_ACK,
        M0_CMD, M0_RD_WAIT, M0_ACK
    );
    signal arb_state : arb_t := IDLE;
    signal state_ack : std_logic := '0';

    -- wr_timer: conta cicli in M1_CMD (timeout), M1_WR_WAIT (26 cicli), M1_FLUSH_CMD (timeout)
    -- rd_timer: conta cicli in M0_RD_WAIT e M1_FLUSH_WAIT (CL latency)
    signal wr_timer : unsigned(4 downto 0) := (others => '0');
    signal rd_timer : unsigned(2 downto 0) := (others => '0');

    signal m0_rd_data_lat : std_logic_vector(31 downto 0) := (others => '0');

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

    process(wb_clk_i)
    begin
        if rising_edge(wb_clk_i) then
            sdrc_cmd_en <= '0';
            sdrc_cmd    <= "111";  -- NOP default
            state_ack   <= '0';

            case arb_state is

                -- ── IDLE ─────────────────────────────────────────────────────────
                -- Priorità M1 (DMA write) > M0 (AUSP read).
                when IDLE =>
                    wr_timer <= (others => '0');
                    rd_timer <= (others => '0');
                    if sdrc_init_done = '1' then
                        if m1_cyc_i = '1' and m1_stb_i = '1' then
                            sdrc_addr_r <= m1_adr_i(20 downto 0);
                            sdrc_data_r <= m1_dat_i;
                            arb_state   <= M1_CMD;
                        elsif m0_cyc_i = '1' and m0_stb_i = '1' then
                            sdrc_addr_r <= m0_adr_i(20 downto 0);
                            arb_state   <= M0_CMD;
                        end if;
                    end if;

                -- ── M1_CMD: tiene cmd_en='1' finché cmd_ack o timeout ───────────
                -- Timeout a 16 cicli: se il SDRC_HS è in refresh al momento del cmd_en
                -- può non rispondere con cmd_ack. Un ciclo NOP (→IDLE→M1_CMD) sblocca
                -- la state machine interna del controller.
                when M1_CMD =>
                    sdrc_cmd_en <= '1';
                    sdrc_cmd    <= "100";  -- WRITE
                    wr_timer    <= wr_timer + 1;
                    if sdrc_cmd_ack = '1' then
                        wr_ack_seen <= '1';
                        wr_timer    <= (others => '0');  -- reset: M1_WR_WAIT parte da 0
                        arb_state   <= M1_WR_WAIT;
                    elsif wr_timer = 15 then              -- timeout 16 cicli: riprova
                        wr_timer  <= (others => '0');
                        arb_state <= IDLE;               -- 1 ciclo NOP poi torna in M1_CMD
                    elsif m1_cyc_i = '0' or m1_stb_i = '0' then
                        wr_timer  <= (others => '0');
                        arb_state <= IDLE;
                    end if;

                -- ── M1_WR_WAIT: aspetta completamento WRITE ──────────────────────
                -- 26 cicli da cmd_ack (≈241 ns @108 MHz) poi flush READ.
                when M1_WR_WAIT =>
                    wr_timer <= wr_timer + 1;
                    if wr_timer = 25 then
                        wr_timer  <= (others => '0');
                        arb_state <= M1_FLUSH_CMD;
                    end if;

                -- ── M1_FLUSH_CMD: READ dallo stesso addr della WRITE ─────────────
                -- Forza ACTIVATE+READ+PRECHARGE (con precharge_ctrl='1') che chiude
                -- la riga SDRAM. Senza questo, il SDRC_HS tiene la riga aperta e
                -- le WRITE consecutive vanno tutte a col 0 della riga iniziale.
                -- Timeout a 16 cicli: se in refresh, salta il flush (non critico).
                when M1_FLUSH_CMD =>
                    sdrc_cmd_en <= '1';
                    sdrc_cmd    <= "101";  -- READ (flush)
                    wr_timer    <= wr_timer + 1;
                    if sdrc_cmd_ack = '1' then
                        rd_timer  <= (others => '0');
                        arb_state <= M1_FLUSH_WAIT;
                    elsif wr_timer = 15 then
                        arb_state <= M1_ACK;  -- timeout: skip flush
                    end if;

                -- ── M1_FLUSH_WAIT: aspetta CL cicli, scarta il dato ─────────────
                -- 7 cicli (rd_timer=6) sufficienti per CL=3 + tRP ≈ 5 cicli.
                when M1_FLUSH_WAIT =>
                    rd_timer <= rd_timer + 1;
                    if rd_timer = 6 then
                        state_ack <= '1';
                        arb_state <= M1_ACK;
                    end if;

                -- ── M1_ACK: hold ack finché DMA deasserta stb ───────────────────
                when M1_ACK =>
                    state_ack <= '1';
                    if m1_cyc_i = '0' or m1_stb_i = '0' then
                        arb_state <= IDLE;
                        state_ack <= '0';
                    end if;

                -- ── M0_CMD: tiene cmd_en='1' finché cmd_ack ─────────────────────
                when M0_CMD =>
                    sdrc_cmd_en <= '1';
                    sdrc_cmd    <= "101";  -- READ
                    if sdrc_cmd_ack = '1' then
                        rd_ack_seen <= '1';
                        rd_timer    <= (others => '0');
                        arb_state   <= M0_RD_WAIT;
                    elsif m0_cyc_i = '0' or m0_stb_i = '0' then
                        arb_state <= IDLE;
                    end if;

                -- ── M0_RD_WAIT: aspetta CL=3 cicli dopo cmd_ack ─────────────────
                -- 5 cicli da cmd_ack: al ciclo 5 O_sdrc_data è stabile (finestra t=3..7).
                when M0_RD_WAIT =>
                    rd_timer <= rd_timer + 1;
                    if rd_timer = 4 then
                        m0_rd_data_lat <= sdrc_data_out;
                        state_ack      <= '1';
                        arb_state      <= M0_ACK;
                    elsif m0_cyc_i = '0' or m0_stb_i = '0' then
                        arb_state <= IDLE;
                        rd_timer  <= (others => '0');
                    end if;

                -- ── M0_ACK: hold ack finché AUSP deasserta stb ──────────────────
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
        I_sdrc_precharge_ctrl => '1',  -- auto-precharge: chiude la riga dopo ogni accesso (richiesto dal flush READ)
        I_sdram_power_down    => '0',
        I_sdram_selfrefresh   => '0',
        I_sdrc_addr           => sdrc_addr_r,
        I_sdrc_dqm            => "0000",
        I_sdrc_data           => sdrc_data_r,
        I_sdrc_data_len       => x"00",  -- length-1: x"00" = 1 word
        O_sdrc_data           => sdrc_data_out,
        O_sdrc_init_done      => sdrc_init_done,
        O_sdrc_cmd_ack        => sdrc_cmd_ack
    );

end structural;
