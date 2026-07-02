library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- =============================================================================
--  sdram_controller_fsm  -  controller SDR SDRAM scritto a mano
-- =============================================================================
--  Rimpiazza l'IP cifrato Gowin "SDRAM_controller_top_SIP": STESSE porte, STESSO
--  protocollo lato utente, STESSI timing documentati nel report (sec. SDRAM).
--  Pilota il die SDR embedded del GW2AR-18 (4 bank x 2048 righe x 256 colonne
--  x 32 bit, 8 MB) parlando JEDEC: ACTIVE / READ / WRITE / PRECHARGE / REFRESH /
--  LOAD MODE REGISTER, con bring-up CKE -> >=200us -> PRECHARGE ALL -> 2x AUTO
--  REFRESH -> LMR (CAS latency 3, sequenziale, full-page burst).
--
--  Metodologia: due processi (stato presente / stato prossimo).
--    p_comb  : combinatorio, calcola SOLO next_state (case su 'st').
--    p_sync  : sincrono, registra st<=nstate, i contatori, i latch e TUTTE le
--              uscite (Moore registrate: comando emesso nel 1o ciclo di ogni
--              stato, riconosciuto con "nstate /= st").
--
--  Clock (come il SIP):
--    I_sdrc_clk  = clk_sdram   (40.5 MHz) -> tutta la logica e il sampling DQ.
--    I_sdram_clk = clk_sdram_p (+1.54 ns) -> inoltrato su O_sdram_clk per
--                  centrare la finestra dati in lettura (vedi report).
--
--  Indirizzo utente I_sdrc_addr[20:0] = { ba[1:0], row[10:0], col[7:0] }.
--  data_len = N  ->  burst di N+1 parole (il progetto usa N=26 -> 27 parole).
-- =============================================================================

entity sdram_controller_fsm is
    generic (
        -- Timing in cicli di I_sdrc_clk (40.5 MHz, tCK = 24.69 ns).
        INIT_WAIT_CYCLES : natural := 8192;  -- >=200us (8100 -> arrotondato)
        TRCD_CYCLES      : natural := 3;     -- ACTIVE -> READ/WRITE
        CL_CYCLES        : natural := 3;     -- CAS latency (READ -> dato)
        TRP_CYCLES       : natural := 2;     -- PRECHARGE -> ACTIVE
        TRFC_CYCLES      : natural := 4;     -- durata AUTO REFRESH
        TMRD_CYCLES      : natural := 2;     -- LMR -> comando successivo
        TWR_CYCLES       : natural := 2;     -- write recovery prima di PRECHARGE
        REFRESH_INTERVAL : natural := 312;   -- AUTO REFRESH ~ogni 7.7us
        -- Istante di cattura in lettura. RD_CAP_ADJ=0 (= attesa CL+1) e' il valore
        -- VALIDATO: bin buoni in sim e su board. ATTENZIONE: valori NEGATIVI
        -- anticipano la cattura PRIMA che il dato valido arrivi dal die -> si legge
        -- il bus DQ flottante (pull-up = 0xFFFF) sui primi indici di ogni burst ->
        -- bin fissi al massimo. NON usare negativi. (Tentativo -2 sbagliato, vedi
        -- diario.) Eventuali correzioni di allineamento vanno fatte sul lato
        -- scrittura, non anticipando la lettura.
        RD_CAP_ADJ       : integer := 0;
        -- Allineamento del dato di SCRITTURA (calibrazione HW). La delay line porta
        -- il dato dal DMA al DQ; con WR_ALIGN=0 sono 2 stadi (wpipe1->wpipe2). Sul
        -- silicio i log mostrano i toni 1 bin SOTTO l'atteso (carrier slave su bin26
        -- invece di 27, ecc.): la 1a parola (word0) arriva un ciclo prima del comando
        -- WRITE e va persa -> tutto slitta -1. WR_ALIGN=1 aggiunge 1 stadio (wpipe3)
        -- cosi' word0 coincide col WRITE e i bin tornano al posto giusto (no garbage:
        -- tutte le colonne restano scritte). Il testbench lo forza a 0 (modello ideale).
        WR_ALIGN         : natural := 1
    );
    port (
        -- ---- lato die SDRAM (identico al SIP) -------------------------------
        O_sdram_clk        : out   std_logic;
        O_sdram_cke        : out   std_logic;
        O_sdram_cs_n       : out   std_logic;
        O_sdram_cas_n      : out   std_logic;
        O_sdram_ras_n      : out   std_logic;
        O_sdram_wen_n      : out   std_logic;
        O_sdram_dqm        : out   std_logic_vector(3 downto 0);
        O_sdram_addr       : out   std_logic_vector(10 downto 0);
        O_sdram_ba         : out   std_logic_vector(1 downto 0);
        IO_sdram_dq        : inout std_logic_vector(31 downto 0);
        -- ---- lato utente (identico al SIP) ----------------------------------
        I_sdrc_rst_n       : in    std_logic;
        I_sdrc_clk         : in    std_logic;
        I_sdram_clk        : in    std_logic;
        I_sdrc_selfrefresh : in    std_logic;
        I_sdrc_power_down  : in    std_logic;
        I_sdrc_wr_n        : in    std_logic;
        I_sdrc_rd_n        : in    std_logic;
        I_sdrc_addr        : in    std_logic_vector(20 downto 0);
        I_sdrc_data_len    : in    std_logic_vector(7 downto 0);
        I_sdrc_dqm         : in    std_logic_vector(3 downto 0);
        I_sdrc_data        : in    std_logic_vector(31 downto 0);
        O_sdrc_data        : out   std_logic_vector(31 downto 0);
        O_sdrc_init_done   : out   std_logic;
        O_sdrc_busy_n      : out   std_logic;
        O_sdrc_rd_valid    : out   std_logic;
        O_sdrc_wrd_ack     : out   std_logic
    );
