-- ============================================================================
-- Testbench: UART_GENERIC (la UART caratteri verso l'ESP32, pin 17/18)
-- Scopo: catturare la waveform REALE di un frame UART trasmesso (TX_o).
-- Stimolo: reset, configura baud (div = 27MHz/115200 = 234) e formato 8N1,
-- abilita, poi trasmette il byte 0x55 ('U', bit alternati -> frame ben leggibile)
-- e subito dopo 'a' (0x61, simbolo "master bit0" del protocollo).
--
-- In GTKWave: TX_o mostra start-bit(0) + 8 bit LSB-first + stop(1). I segnali
-- interni (tx_busy, baud counter, shift register) sono sotto uut/.
-- Run:  sim/run.sh  ->  sim/tb_uart.vcd
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart is
end entity;

architecture sim of tb_uart is
    constant TCLK : time := 37 ns;               -- ~27 MHz
    constant DIV  : integer := 234;              -- 27e6 / 115200

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';             -- UART_GENERIC: reset ATTIVO BASSO
    signal cyc, stb, we, ack : std_logic := '0';
    signal adr   : std_logic_vector(7 downto 0)  := (others => '0');
    signal dat_i : std_logic_vector(31 downto 0) := (others => '0');
    signal dat_o : std_logic_vector(31 downto 0);
    signal tx    : std_logic;
    signal rx    : std_logic := '1';             -- linea RX a riposo (idle alto)
begin
    uut : entity work.UART_GENERIC
        port map ( clk_i => clk, rst_i => rst, cyc_i => cyc, stb_i => stb,
                   we_i => we, adr_i => adr, dat_i => dat_i, dat_o => dat_o,
                   ack_o => ack, TX_o => tx, RX_i => rx );

    clk <= not clk after TCLK/2;

    stim : process
        procedure wb_write(a : integer; d : integer) is
        begin
            wait until rising_edge(clk);
            adr <= std_logic_vector(to_unsigned(a, 8));
            dat_i <= std_logic_vector(to_unsigned(d, 32));
            we <= '1'; cyc <= '1'; stb <= '1';
            wait until rising_edge(clk);
            cyc <= '0'; stb <= '0'; we <= '0';
        end procedure;
    begin
        rst <= '0'; wait for 10*TCLK;            -- reset attivo basso
        rst <= '1'; wait for 10*TCLK;

        wb_write(16#08#, 0);                     -- STOP (riconfig pulita)
        wb_write(16#0C#, DIV);                   -- baud divider
        wb_write(16#10#, 16#18#);                -- CFG: 8 bit dati, no parity, 1 stop
        wb_write(16#04#, 1);                     -- START (abilita)

        wb_write(16#00#, 16#55#);                -- TX 'U' (0x55, bit alternati)
        wait for 110 us;                         -- ~1 byte @115200 = 87 us

        wb_write(16#00#, 16#61#);                -- TX 'a' (simbolo protocollo)
        wait for 110 us;

        report "tb_uart: fine simulazione" severity note;
        std.env.stop;
    end process;
end architecture;
