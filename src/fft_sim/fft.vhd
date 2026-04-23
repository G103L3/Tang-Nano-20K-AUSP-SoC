library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- Behavioral 512-point DIT Radix-2 FFT per simulazione GHDL.
-- Stessa interfaccia del Gowin FFT_Top (fft_tmp.vhd).
-- Scaling RS111: right-shift 1 bit per stage (9 stage totali → 9 bit di shift).
-- Input  : 512 campioni reali 16-bit (xn_im ignorato, sempre 0 dal DMA).
-- Output : 512 bin complessi (xk_re, xk_im) 16-bit + idx 9-bit.
--
-- Protocollo:
--   start='1'  → avvio acquisizione campioni
--   ipd='1'    → FFT segnala "sto leggendo xn_re ora, campione acquisito"
--   eod='1'    → pulsato insieme all'ultimo ipd (campione 511)
--   busy='1'   → calcolo FFT in corso (1 ciclo di clock)
--   opd='1'    → bin xk_re/xk_im/idx validi (1 bin per ciclo)
--   eoud='1'   → pulsato insieme all'ultimo opd (bin 511)
--
-- Nota: ipd viene pulsato ad ogni ciclo mentre il DMA tiene start='1'.
-- Il DMA deve avere xn_re valido prima che ipd arrivi; questo è garantito
-- dalla sequenza S_FFT_READ1 → S_FFT_READ2 del DMA.

entity FFT_Top is
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
end FFT_Top;

architecture behavioral of FFT_Top is

    constant N     : integer := 512;
    constant LOG2N : integer := 9;

    type int_array_t is array (0 to N-1) of integer;

    -- Bit-reversal permutation index
    function bit_rev(x : integer; bits : integer) return integer is
        variable v   : unsigned(bits-1 downto 0);
        variable res : unsigned(bits-1 downto 0);
    begin
        v := to_unsigned(x, bits);
        for i in 0 to bits-1 loop
            res(i) := v(bits-1-i);
        end loop;
        return to_integer(res);
    end function;

    -- Arithmetic right-shift by 1 (floor division by 2)
    function shr1(x : integer) return integer is
    begin
        if x >= 0 then
            return x / 2;
        else
            -- VHDL integer division truncates toward zero; compensate for negative
            if (x mod 2) /= 0 then
                return (x - 1) / 2;
            else
                return x / 2;
            end if;
        end if;
    end function;

    type state_t is (S_IDLE, S_INPUT, S_COMPUTE, S_OUTPUT);
    signal state   : state_t := S_IDLE;
    signal in_cnt  : integer range 0 to N := 0;
    signal out_cnt : integer range 0 to N := 0;

    -- Input sample buffer (written during S_INPUT)
    signal buf_re  : int_array_t := (others => 0);
    signal buf_im  : int_array_t := (others => 0);

    -- FFT result buffer (written during S_COMPUTE, read during S_OUTPUT)
    signal fft_re  : int_array_t := (others => 0);
    signal fft_im  : int_array_t := (others => 0);