end entity sdram_controller_fsm;

architecture rtl of sdram_controller_fsm is

    -- ---- encoding comando {cs_n, ras_n, cas_n, wen_n} -----------------------
    subtype cmd_t is std_logic_vector(3 downto 0);
    constant CMD_NOP  : cmd_t := "0111";  -- (CS basso, gli altri alti)
    constant CMD_ACT  : cmd_t := "0011";  -- ACTIVE
    constant CMD_READ : cmd_t := "0101";  -- READ
    constant CMD_WRITE: cmd_t := "0100";  -- WRITE
    constant CMD_PRE  : cmd_t := "0010";  -- PRECHARGE
    constant CMD_REF  : cmd_t := "0001";  -- AUTO REFRESH
    constant CMD_LMR  : cmd_t := "0000";  -- LOAD MODE REGISTER
    constant CMD_INH  : cmd_t := "1111";  -- DESELECT (CS alto)

    -- Mode Register: BL=full page(A2-0=111), CL=3(A6-4=011), seq(A3=0), A9=0.
    constant MODE_REG : std_logic_vector(10 downto 0) := "00000110111";

    type state_t is (
        S_RESET, S_INIT_WAIT, S_INIT_PRE, S_INIT_REF1, S_INIT_REF2, S_INIT_LMR,
        S_IDLE, S_REF,
        S_ACT_RD, S_RD, S_RD_DATA,
        S_ACT_WR, S_WR_DATA, S_TWR,
        S_PRE
    );
    signal st, nstate : state_t;

    -- contatore unico: azzerato a ogni cambio stato, incrementa restando.
    -- serve sia come timer (attese) sia come indice parola (cattura/drena/leggi).
    signal tmr : unsigned(13 downto 0);

    -- ===================== DIAGNOSTICA (per debug) =====================
    -- DIAG_READ_RAMP  : in lettura O_sdrc_data = rampa (bypassa il die).
    -- DIAG_WRITE_RAMP : in scrittura manda al die una rampa NOTA invece dei dati.
    -- DIAG_WRITE_SPIKE: MISURA ALLINEAMENTO. Scrive uno spike isolato (valore alto)
    --   al solo word-index SPIKE_IDX, zero altrove. Con lettura allineata il picco
    --   appare su bin SPIKE_IDX (burst0) e bin 26+SPIKE_IDX (burst1). Il display
    --   mostra bin 16..55: con SPIKE_IDX=20 -> due picchi netti su bin 20 e 46.
    --   Se cadono piu' in basso = la lettura prende colonne piu' avanti (shift da
    --   correggere a MONTE, lato scrittura); piu' in alto = il contrario.
    --   Tutte e tre a false = funzionamento normale.
    constant DIAG_READ_RAMP   : boolean := false;
    constant DIAG_WRITE_RAMP  : boolean := false;
    constant DIAG_WRITE_SPIKE : boolean := false;    -- misura fatta: allineamento OK
    constant SPIKE_IDX        : natural := 20;       -- -> bin 20 (burst0) e 46 (burst1)
    -- ==================================================================

    -- latch dei parametri del comando accettato
    signal ba_lat  : std_logic_vector(1 downto 0);
    signal col_lat : std_logic_vector(7 downto 0);
    signal len_lat : unsigned(7 downto 0);
    signal dqm_lat : std_logic_vector(3 downto 0);

    -- refresh
    signal ref_cnt : unsigned(9 downto 0);
    signal ref_req : std_logic;

    -- Scrittura in STREAMING come il SIP: NESSUN buffer-array. Il dato in arrivo
    -- dal DMA (uno per ciclo, continuo) viene RITARDATO di TRCD cicli da una
    -- delay line di registri SINGOLI (niente array indicizzato) e mandato al DQ.
    -- Cosi' la parola arrivata il ciclo dopo lo strobe esce esattamente quando
    -- parte il comando WRITE (= ACTIVE + tRCD).
    --
    -- PERCHE' COSI' (causa vera del bug "bin 16-23 uguali"): rampa OK, dati veri
    -- NO -> l'unica differenza era la sorgente di dq_out_r. La rampa la prende da
    -- un contatore (registro semplice) e funziona; le versioni precedenti la
    -- prendevano da `wbuf(indice)`, cioe' una LETTURA INDICIZZATA di un array a 32
    -- parole, che Gowin mappa in SSRAM/SRL e che si guastava proprio sugli indici
    -- 16-23 (sia shift register sia register file fallivano IDENTICI: comune =
    -- l'array). Qui dq_out_r pesca da un registro singolo (wpipe2), come la rampa:
    -- niente array -> niente SSRAM/SRL.
    --
    -- NB: la profondita' della delay line (= numero di stadi prima di dq_out_r)
    -- deve valere TRCD_CYCLES. Con TRCD_CYCLES=3: 2 stadi (wpipe1,wpipe2) +
    -- dq_out_r = 3 cicli di ritardo. Se si cambia TRCD_CYCLES, adeguare gli stadi.
    signal wpipe1 : std_logic_vector(31 downto 0);   -- stadio 1 della delay line
    signal wpipe2 : std_logic_vector(31 downto 0);   -- stadio 2 (sorgente se WR_ALIGN=0)
    signal wpipe3 : std_logic_vector(31 downto 0);   -- stadio 3 opzionale (sorgente se WR_ALIGN=1)

    -- DQ e uscite registrate
    signal dq_in_r  : std_logic_vector(31 downto 0);
    signal dq_out_r : std_logic_vector(31 downto 0);
    signal dq_oe_r  : std_logic;

    signal cmd_r       : cmd_t;
    signal addr_r      : std_logic_vector(10 downto 0);
    signal bank_r      : std_logic_vector(1 downto 0);
    signal dqm_r       : std_logic_vector(3 downto 0);
    signal init_done_r : std_logic;
    signal busy_n_r    : std_logic;
    signal rd_valid_r  : std_logic;
    signal wrd_ack_r   : std_logic;
    signal data_r      : std_logic_vector(31 downto 0);

begin

    -- forward del clock sfasato verso il die (come fa il SIP con I_sdram_clk)
    O_sdram_clk <= I_sdram_clk;
    O_sdram_cke <= '1';                       -- CKE alto da subito (richiesto nel bring-up)

    -- bus comando registrato
    O_sdram_cs_n  <= cmd_r(3);
    O_sdram_ras_n <= cmd_r(2);
    O_sdram_cas_n <= cmd_r(1);
    O_sdram_wen_n <= cmd_r(0);
    O_sdram_addr  <= addr_r;
    O_sdram_ba    <= bank_r;
    O_sdram_dqm   <= dqm_r;

    -- tristate del bus dati
    IO_sdram_dq <= dq_out_r when dq_oe_r = '1' else (others => 'Z');

    O_sdrc_data      <= data_r;
    O_sdrc_init_done <= init_done_r;
    O_sdrc_busy_n    <= busy_n_r;
    O_sdrc_rd_valid  <= rd_valid_r;
    O_sdrc_wrd_ack   <= wrd_ack_r;

    -- =========================================================================
    --  next_state (combinatorio puro)
    -- =========================================================================
    p_comb : process(st, tmr, ref_req, I_sdrc_wr_n, I_sdrc_rd_n, len_lat)
    begin
        nstate <= st;
        case st is
            when S_RESET     => nstate <= S_INIT_WAIT;

            when S_INIT_WAIT =>
                if tmr = INIT_WAIT_CYCLES - 1 then nstate <= S_INIT_PRE; end if;
            when S_INIT_PRE  =>                              -- PRECHARGE ALL + tRP
                if tmr = TRP_CYCLES  - 1 then nstate <= S_INIT_REF1; end if;
            when S_INIT_REF1 =>                              -- AUTO REFRESH + tRFC
                if tmr = TRFC_CYCLES - 1 then nstate <= S_INIT_REF2; end if;
            when S_INIT_REF2 =>
                if tmr = TRFC_CYCLES - 1 then nstate <= S_INIT_LMR;  end if;
            when S_INIT_LMR  =>                              -- LMR + tMRD
                if tmr = TMRD_CYCLES - 1 then nstate <= S_IDLE;      end if;

            when S_IDLE =>
                -- priorita' al comando utente (l'impulso wr_n/rd_n dura 1 ciclo
                -- e non si puo' perdere); il refresh resta pending e parte al
                -- primo IDLE senza comando (i burst hanno ampi vuoti fra loro).
                if    I_sdrc_wr_n  = '0' then nstate <= S_ACT_WR;
                elsif I_sdrc_rd_n  = '0' then nstate <= S_ACT_RD;
                elsif ref_req      = '1' then nstate <= S_REF;
                end if;

            when S_REF =>
                if tmr = TRFC_CYCLES - 1 then nstate <= S_IDLE; end if;

            -- ---- lettura --------------------------------------------------
            when S_ACT_RD =>                                 -- ACTIVE riga + tRCD
                if tmr = TRCD_CYCLES - 1 then nstate <= S_RD; end if;
            when S_RD =>                                     -- READ col + CL + 2
                -- attesa = CAS latency + i 2 stadi di registro del path di lettura
                -- (IO_sdram_dq -> dq_in_r -> data_r) + RD_CAP_ADJ (calibrazione HW).
                -- Nel modello ideale RD_CAP_ADJ=0 allinea il 1o rd_valid alla 1a
                -- parola; sul silicio RD_CAP_ADJ=-2 (vedi generic).
                if tmr = CL_CYCLES + 1 + RD_CAP_ADJ then nstate <= S_RD_DATA; end if;
            when S_RD_DATA =>                                -- N+1 parole valide
                if tmr = len_lat then nstate <= S_PRE; end if;

            -- ---- scrittura (streaming: ACTIVE -> tRCD -> WRITE + delay line) ---
            when S_ACT_WR =>                                 -- ACTIVE riga + tRCD
                if tmr = TRCD_CYCLES - 1 then nstate <= S_WR_DATA; end if;
            when S_WR_DATA =>                                -- WRITE col + streama
                if tmr = len_lat then nstate <= S_TWR; end if;
            when S_TWR =>                                    -- write recovery
                if tmr = TWR_CYCLES - 1 then nstate <= S_PRE; end if;

            when S_PRE =>                                    -- PRECHARGE + tRP
                if tmr = TRP_CYCLES - 1 then nstate <= S_IDLE; end if;
        end case;
    end process;

    -- =========================================================================
    --  registri: stato, contatori, latch, buffer, uscite registrate
    -- =========================================================================
    p_sync : process(I_sdrc_clk)
        variable ntmr : unsigned(13 downto 0);
    begin
        if rising_edge(I_sdrc_clk) then
            if I_sdrc_rst_n = '0' then
                st          <= S_RESET;
                tmr         <= (others => '0');
                wpipe1      <= (others => '0');
                wpipe2      <= (others => '0');
                wpipe3      <= (others => '0');
                ref_cnt     <= (others => '0');
                ref_req     <= '0';
                init_done_r <= '0';
                busy_n_r    <= '0';
                rd_valid_r  <= '0';
                wrd_ack_r   <= '0';
                dq_oe_r     <= '0';
                cmd_r       <= CMD_INH;
                addr_r      <= (others => '0');
                bank_r      <= (others => '0');
                dqm_r       <= (others => '0');
                data_r      <= (others => '0');
            else
                ------------------------------------------------------------------
                -- stato + contatore (azzerato a ogni transizione)
                ------------------------------------------------------------------
                st <= nstate;
                if nstate /= st then ntmr := (others => '0');
                else                 ntmr := tmr + 1;
                end if;
                tmr <= ntmr;

                ------------------------------------------------------------------
                -- contatore di refresh (libero; servito al primo IDLE)
                ------------------------------------------------------------------
                if ref_cnt = REFRESH_INTERVAL - 1 then
                    ref_cnt <= (others => '0');
                    ref_req <= '1';
                else
                    ref_cnt <= ref_cnt + 1;
                end if;
                if st = S_REF then        -- richiesta servita
                    ref_req <= '0';
                end if;

                ------------------------------------------------------------------
                -- init_done / busy_n
                ------------------------------------------------------------------
                if st = S_INIT_LMR and nstate = S_IDLE then
                    init_done_r <= '1';
                end if;
                -- pronto solo in IDLE e con nessun refresh pending: cosi' chi
                -- attende busy_n=1 (DMA/fetch) non emette un impulso wr_n/rd_n
                -- proprio nel ciclo in cui il controller parte col refresh.
                if nstate = S_IDLE and ref_req = '0' then busy_n_r <= '1';
                else                                       busy_n_r <= '0';
                end if;

                ------------------------------------------------------------------
                -- latch dei parametri quando si accetta un comando in IDLE
                ------------------------------------------------------------------
                if st = S_IDLE and
                   (I_sdrc_wr_n = '0' or I_sdrc_rd_n = '0') then
                    ba_lat  <= I_sdrc_addr(20 downto 19);
                    col_lat <= I_sdrc_addr( 7 downto  0);
                    len_lat <= unsigned(I_sdrc_data_len);
                    dqm_lat <= I_sdrc_dqm;
                end if;

                ------------------------------------------------------------------
                -- DELAY LINE di scrittura (registri singoli, NESSUN array).
                -- Scorre SEMPRE il dato in arrivo dal DMA: I_sdrc_data -> wpipe1 ->
                -- wpipe2 -> wpipe3. La sorgente di dq_out_r e' wpipe2 (WR_ALIGN=0,
                -- modello ideale) o wpipe3 (WR_ALIGN=1, board: +1 stadio per recuperare
                -- word0 e rimettere i bin al posto giusto). La parola esce su DQ quando
                -- parte il comando WRITE (ACTIVE+tRCD).
                ------------------------------------------------------------------
                wpipe1 <= I_sdrc_data;
                wpipe2 <= wpipe1;
                wpipe3 <= wpipe2;
                wrd_ack_r <= '0';            -- non usato dal DMA

                ------------------------------------------------------------------
                -- pilotaggio DQ in scrittura: una parola per ciclo da wpipe2, un
                -- REGISTRO SINGOLO (come la rampa, NON una lettura da array). Parte
                -- sul 1o ciclo di streaming (nstate=S_WR_DATA mentre st=S_ACT_WR):
                -- in quel ciclo wpipe2 contiene gia' word0 (3 stadi dopo lo strobe).
                ------------------------------------------------------------------
                if nstate = S_WR_DATA then
                    if DIAG_WRITE_SPIKE then
                        -- spike isolato a SPIKE_IDX, zero altrove (misura allineamento)
                        if ntmr = SPIKE_IDX then dq_out_r <= x"00004000";
                        else                     dq_out_r <= (others => '0'); end if;
                    elsif DIAG_WRITE_RAMP then
                        -- rampa sui BIT ALTI (11..15) per testare quei DQ:
                        -- ntmr<<11 -> 0, 0x0800, 0x1000, ... (16 bit bassi, upper=0)
                        dq_out_r <= x"0000" & std_logic_vector(shift_left(resize(ntmr, 16), 11));
                    elsif WR_ALIGN = 1 then
                        dq_out_r <= wpipe3;   -- board: +1 stadio (recupera word0)
                    else
                        dq_out_r <= wpipe2;   -- modello ideale / testbench
                    end if;
                    dq_oe_r <= '1';
                else
                    dq_oe_r <= '0';
                end if;

                ------------------------------------------------------------------
                -- campionamento DQ su I_sdrc_clk (il die pilota DQ su O_sdram_clk=
                -- clkoutp, sfasato +1.54 ns -> qui si campiona al centro della
                -- finestra dati). IDENTICO al SIP: tutta la logica su I_sdrc_clk,
                -- O_sdram_clk = I_sdram_clk diretto, DQ via IOBUF normale.
                ------------------------------------------------------------------
                dq_in_r <= IO_sdram_dq;
                if nstate = S_RD_DATA then
                    if DIAG_READ_RAMP then
                        data_r <= std_logic_vector(resize(ntmr, 32));  -- rampa = indice parola
                    else
                        data_r <= dq_in_r;                             -- dato dal die (pulito, come il SIP)
                    end if;
                    rd_valid_r <= '1';
                else
                    rd_valid_r <= '0';
                end if;

                ------------------------------------------------------------------
                -- bus comando / indirizzo: comando emesso nel 1o ciclo dello
                -- stato (ingresso = "nstate /= st"); altrimenti NOP.
                ------------------------------------------------------------------
                cmd_r  <= CMD_NOP;
                addr_r <= (others => '0');
                bank_r <= ba_lat;
                if nstate /= st then
                    case nstate is
                        when S_INIT_PRE | S_PRE =>
                            cmd_r  <= CMD_PRE;
                            addr_r <= "10000000000";          -- A10=1: tutti i bank
                        when S_INIT_REF1 | S_INIT_REF2 | S_REF =>
                            cmd_r  <= CMD_REF;
                        when S_INIT_LMR =>
                            cmd_r  <= CMD_LMR;
                            addr_r <= MODE_REG;
                            bank_r <= "00";
                        when S_ACT_RD | S_ACT_WR =>
                            -- L'ACTIVE e' emesso NELLO STESSO ciclo dello strobe
                            -- (S_IDLE -> S_ACT_*), quando row_lat/ba_lat sono ancora
                            -- in fase di latch (vecchio valore!). Si prende quindi
                            -- la riga/bank DIRETTAMENTE da I_sdrc_addr, valido allo
                            -- strobe. col_lat invece e' usato da READ/WRITE che
                            -- arrivano tRCD cicli dopo, quando e' gia' stabile.
                            cmd_r  <= CMD_ACT;
                            addr_r <= I_sdrc_addr(18 downto 8);
                            bank_r <= I_sdrc_addr(20 downto 19);
                        when S_RD =>
                            cmd_r  <= CMD_READ;
                            addr_r <= "000" & col_lat;        -- A10=0: no auto-precharge
                        when S_WR_DATA =>
                            cmd_r  <= CMD_WRITE;
                            addr_r <= "000" & col_lat;
                        when others =>
                            cmd_r  <= CMD_NOP;
                    end case;
                end if;

                ------------------------------------------------------------------
                -- DQM: basso durante le finestre dato, mascherato altrimenti
                ------------------------------------------------------------------
                if nstate = S_RD or nstate = S_RD_DATA then
                    dqm_r <= "0000";
                elsif nstate = S_WR_DATA then
                    dqm_r <= dqm_lat;
                else
                    dqm_r <= "1111";
                end if;

            end if;
        end if;
    end process;

end architecture rtl;
