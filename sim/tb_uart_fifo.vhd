-- ============================================================================
-- Testbench: FIFO RX di UART_GENERIC (fix comandi NOR multi-byte).
-- Caso reale che falliva: l'ESP32 manda 'G'+3 byte back-to-back (87 us l'uno)
-- mentre la CPU e' occupata altrove; col registro singolo il comando veniva
-- sovrascritto dal payload. Qui: 4 byte in raffica SENZA letture, poi 4 letture
-- WB che devono restituirli IN ORDINE con bit8=1, e una 5a con bit8=0.
-- Run: ghdl -a --std=08 src/uart_generic.vhd sim/tb_uart_fifo.vhd
--      ghdl -e --std=08 tb_uart_fifo && ghdl -r --std=08 tb_uart_fifo
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart_fifo is
end entity;

architecture sim of tb_uart_fifo is
    constant TCLK : time := 37 ns;               -- ~27 MHz
    constant DIV  : integer := 234;              -- 27e6 / 115200
    constant TBIT : time := TCLK * DIV;

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';
    signal cyc, stb, we, ack : std_logic := '0';
    signal adr   : std_logic_vector(7 downto 0)  := (others => '0');
    signal dat_i : std_logic_vector(31 downto 0) := (others => '0');
    signal dat_o : std_logic_vector(31 downto 0);
    signal tx    : std_logic;
    signal rx    : std_logic := '1';
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

        procedure wb_read(a : integer; d : out std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
            adr <= std_logic_vector(to_unsigned(a, 8));
            we <= '0'; cyc <= '1'; stb <= '1';
            loop
                wait until rising_edge(clk);
                if ack = '1' then d := dat_o; exit; end if;
            end loop;
            cyc <= '0'; stb <= '0';
        end procedure;

        procedure uart_send(b : integer) is
            variable v : std_logic_vector(7 downto 0);
        begin
            v := std_logic_vector(to_unsigned(b, 8));
            rx <= '0';                            -- start
            wait for TBIT;
            for i in 0 to 7 loop                  -- LSB first
                rx <= v(i);
                wait for TBIT;
            end loop;
            rx <= '1';                            -- stop
            wait for TBIT;
        end procedure;

        variable d : std_logic_vector(31 downto 0);
    begin
        rst <= '0'; wait for 10*TCLK;
        rst <= '1'; wait for 10*TCLK;

        wb_write(16#08#, 0);
        wb_write(16#0C#, DIV);
        wb_write(16#10#, 16#18#);
        wb_write(16#04#, 1);

        -- raffica back-to-back senza letture (CPU "occupata")
        uart_send(16#47#);                        -- 'G'
        uart_send(16#12#);
        uart_send(16#34#);
        uart_send(16#04#);
        wait for 20*TCLK;

        wb_read(16#14#, d);                       -- STATUS: rx_valid atteso 1
        assert d(1) = '1' report "STATUS.rx_valid=0 dopo la raffica" severity failure;

        wb_read(16#00#, d);
        assert d(8) = '1' and d(7 downto 0) = x"47"
            report "byte 1 errato (atteso 0x47)" severity failure;
        wb_read(16#00#, d);
        assert d(8) = '1' and d(7 downto 0) = x"12"
            report "byte 2 errato (atteso 0x12)" severity failure;
        wb_read(16#00#, d);
        assert d(8) = '1' and d(7 downto 0) = x"34"
            report "byte 3 errato (atteso 0x34)" severity failure;
        wb_read(16#00#, d);
        assert d(8) = '1' and d(7 downto 0) = x"04"
            report "byte 4 errato (atteso 0x04)" severity failure;

        wb_read(16#00#, d);                       -- FIFO vuota
        assert d(8) = '0' report "bit8=1 a FIFO vuota" severity failure;
        wb_read(16#14#, d);
        assert d(1) = '0' report "STATUS.rx_valid=1 a FIFO vuota" severity failure;

        -- byte singolo dopo lo svuotamento: percorso normale ancora ok
        uart_send(16#41#);
        wait for 20*TCLK;
        wb_read(16#00#, d);
        assert d(8) = '1' and d(7 downto 0) = x"41"
            report "byte singolo post-svuotamento errato" severity failure;

        report "tb_uart_fifo: PASS" severity note;
        std.env.stop;
    end process;
end architecture;