begin

    process(clk)
        -- Variables for in-process FFT computation (all in one clock cycle)
        variable vr    : int_array_t;
        variable vi    : int_array_t;
        variable ar, ai, br, bi, pr, pi : integer;
        variable angle : real;
        variable wr, wi : real;
        variable stride, half, k : integer;
    begin
        if rising_edge(clk) then
            -- Output defaults (overridden below)
            sod  <= '0';
            ipd  <= '0';
            eod  <= '0';
            busy <= '0';
            soud <= '0';
            opd  <= '0';
            eoud <= '0';
            idx   <= (others => '0');
            xk_re <= (others => '0');
            xk_im <= (others => '0');

            if rst = '0' then
                state   <= S_IDLE;
                in_cnt  <= 0;
                out_cnt <= 0;
            else
                case state is

                    -- ----------------------------------------------------------------
                    -- S_IDLE: attende il primo strobe start='1' dal DMA.
                    -- Al primo start='1' latcha il campione 0 (xn_re valido in quel ciclo)
                    -- e pulsa ipd='1' + sod='1', poi passa a S_INPUT con in_cnt=1.
                    when S_IDLE =>
                        in_cnt  <= 0;
                        out_cnt <= 0;
                        if start = '1' then
                            sod           <= '1';
                            ipd           <= '1';
                            buf_re(0)     <= to_integer(signed(xn_re));
                            buf_im(0)     <= to_integer(signed(xn_im));
                            in_cnt        <= 1;
                            state         <= S_INPUT;
                        end if;

                    -- ----------------------------------------------------------------
                    -- S_INPUT: avanza in_cnt SOLO quando start='1' (strobe dal DMA).
                    -- Il DMA garantisce che xn_re sia valido nel ciclo in cui start='1'.
                    -- ipd='1' viene pulsato sullo stesso ciclo di start='1'.
                    when S_INPUT =>
                        if start = '1' then
                            ipd <= '1';
                            buf_re(in_cnt) <= to_integer(signed(xn_re));
                            buf_im(in_cnt) <= to_integer(signed(xn_im));
                            if in_cnt = N-1 then
                                eod    <= '1';
                                state  <= S_COMPUTE;
                                in_cnt <= 0;
                            else
                                state <= S_INPUT;
                                in_cnt <= in_cnt + 1;
                            end if;
                        end if;

                    -- ----------------------------------------------------------------
                    -- Calcolo FFT DIT Radix-2, scala RS111 (shr 1 bit per stage).
                    -- Tutto in un singolo ciclo di clock (variabili, non segnali).
                    when S_COMPUTE =>
                        busy <= '1';

                        -- Copy signal arrays to variables for in-process computation
                        vr := buf_re;
                        vi := buf_im;

                        -- Bit-reversal permutation
                        for i in 0 to N-1 loop
                            k := bit_rev(i, LOG2N);
                            if k > i then
                                ar := vr(i); ai := vi(i);
                                vr(i) := vr(k); vi(i) := vi(k);
                                vr(k) := ar;    vi(k) := ai;
                            end if;
                        end loop;

                        -- 9 butterfly stages (DIT)
                        stride := 2;
                        for stage in 0 to LOG2N-1 loop
                            half := stride / 2;
                            for grp in 0 to (N/stride)-1 loop
                                for m in 0 to half-1 loop
                                    k     := grp * stride + m;
                                    angle := -2.0 * MATH_PI * real(m) / real(stride);
                                    wr    := cos(angle);
                                    wi    := sin(angle);
                                    ar := vr(k);       ai := vi(k);
                                    br := vr(k + half); bi := vi(k + half);
                                    -- Twiddle multiply (real arithmetic, no fixed-point quantization)
                                    pr := integer(real(br)*wr - real(bi)*wi);
                                    pi := integer(real(br)*wi + real(bi)*wr);
                                    -- Butterfly
                                    vr(k)        := ar + pr;
                                    vi(k)        := ai + pi;
                                    vr(k + half) := ar - pr;
                                    vi(k + half) := ai - pi;
                                end loop;
                            end loop;
                            -- RS111: right-shift 1 bit per stage (block floating point)
                            for i in 0 to N-1 loop
                                vr(i) := shr1(vr(i));
                                vi(i) := shr1(vi(i));
                            end loop;
                            stride := stride * 2;
                        end loop;

                        -- Store results into signals (visible next cycle)
                        fft_re  <= vr;
                        fft_im  <= vi;
                        out_cnt <= 0;
                        state   <= S_OUTPUT;

                    -- ----------------------------------------------------------------
                    -- Streaming output: 1 bin per ciclo, opd='1' per ogni bin.
                    when S_OUTPUT =>
                        opd <= '1';
                        if out_cnt = 0 then
                            soud <= '1';
                        end if;
                        if out_cnt = N-1 then
                            eoud <= '1';
                        end if;
                        idx   <= std_logic_vector(to_unsigned(out_cnt, 9));
                        xk_re <= std_logic_vector(to_signed(fft_re(out_cnt), 16));
                        xk_im <= std_logic_vector(to_signed(fft_im(out_cnt), 16));

                        if out_cnt = N-1 then
                            state <= S_IDLE;
                        else
                            out_cnt <= out_cnt + 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

end behavioral;
