-- ============================================================================
-- Testbench: PWM_GENERIC (generatore DDS a due toni + inviluppo attack/release)
-- Scopo: catturare la waveform REALE del PWM dello speaker per il report.
-- Stimolo: reset, poi "start due toni" (carrier 2000 Hz + tono 3500 Hz) via
-- Wishbone (reg 0x04), si lascia suonare ~2 ms (si vede l'attacco + il regime),
-- poi "stop" (reg 0x08) per vedere il release.
--
-- GHDL dumpa in VCD TUTTI i segnali, anche gli INTERNI dell'istanza (fase DDS,
-- stato dell'inviluppo, uscita del LUT seno): in GTKWave si aprono sotto uut/.
-- Run:  vedi sim/run.sh   ->  genera sim/tb_pwm.vcd
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pwm is
end entity;

architecture sim of tb_pwm is
    constant CLK_HZ : integer := 27_000_000;
    constant TCLK   : time    := 37 ns;          -- ~27 MHz

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';             -- PWM_GENERIC: reset ATTIVO ALTO
    signal cyc, stb, we, ack : std_logic := '0';
    signal adr   : std_logic_vector(7 downto 0)  := (others => '0');
    signal dat_i : std_logic_vector(31 downto 0) := (others => '0');
    signal dat_o : std_logic_vector(31 downto 0);
    signal pwm   : std_logic;
begin
    -- Device under test
    uut : entity work.PWM_GENERIC
        generic map ( CLK_HZ => CLK_HZ, NBIT => 8, PHASE_NBITS => 24,
                      F1_DEFAULT_HZ => 0, F2_DEFAULT_HZ => 0, AUTO_START => false )
        port map ( clk_i => clk, rst_i => rst, cyc_i => cyc, stb_i => stb,
                   we_i => we, adr_i => adr, dat_i => dat_i, dat_o => dat_o,
                   ack_o => ack, PWM_o => pwm );

    clk <= not clk after TCLK/2;

    stim : process
        -- una scrittura Wishbone di 1 colpo (registro a, dato d)
        procedure wb_write(a : integer; d : std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
            adr <= std_logic_vector(to_unsigned(a, 8));
            dat_i <= d; we <= '1'; cyc <= '1'; stb <= '1';
            wait until rising_edge(clk);
            cyc <= '0'; stb <= '0'; we <= '0';
        end procedure;
    begin
        rst <= '1'; wait for 10*TCLK;
        rst <= '0'; wait for 10*TCLK;

        -- START due toni: dat[31:16] = tono 3500 Hz, dat[15:0] = carrier 2000 Hz
        wb_write(16#04#, std_logic_vector(to_unsigned(3500, 16)) &
                         std_logic_vector(to_unsigned(2000, 16)));
        wait for 2 ms;                           -- attacco + regime

        wb_write(16#08#, (others => '0'));       -- STOP -> release
        wait for 1 ms;

        report "tb_pwm: fine simulazione" severity note;
        std.env.stop;
    end process;
end architecture;
