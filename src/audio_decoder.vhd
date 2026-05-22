library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Audio Decoder (memory-read) — porting fedele del decoder C di riferimento
-- (firmware/src/decoder.c: check_active_frequencies + interpolate_peak_frequency).
--
-- Per ogni FREQUENZA ATTESA (i bin della mappa giocattolo) NON si prende il max
-- di una finestra larga: si guarda il bin esatto, si verifica che sia un MASSIMO
-- LOCALE rispetto ai vicini (±WINR), e si stima il magnitude PRECISO con
-- interpolazione parabolica sui 3 punti alpha/beta/gamma. Si confronta con una
-- soglia ASSOLUTA (generic THRESHOLD).
--
-- Interpolazione (come in C):
--   alpha=|bin-1|, beta=|bin|, gamma=|bin+1|
--   p   = 0.5*(alpha-gamma)/(alpha-2*beta+gamma)
--   amp = beta - 0.25*(alpha-gamma)*p
-- Posto D = 2*beta-alpha-gamma (>0 a un picco), amp = beta + (alpha-gamma)^2/(8*D),
-- quindi il test  amp > T  equivale (moltiplicando per 8*D>0) a
--   8*D*(beta-T) + (alpha-gamma)^2 > 0     -- solo interi, nessun divisore HW.
--
-- Interfaccia memoria: mem_addr_o presenta l'indirizzo (combinatorio da rd_addr),
-- mem_data_i e' valido 1 ciclo dopo (BSRAM sincrona).
--
-- Mappa giocattolo binaria {1,2,4}+EOP, Fs ≈ 45 750 Hz, Δf ≈ 89.36 Hz:
--   master carrier 2000 Hz → bin 22, config carrier 2400 Hz → bin 27,
--   EOP 2800 (bin 31), dati 3200..5200 Hz (bin 36/40/45/49/54/58).
entity audio_decoder is
    Generic (
        DEBUG_MODE : boolean := false;
        THRESHOLD  : integer := 6;     -- soglia ASSOLUTA sul magnitude interpolato
        N_BINS     : integer := 256    -- (compat: non piu' usato, le freq sono puntuali)
    );
    Port (
        clk_i      : in  std_logic;
        rst_i      : in  std_logic;     -- reset attivo basso
        start_i    : in  std_logic;     -- pulse 1 colpo: un frame e' pronto in BSRAM
        mem_addr_o : out std_logic_vector(8 downto 0);
        mem_data_i : in  std_logic_vector(15 downto 0);  -- 16-bit signed
        busy_i     : in  std_logic;     -- UART TX busy (handshake debug)
        char_o     : out std_logic_vector(7 downto 0);
        char_stb_o : out std_logic;
        busy_o     : out std_logic
    );
end audio_decoder;

architecture behavioral of audio_decoder is

    -- Tabella dei bin attesi. ROLE: 0=master carrier, 1=config carrier, 2=signal.
    -- CODE valido solo per i signal (carriers non emettono un codice dati).
    --   bin 31=EOP(8), 36=Z1(0), 40=O1(10), 45=Z2(1), 49=O2(11), 54=Z4(2), 58=O4(12)
    constant NCAND : integer := 9;
    constant WINR  : integer := 3;     -- raggio finestra massimo-locale (±3)
    type icand_t is array(0 to NCAND-1) of integer;
    constant CAND_BIN  : icand_t := (22, 27, 31, 36, 40, 45, 49, 54, 58);
    constant CAND_ROLE : icand_t := ( 0,  1,  2,  2,  2,  2,  2,  2,  2);
    constant CAND_CODE : icand_t := ( 0,  0,  8,  0, 10,  1, 11,  2, 12);

    constant DBG_LEN : integer := 19;

    type state_t is (ST_IDLE, ST_LAT, ST_CAP, ST_EVAL, ST_DECIDE, ST_EMIT,
                     ST_DBG_WAIT, ST_DBG_SENT, ST_DBG_DRAIN);
    signal state : state_t := ST_IDLE;

    signal cand_idx : integer range 0 to NCAND-1 := 0;
    signal off      : integer range 0 to 2*WINR := 0;
    signal rd_addr  : integer range 0 to 511 := 0;

    type win_t is array(0 to 2*WINR) of unsigned(14 downto 0);
    signal win : win_t := (others => (others => '0'));

    -- accumulatori per-frame
    signal m_det, c_det, s_det : std_logic := '0';
    signal m_beta, c_beta      : unsigned(14 downto 0) := (others => '0');
    signal best_s_beta         : unsigned(14 downto 0) := (others => '0');
    signal best_s_bin          : integer range 0 to 511 := 0;
    signal best_s_code         : integer range 0 to 15  := 0;

    signal char_r     : std_logic_vector(7 downto 0) := (others => '0');
    signal char_stb_r : std_logic := '0';

    type dbg_buf_t is array(0 to DBG_LEN - 1) of std_logic_vector(7 downto 0);
    signal dbg_buf : dbg_buf_t := (others => (others => '0'));
    signal dbg_idx : integer range 0 to DBG_LEN := 0;

    function abs_mag(v : std_logic_vector(15 downto 0)) return unsigned is
        variable s : signed(15 downto 0);
        variable u : unsigned(15 downto 0);
    begin
        s := signed(v);
        if s(15) = '0' then
            u := unsigned(v);
        else
            if v = x"8000" then u := x"7FFF";
            else u := unsigned(std_logic_vector(-s)); end if;
        end if;
        return u(14 downto 0);
    end function;

    function hexc(n : unsigned(3 downto 0)) return std_logic_vector is
        variable v : integer;
    begin
        v := to_integer(n);
        if v < 10 then return std_logic_vector(to_unsigned(48 + v, 8));
        else           return std_logic_vector(to_unsigned(55 + v, 8)); end if;
    end function;

    function code_to_char(is_config : boolean; code : integer) return std_logic_vector is
        variable base : integer;
        variable c    : integer;
    begin
        if is_config then base := 65; else base := 97; end if;
        if code <= 8 then c := base + code;
        else              c := base + code - 1;
        end if;
        return std_logic_vector(to_unsigned(c, 8));
    end function;

begin

    -- indirizzo combinatorio: la BSRAM (registrata) restituisce il dato 1 ciclo dopo
    mem_addr_o <= std_logic_vector(to_unsigned(rd_addr, 9));
    char_o     <= char_r;
    char_stb_o <= char_stb_r;
    busy_o     <= '0' when state = ST_IDLE else '1';

    process(clk_i)
        variable a_s, b_s, g_s : signed(16 downto 0);
        variable diff_s        : signed(17 downto 0);
        variable diffsq_s      : signed(35 downto 0);
        variable d_s           : signed(18 downto 0);
        variable bmt_s         : signed(17 downto 0);
        variable dm_s          : signed(36 downto 0);
        variable term1_s       : signed(47 downto 0);
        variable test_s        : signed(47 downto 0);
        variable localmax      : boolean;
        variable det           : boolean;
        variable sbin, sbeta   : unsigned(7 downto 0);
        variable flags         : unsigned(3 downto 0);
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                state       <= ST_IDLE;
                cand_idx    <= 0;
                off         <= 0;
                rd_addr     <= 0;
                m_det <= '0'; c_det <= '0'; s_det <= '0';
                m_beta <= (others => '0'); c_beta <= (others => '0');
                best_s_beta <= (others => '0'); best_s_bin <= 0; best_s_code <= 0;
                char_r      <= (others => '0');
                char_stb_r  <= '0';
                dbg_idx     <= 0;
            else
                char_stb_r <= '0';

                case state is

                    when ST_IDLE =>
                        if start_i = '1' then
                            cand_idx    <= 0;
                            off         <= 0;
                            rd_addr     <= CAND_BIN(0) - WINR;
                            m_det <= '0'; c_det <= '0'; s_det <= '0';
                            m_beta <= (others => '0'); c_beta <= (others => '0');
                            best_s_beta <= (others => '0');
                            best_s_bin  <= 0; best_s_code <= 0;
                            state       <= ST_LAT;
                        end if;

                    -- indirizzo presentato in rd_addr: 1 ciclo per la latenza BSRAM
                    when ST_LAT =>
                        state <= ST_CAP;

                    -- mem_data_i valido = BSRAM[rd_addr]; lo metto in win(off)
                    when ST_CAP =>
                        win(off) <= abs_mag(mem_data_i);
                        if off = 2*WINR then
                            state <= ST_EVAL;
                        else
                            off     <= off + 1;
                            rd_addr <= CAND_BIN(cand_idx) - WINR + off + 1;
                            state   <= ST_LAT;
                        end if;

                    -- finestra completa win(0..2*WINR): centro = win(WINR)
                    when ST_EVAL =>
                        a_s := to_signed(to_integer(win(WINR-1)), 17);  -- alpha
                        b_s := to_signed(to_integer(win(WINR)),   17);  -- beta (centro)
                        g_s := to_signed(to_integer(win(WINR+1)), 17);  -- gamma

                        -- massimo locale su tutta la finestra ±WINR
                        localmax := (win(WINR) >= win(0)) and (win(WINR) >= win(1))
                                and (win(WINR) >= win(2)) and (win(WINR) >= win(4))
                                and (win(WINR) >= win(5)) and (win(WINR) >= win(6));

                        d_s      := resize(b_s,19) + resize(b_s,19)
                                    - resize(a_s,19) - resize(g_s,19);   -- 2b-a-g
                        diff_s   := resize(a_s,18) - resize(g_s,18);      -- alpha-gamma
                        diffsq_s := diff_s * diff_s;
                        bmt_s    := to_signed(to_integer(b_s) - THRESHOLD, 18);
                        dm_s     := d_s * bmt_s;
                        term1_s  := shift_left(resize(dm_s, 48), 3);      -- *8
                        test_s   := term1_s + resize(diffsq_s, 48);

                        -- amp_interp > THRESHOLD  <=>  8*D*(beta-T)+(alpha-gamma)^2 > 0
                        det := localmax and (d_s > 0) and (test_s > 0);

                        if CAND_ROLE(cand_idx) = 0 then          -- master carrier
                            m_beta <= win(WINR);
                            if det then m_det <= '1'; end if;
                        elsif CAND_ROLE(cand_idx) = 1 then       -- config carrier
                            c_beta <= win(WINR);
                            if det then c_det <= '1'; end if;
                        else                                      -- signal: tieni il piu' forte
                            if win(WINR) > best_s_beta then
                                best_s_beta <= win(WINR);
                                best_s_bin  <= CAND_BIN(cand_idx);
                                best_s_code <= CAND_CODE(cand_idx);
                                if det then s_det <= '1'; else s_det <= '0'; end if;
                            end if;
                        end if;

                        if cand_idx = NCAND-1 then
                            state <= ST_DECIDE;
                        else
                            cand_idx <= cand_idx + 1;
                            off      <= 0;
                            rd_addr  <= CAND_BIN(cand_idx + 1) - WINR;
                            state    <= ST_LAT;
                        end if;

                    when ST_DECIDE =>
                        if DEBUG_MODE then
                            sbin  := to_unsigned(best_s_bin, 8);
                            sbeta := best_s_beta(7 downto 0);
                            flags := (others => '0');
                            flags(0) := m_det; flags(1) := c_det; flags(2) := s_det;

                            dbg_buf(0)  <= x"4D";                       -- 'M'
                            dbg_buf(1)  <= hexc(m_beta(7 downto 4));
                            dbg_buf(2)  <= hexc(m_beta(3 downto 0));
                            dbg_buf(3)  <= x"20";
                            dbg_buf(4)  <= x"43";                       -- 'C'
                            dbg_buf(5)  <= hexc(c_beta(7 downto 4));
                            dbg_buf(6)  <= hexc(c_beta(3 downto 0));
                            dbg_buf(7)  <= x"20";
                            dbg_buf(8)  <= x"53";                       -- 'S'
                            dbg_buf(9)  <= hexc(sbin(7 downto 4));
                            dbg_buf(10) <= hexc(sbin(3 downto 0));
                            dbg_buf(11) <= x"3A";                       -- ':'
                            dbg_buf(12) <= hexc(sbeta(7 downto 4));
                            dbg_buf(13) <= hexc(sbeta(3 downto 0));
                            dbg_buf(14) <= x"20";
                            dbg_buf(15) <= x"46";                       -- 'F'
                            dbg_buf(16) <= hexc(flags);
                            dbg_buf(17) <= x"0D";
                            dbg_buf(18) <= x"0A";
                            dbg_idx <= 0;
                            state   <= ST_DBG_WAIT;
                        else
                            if (s_det = '1') and (m_det = '1') and (c_det = '0') then
                                char_r <= code_to_char(false, best_s_code);
                                state  <= ST_EMIT;
                            elsif (s_det = '1') and (c_det = '1') and (m_det = '0') then
                                char_r <= code_to_char(true, best_s_code);
                                state  <= ST_EMIT;
                            else
                                state <= ST_IDLE;
                            end if;
                        end if;

                    when ST_EMIT =>
                        char_stb_r <= '1';
                        state      <= ST_IDLE;

                    when ST_DBG_WAIT =>
                        if busy_i = '0' then
                            char_r     <= dbg_buf(dbg_idx);
                            char_stb_r <= '1';
                            state      <= ST_DBG_SENT;
                        end if;

                    when ST_DBG_SENT =>
                        if busy_i = '1' then
                            state <= ST_DBG_DRAIN;
                        end if;

                    when ST_DBG_DRAIN =>
                        if busy_i = '0' then
                            if dbg_idx = DBG_LEN - 1 then
                                state <= ST_IDLE;
                            else
                                dbg_idx <= dbg_idx + 1;
                                state   <= ST_DBG_WAIT;
                            end if;
                        end if;

                end case;
            end if;
        end if;
    end process;

end behavioral;
