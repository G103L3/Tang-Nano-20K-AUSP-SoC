library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Audio Decoder (memory-read) — protocollo COMPATTO a opcode (vedi DIARIO
-- 2026-05-24). Niente run-length: 1 tono = 1 simbolo. Solo 5 frequenze, con
-- bit0/bit1 distanti 1000 Hz (poco confondibili):
--   carrier MASTER 2000 Hz (bin 22), carrier SLAVE 2400 Hz (bin 27),
--   EOF 2900 (bin 32), bit0 3500 (bin 39), bit1 4500 (bin 50).
--
-- Ogni simbolo emesso e' una coppia carrier + tono-dato. Il decoder, per ogni
-- frame, trova il carrier (master/slave) + il tono-dato (bit0/bit1/EOF) e emette
-- UN char:
--   carrier master -> minuscole 'a'/'b'/'c' (bit0/bit1/EOF)
--   carrier slave   -> MAIUSCOLE 'A'/'B'/'C'
--
-- Algoritmo di rilevamento invariato: per ogni bin atteso, massimo locale ±3 +
-- interpolazione parabolica + soglia assoluta (generic THRESHOLD). Test senza
-- divisore: 8*D*(beta-T)+(alpha-gamma)^2 > 0 con D=2*beta-alpha-gamma.
entity audio_decoder is
    Generic (
        DEBUG_MODE : boolean := false;
        THRESHOLD  : integer := 6;
        N_BINS     : integer := 256
    );
    Port (
        clk_i      : in  std_logic;
        rst_i      : in  std_logic;     -- reset attivo basso
        start_i    : in  std_logic;
        mem_addr_o : out std_logic_vector(8 downto 0);
        mem_data_i : in  std_logic_vector(15 downto 0);
        busy_i     : in  std_logic;
        char_o     : out std_logic_vector(7 downto 0);
        char_stb_o : out std_logic;
        busy_o     : out std_logic
    );
end audio_decoder;

architecture behavioral of audio_decoder is

    -- Candidati: 0=carrier master, 1=carrier slave, 2=bit0, 3=bit1, 4=EOF
    constant NCAND : integer := 5;
    constant WINR  : integer := 3;
    type icand_t is array(0 to NCAND-1) of integer;
    -- ordine: master(2000/22), slave(2400/27), bit0(3500/39), bit1(4500/50), EOF(2900/32)
    constant CAND_BIN : icand_t := (22, 27, 39, 50, 32);
    constant IDX_CM   : integer := 0;  -- carrier master 2000
    constant IDX_CS   : integer := 1;  -- carrier slave  2400
    constant IDX_B0   : integer := 2;  -- bit0 3500
    constant IDX_B1   : integer := 3;  -- bit1 4500
    constant IDX_EOF  : integer := 4;  -- EOF  2900

    constant DBG_LEN : integer := 21;

    type state_t is (ST_IDLE, ST_LAT, ST_CAP, ST_EVAL, ST_DECIDE, ST_EMIT,
                     ST_DBG_WAIT, ST_DBG_SENT, ST_DBG_DRAIN);
    signal state : state_t := ST_IDLE;

    signal cand_idx : integer range 0 to NCAND-1 := 0;
    signal off      : integer range 0 to 2*WINR := 0;
    signal rd_addr  : integer range 0 to 511 := 0;

    type win_t is array(0 to 2*WINR) of unsigned(14 downto 0);
    signal win : win_t := (others => (others => '0'));

    -- per-candidato: rilevato + magnitudine centrale (beta)
    type det_t  is array(0 to NCAND-1) of std_logic;
    type beta_t is array(0 to NCAND-1) of unsigned(14 downto 0);
    signal det  : det_t  := (others => '0');
    signal beta : beta_t := (others => (others => '0'));

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
        if s(15) = '0' then u := unsigned(v);
        else
            if v = x"8000" then u := x"7FFF";
            else u := unsigned(std_logic_vector(-s)); end if;
        end if;
        return u(14 downto 0);
    end function;

    function hexc(n : unsigned(3 downto 0)) return std_logic_vector is
        variable vv : integer;
    begin
        vv := to_integer(n);
        if vv < 10 then return std_logic_vector(to_unsigned(48 + vv, 8));
        else            return std_logic_vector(to_unsigned(55 + vv, 8)); end if;
    end function;

