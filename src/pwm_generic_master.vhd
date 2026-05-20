library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Generatore PWM a due toni sinusoidali sommati (DDS + sine LUT)
-- con interfaccia Wishbone.
--
-- Wishbone slave:
--   Scrittura @ 0x04: dat_i[15:0] = F1 in Hz, dat_i[31:16] = F2 in Hz
--                     -> carica le frequenze e fa partire il generatore
--                     (i parametri si aggiornano solo se start = '0', come l'originale)
--   Scrittura @ 0x08: ferma il generatore (start = 0, uscita 50% duty = DC center)
--
-- ATTENZIONE: le costanti K_RECIP e SINE_LUT sono PRECALCOLATE per:
--   CLK_HZ = 27_000_000, NBIT = 8, PHASE_NBITS = 24, FRAC_BITS = 24.
-- Il sintetizzatore Gowin/Synplify non ha ieee.math_real disponibile,
-- per cui non si possono usare sin()/round() a elaborazione: se cambi
-- uno dei parametri qui sopra DEVI rigenerare K_RECIP e SINE_LUT
-- (script Python di una decina di righe; vedi commento sotto).
entity PWM_GENERIC is
    Generic (
        CLK_HZ        : integer := 27_000_000;
        NBIT          : integer := 8;
        PHASE_NBITS   : integer := 24;
        -- Se AUTO_START = true, al reset il generatore parte da solo con
        -- le frequenze F1_DEFAULT_HZ / F2_DEFAULT_HZ. Wishbone puo' comunque
        -- fermare (0x08) o riconfigurare (stop poi 0x04) in qualsiasi momento.
        F1_DEFAULT_HZ : integer := 0;
        F2_DEFAULT_HZ : integer := 0;
        AUTO_START    : boolean := false
    );
    Port (
        clk_i : in  STD_LOGIC;
        rst_i : in  STD_LOGIC;
        cyc_i : in  STD_LOGIC;
        stb_i : in  STD_LOGIC;
        we_i  : in  STD_LOGIC;
        adr_i : in  STD_LOGIC_VECTOR(7 downto 0);
        dat_i : in  STD_LOGIC_VECTOR(31 downto 0);
        dat_o : out STD_LOGIC_VECTOR(31 downto 0);
        ack_o : out STD_LOGIC;
        PWM_o : out STD_LOGIC
    );
end PWM_GENERIC;

architecture PWM_GENERIC_BEHAVIORAL of PWM_GENERIC is

    constant F_WIDTH   : integer := 16;
    constant FRAC_BITS : integer := 24;
    constant K_WIDTH   : integer := 40;

    -- K_RECIP = round(2^(FRAC_BITS + PHASE_NBITS) / CLK_HZ)
    --        = round(2^48 / 27_000_000) = 10_424_999
    -- phase_inc = (f_hz * K_RECIP + 2^(FRAC_BITS-1)) >> FRAC_BITS
    constant K_RECIP : unsigned(K_WIDTH - 1 downto 0) :=
        to_unsigned(10_424_999, K_WIDTH);

    constant SINE_LUT_DEPTH : integer := 2**NBIT;
    type sine_lut_t is array(0 to SINE_LUT_DEPTH - 1) of unsigned(NBIT - 1 downto 0);

    -- LUT seno 256x8: mid=128, amp=127 -> valori [1..255], DC center = 128
    -- Generata con: lut[i] = round(128 + 127 * sin(2*pi*i/256))
    constant SINE_LUT : sine_lut_t := (
        to_unsigned(128, NBIT), to_unsigned(131, NBIT), to_unsigned(134, NBIT), to_unsigned(137, NBIT), to_unsigned(140, NBIT), to_unsigned(144, NBIT), to_unsigned(147, NBIT), to_unsigned(150, NBIT),
        to_unsigned(153, NBIT), to_unsigned(156, NBIT), to_unsigned(159, NBIT), to_unsigned(162, NBIT), to_unsigned(165, NBIT), to_unsigned(168, NBIT), to_unsigned(171, NBIT), to_unsigned(174, NBIT),
        to_unsigned(177, NBIT), to_unsigned(179, NBIT), to_unsigned(182, NBIT), to_unsigned(185, NBIT), to_unsigned(188, NBIT), to_unsigned(191, NBIT), to_unsigned(193, NBIT), to_unsigned(196, NBIT),
        to_unsigned(199, NBIT), to_unsigned(201, NBIT), to_unsigned(204, NBIT), to_unsigned(206, NBIT), to_unsigned(209, NBIT), to_unsigned(211, NBIT), to_unsigned(213, NBIT), to_unsigned(216, NBIT),
        to_unsigned(218, NBIT), to_unsigned(220, NBIT), to_unsigned(222, NBIT), to_unsigned(224, NBIT), to_unsigned(226, NBIT), to_unsigned(228, NBIT), to_unsigned(230, NBIT), to_unsigned(232, NBIT),
        to_unsigned(234, NBIT), to_unsigned(235, NBIT), to_unsigned(237, NBIT), to_unsigned(239, NBIT), to_unsigned(240, NBIT), to_unsigned(241, NBIT), to_unsigned(243, NBIT), to_unsigned(244, NBIT),
        to_unsigned(245, NBIT), to_unsigned(246, NBIT), to_unsigned(248, NBIT), to_unsigned(249, NBIT), to_unsigned(250, NBIT), to_unsigned(250, NBIT), to_unsigned(251, NBIT), to_unsigned(252, NBIT),
        to_unsigned(253, NBIT), to_unsigned(253, NBIT), to_unsigned(254, NBIT), to_unsigned(254, NBIT), to_unsigned(254, NBIT), to_unsigned(255, NBIT), to_unsigned(255, NBIT), to_unsigned(255, NBIT),
        to_unsigned(255, NBIT), to_unsigned(255, NBIT), to_unsigned(255, NBIT), to_unsigned(255, NBIT), to_unsigned(254, NBIT), to_unsigned(254, NBIT), to_unsigned(254, NBIT), to_unsigned(253, NBIT),
        to_unsigned(253, NBIT), to_unsigned(252, NBIT), to_unsigned(251, NBIT), to_unsigned(250, NBIT), to_unsigned(250, NBIT), to_unsigned(249, NBIT), to_unsigned(248, NBIT), to_unsigned(246, NBIT),
        to_unsigned(245, NBIT), to_unsigned(244, NBIT), to_unsigned(243, NBIT), to_unsigned(241, NBIT), to_unsigned(240, NBIT), to_unsigned(239, NBIT), to_unsigned(237, NBIT), to_unsigned(235, NBIT),
        to_unsigned(234, NBIT), to_unsigned(232, NBIT), to_unsigned(230, NBIT), to_unsigned(228, NBIT), to_unsigned(226, NBIT), to_unsigned(224, NBIT), to_unsigned(222, NBIT), to_unsigned(220, NBIT),
        to_unsigned(218, NBIT), to_unsigned(216, NBIT), to_unsigned(213, NBIT), to_unsigned(211, NBIT), to_unsigned(209, NBIT), to_unsigned(206, NBIT), to_unsigned(204, NBIT), to_unsigned(201, NBIT),
        to_unsigned(199, NBIT), to_unsigned(196, NBIT), to_unsigned(193, NBIT), to_unsigned(191, NBIT), to_unsigned(188, NBIT), to_unsigned(185, NBIT), to_unsigned(182, NBIT), to_unsigned(179, NBIT),
        to_unsigned(177, NBIT), to_unsigned(174, NBIT), to_unsigned(171, NBIT), to_unsigned(168, NBIT), to_unsigned(165, NBIT), to_unsigned(162, NBIT), to_unsigned(159, NBIT), to_unsigned(156, NBIT),
        to_unsigned(153, NBIT), to_unsigned(150, NBIT), to_unsigned(147, NBIT), to_unsigned(144, NBIT), to_unsigned(140, NBIT), to_unsigned(137, NBIT), to_unsigned(134, NBIT), to_unsigned(131, NBIT),
        to_unsigned(128, NBIT), to_unsigned(125, NBIT), to_unsigned(122, NBIT), to_unsigned(119, NBIT), to_unsigned(116, NBIT), to_unsigned(112, NBIT), to_unsigned(109, NBIT), to_unsigned(106, NBIT),
        to_unsigned(103, NBIT), to_unsigned(100, NBIT), to_unsigned(97,  NBIT), to_unsigned(94,  NBIT), to_unsigned(91,  NBIT), to_unsigned(88,  NBIT), to_unsigned(85,  NBIT), to_unsigned(82,  NBIT),
        to_unsigned(79,  NBIT), to_unsigned(77,  NBIT), to_unsigned(74,  NBIT), to_unsigned(71,  NBIT), to_unsigned(68,  NBIT), to_unsigned(65,  NBIT), to_unsigned(63,  NBIT), to_unsigned(60,  NBIT),
        to_unsigned(57,  NBIT), to_unsigned(55,  NBIT), to_unsigned(52,  NBIT), to_unsigned(50,  NBIT), to_unsigned(47,  NBIT), to_unsigned(45,  NBIT), to_unsigned(43,  NBIT), to_unsigned(40,  NBIT),
        to_unsigned(38,  NBIT), to_unsigned(36,  NBIT), to_unsigned(34,  NBIT), to_unsigned(32,  NBIT), to_unsigned(30,  NBIT), to_unsigned(28,  NBIT), to_unsigned(26,  NBIT), to_unsigned(24,  NBIT),
        to_unsigned(22,  NBIT), to_unsigned(21,  NBIT), to_unsigned(19,  NBIT), to_unsigned(17,  NBIT), to_unsigned(16,  NBIT), to_unsigned(15,  NBIT), to_unsigned(13,  NBIT), to_unsigned(12,  NBIT),
        to_unsigned(11,  NBIT), to_unsigned(10,  NBIT), to_unsigned(8,   NBIT), to_unsigned(7,   NBIT), to_unsigned(6,   NBIT), to_unsigned(6,   NBIT), to_unsigned(5,   NBIT), to_unsigned(4,   NBIT),
        to_unsigned(3,   NBIT), to_unsigned(3,   NBIT), to_unsigned(2,   NBIT), to_unsigned(2,   NBIT), to_unsigned(2,   NBIT), to_unsigned(1,   NBIT), to_unsigned(1,   NBIT), to_unsigned(1,   NBIT),
        to_unsigned(1,   NBIT), to_unsigned(1,   NBIT), to_unsigned(1,   NBIT), to_unsigned(1,   NBIT), to_unsigned(2,   NBIT), to_unsigned(2,   NBIT), to_unsigned(2,   NBIT), to_unsigned(3,   NBIT),
        to_unsigned(3,   NBIT), to_unsigned(4,   NBIT), to_unsigned(5,   NBIT), to_unsigned(6,   NBIT), to_unsigned(6,   NBIT), to_unsigned(7,   NBIT), to_unsigned(8,   NBIT), to_unsigned(10,  NBIT),
        to_unsigned(11,  NBIT), to_unsigned(12,  NBIT), to_unsigned(13,  NBIT), to_unsigned(15,  NBIT), to_unsigned(16,  NBIT), to_unsigned(17,  NBIT), to_unsigned(19,  NBIT), to_unsigned(21,  NBIT),
        to_unsigned(22,  NBIT), to_unsigned(24,  NBIT), to_unsigned(26,  NBIT), to_unsigned(28,  NBIT), to_unsigned(30,  NBIT), to_unsigned(32,  NBIT), to_unsigned(34,  NBIT), to_unsigned(36,  NBIT),
        to_unsigned(38,  NBIT), to_unsigned(40,  NBIT), to_unsigned(43,  NBIT), to_unsigned(45,  NBIT), to_unsigned(47,  NBIT), to_unsigned(50,  NBIT), to_unsigned(52,  NBIT), to_unsigned(55,  NBIT),
        to_unsigned(57,  NBIT), to_unsigned(60,  NBIT), to_unsigned(63,  NBIT), to_unsigned(65,  NBIT), to_unsigned(68,  NBIT), to_unsigned(71,  NBIT), to_unsigned(74,  NBIT), to_unsigned(77,  NBIT),
        to_unsigned(79,  NBIT), to_unsigned(82,  NBIT), to_unsigned(85,  NBIT), to_unsigned(88,  NBIT), to_unsigned(91,  NBIT), to_unsigned(94,  NBIT), to_unsigned(97,  NBIT), to_unsigned(100, NBIT),
        to_unsigned(103, NBIT), to_unsigned(106, NBIT), to_unsigned(109, NBIT), to_unsigned(112, NBIT), to_unsigned(116, NBIT), to_unsigned(119, NBIT), to_unsigned(122, NBIT), to_unsigned(125, NBIT)
    );

    -- Registri configurabili via Wishbone
    signal f1_hz_r : unsigned(F_WIDTH - 1 downto 0) := (others => '0');
    signal f2_hz_r : unsigned(F_WIDTH - 1 downto 0) := (others => '0');
    signal start_r : std_logic := '0';
    signal stb_old : std_logic := '0';

    -- Calcolo phase increment (combinazionale)
    signal mul_1       : unsigned(F_WIDTH + K_WIDTH - 1 downto 0);
    signal mul_2       : unsigned(F_WIDTH + K_WIDTH - 1 downto 0);
    signal phase_inc_1 : unsigned(PHASE_NBITS - 1 downto 0);
    signal phase_inc_2 : unsigned(PHASE_NBITS - 1 downto 0);

    -- DDS + PWM
    signal phase_1    : unsigned(PHASE_NBITS - 1 downto 0) := (others => '0');
    signal phase_2    : unsigned(PHASE_NBITS - 1 downto 0) := (others => '0');
    signal sin_1_s    : unsigned(NBIT - 1 downto 0);
    signal sin_2_s    : unsigned(NBIT - 1 downto 0);
    signal duty_sum_s : unsigned(NBIT downto 0);
    signal duty_s     : unsigned(NBIT - 1 downto 0);
    signal pwm_cnt_s  : unsigned(NBIT - 1 downto 0) := (others => '0');
    signal pwm_int_s  : std_logic := '0';

begin
    dat_o <= (others => '0');

    -- Wishbone slave (reset attivo basso)
    wb_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack_o   <= '0';
                stb_old <= '0';
                if AUTO_START then
                    start_r <= '1';
                    f1_hz_r <= to_unsigned(F1_DEFAULT_HZ, F_WIDTH);
                    f2_hz_r <= to_unsigned(F2_DEFAULT_HZ, F_WIDTH);
                else
                    start_r <= '0';
                    f1_hz_r <= (others => '0');
                    f2_hz_r <= (others => '0');
                end if;
            else
                ack_o   <= '0';
                stb_old <= stb_i;
                if cyc_i = '1' and stb_i = '1' and stb_old = '0' then
                    if we_i = '1' then
                        if adr_i = x"04" then
                            if start_r = '0' then
                                f1_hz_r <= unsigned(dat_i(F_WIDTH - 1 downto 0));
                                f2_hz_r <= unsigned(dat_i(2*F_WIDTH - 1 downto F_WIDTH));
                                start_r <= '1';
                            end if;
                        elsif adr_i = x"08" then
                            start_r <= '0';
                        end if;
                    end if;
                    ack_o <= '1';
                end if;
            end if;
        end if;
    end process;

    -- phase_inc = round(f_hz * 2^PHASE_NBITS / CLK_HZ)
    mul_1 <= f1_hz_r * K_RECIP;
    mul_2 <= f2_hz_r * K_RECIP;

    phase_inc_1 <= resize(
        shift_right(mul_1 + to_unsigned(2**(FRAC_BITS - 1), mul_1'length), FRAC_BITS),
        PHASE_NBITS);
    phase_inc_2 <= resize(
        shift_right(mul_2 + to_unsigned(2**(FRAC_BITS - 1), mul_2'length), FRAC_BITS),
        PHASE_NBITS);

    -- Phase accumulators: corrono solo se start = '1', altrimenti a 0
    -- (sin(0) = mid -> duty 50% -> nessun AC dopo RC)
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' or start_r = '0' then
                phase_1 <= (others => '0');
                phase_2 <= (others => '0');
            else
                phase_1 <= phase_1 + phase_inc_1;
                phase_2 <= phase_2 + phase_inc_2;
            end if;
        end if;
    end process;

    sin_1_s <= SINE_LUT(to_integer(phase_1(PHASE_NBITS - 1 downto PHASE_NBITS - NBIT)));
    sin_2_s <= SINE_LUT(to_integer(phase_2(PHASE_NBITS - 1 downto PHASE_NBITS - NBIT)));

    duty_sum_s <= ('0' & sin_1_s) + ('0' & sin_2_s);
    duty_s     <= duty_sum_s(NBIT downto 1);

    -- Comparatore PWM free-running -> carrier = CLK_HZ / 2^NBIT
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                pwm_cnt_s <= (others => '0');
                pwm_int_s <= '0';
            else
                pwm_cnt_s <= pwm_cnt_s + 1;
                if pwm_cnt_s < duty_s then
                    pwm_int_s <= '1';
                else
                    pwm_int_s <= '0';
                end if;
            end if;
        end if;
    end process;

    PWM_o <= pwm_int_s;

end PWM_GENERIC_BEHAVIORAL;