begin

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
        variable detected      : boolean;
        variable use_master    : boolean;
        variable car_base      : integer;
        variable data_sym      : integer;   -- 0=bit0,1=bit1,2=EOF
        variable data_beta     : unsigned(14 downto 0);
        variable have_data     : boolean;
        variable flags         : unsigned(3 downto 0);
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                state    <= ST_IDLE;
                cand_idx <= 0; off <= 0; rd_addr <= 0;
                det  <= (others => '0');
                beta <= (others => (others => '0'));
                char_r <= (others => '0'); char_stb_r <= '0';
                dbg_idx <= 0;
            else
                char_stb_r <= '0';
                case state is

                    when ST_IDLE =>
                        if start_i = '1' then
                            cand_idx <= 0; off <= 0;
                            rd_addr  <= CAND_BIN(0) - WINR;
                            det  <= (others => '0');
                            beta <= (others => (others => '0'));
                            state <= ST_LAT;
                        end if;

                    when ST_LAT =>
                        state <= ST_CAP;

                    when ST_CAP =>
                        win(off) <= abs_mag(mem_data_i);
                        if off = 2*WINR then
                            state <= ST_EVAL;
                        else
                            off     <= off + 1;
                            rd_addr <= CAND_BIN(cand_idx) - WINR + off + 1;
                            state   <= ST_LAT;
                        end if;

                    when ST_EVAL =>
                        a_s := to_signed(to_integer(win(WINR-1)), 17);
                        b_s := to_signed(to_integer(win(WINR)),   17);
                        g_s := to_signed(to_integer(win(WINR+1)), 17);
                        localmax := (win(WINR) >= win(0)) and (win(WINR) >= win(1))
                                and (win(WINR) >= win(2)) and (win(WINR) >= win(4))
                                and (win(WINR) >= win(5)) and (win(WINR) >= win(6));
                        d_s      := resize(b_s,19) + resize(b_s,19)
                                    - resize(a_s,19) - resize(g_s,19);
                        diff_s   := resize(a_s,18) - resize(g_s,18);
                        diffsq_s := diff_s * diff_s;
                        bmt_s    := to_signed(to_integer(b_s) - THRESHOLD, 18);
                        dm_s     := d_s * bmt_s;
                        term1_s  := shift_left(resize(dm_s, 48), 3);
                        test_s   := term1_s + resize(diffsq_s, 48);
                        detected := localmax and (d_s > 0) and (test_s > 0);

                        if detected then det(cand_idx) <= '1';
                        else             det(cand_idx) <= '0'; end if;
                        beta(cand_idx) <= win(WINR);

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
                            -- "M<cm> S<cs> 0<b0> 1<b1> E<eof> F<flags>\r\n"
                            flags := (others => '0');
                            flags(0) := det(IDX_CM);  flags(1) := det(IDX_CS);
                            flags(2) := det(IDX_B0) or det(IDX_B1) or det(IDX_EOF);
                            dbg_buf(0)  <= x"4D";                       -- 'M'
                            dbg_buf(1)  <= hexc(beta(IDX_CM)(7 downto 4));
                            dbg_buf(2)  <= hexc(beta(IDX_CM)(3 downto 0));
                            dbg_buf(3)  <= x"20";
                            dbg_buf(4)  <= x"53";                       -- 'S'
                            dbg_buf(5)  <= hexc(beta(IDX_CS)(7 downto 4));
                            dbg_buf(6)  <= hexc(beta(IDX_CS)(3 downto 0));
                            dbg_buf(7)  <= x"20";
                            dbg_buf(8)  <= x"30";                       -- '0'
                            dbg_buf(9)  <= hexc(beta(IDX_B0)(7 downto 4));
                            dbg_buf(10) <= hexc(beta(IDX_B0)(3 downto 0));
                            dbg_buf(11) <= x"31";                       -- '1'
                            dbg_buf(12) <= hexc(beta(IDX_B1)(7 downto 4));
                            dbg_buf(13) <= hexc(beta(IDX_B1)(3 downto 0));
                            dbg_buf(14) <= x"45";                       -- 'E'
                            dbg_buf(15) <= hexc(beta(IDX_EOF)(7 downto 4));
                            dbg_buf(16) <= hexc(beta(IDX_EOF)(3 downto 0));
                            dbg_buf(17) <= x"46";                       -- 'F'
                            dbg_buf(18) <= hexc(flags);
                            dbg_buf(19) <= x"0D";
                            dbg_buf(20) <= x"0A";
                            dbg_idx <= 0;
                            state   <= ST_DBG_WAIT;
                        else
                            -- dato piu' forte tra bit0/bit1/EOF (solo se rilevato)
                            have_data := false; data_beta := (others => '0'); data_sym := 0;
                            if det(IDX_B0) = '1' and beta(IDX_B0) > data_beta then
                                data_beta := beta(IDX_B0); data_sym := 0; have_data := true;
                            end if;
                            if det(IDX_B1) = '1' and beta(IDX_B1) > data_beta then
                                data_beta := beta(IDX_B1); data_sym := 1; have_data := true;
                            end if;
                            if det(IDX_EOF) = '1' and beta(IDX_EOF) > data_beta then
                                data_beta := beta(IDX_EOF); data_sym := 2; have_data := true;
                            end if;

                            -- carrier: master XOR slave (se entrambi, il piu' forte)
                            use_master := false;
                            if det(IDX_CM) = '1' and det(IDX_CS) = '0' then
                                use_master := true;
                            elsif det(IDX_CS) = '1' and det(IDX_CM) = '0' then
                                use_master := false;
                            elsif det(IDX_CM) = '1' and det(IDX_CS) = '1' then
                                use_master := beta(IDX_CM) >= beta(IDX_CS);
                            end if;

                            if have_data and (det(IDX_CM) = '1' or det(IDX_CS) = '1') then
                                if use_master then car_base := 97; else car_base := 65; end if;
                                char_r <= std_logic_vector(to_unsigned(car_base + data_sym, 8));
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
                        if busy_i = '1' then state <= ST_DBG_DRAIN; end if;

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
