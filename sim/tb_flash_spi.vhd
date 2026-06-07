-- ============================================================================
-- Testbench: SPI_Flash (il motore SPI a byte che flash_ctrl usa per il W25Q)
-- Scopo: catturare la waveform REALE di un trasferimento SPI a 8 bit della NOR:
-- MOSI, SCK, MISO, busy_o, done_o e il byte ricevuto rx_o. PRESCALER=64 come nel
-- progetto (SCK = clk/64). Mode 0, MSB first.
-- Stimolo: invia il comando JEDEC 0x9F, poi tre byte dummy 0x00 per leggere la
-- risposta; un modello MISO minimale presenta 0xEF,0x40,0x17 (l'ID Winbond W25Q64)
-- ruotando un pattern sul fronte di discesa di SCK.
--
-- Run:  sim/run.sh  ->  sim/tb_flash_spi.vcd
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_flash_spi is
end entity;

architecture sim of tb_flash_spi is
    constant TCLK : time := 37 ns;               -- ~27 MHz

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';             -- SPI_Flash: reset ATTIVO BASSO
    signal start : std_logic := '0';
    signal txb   : std_logic_vector(7 downto 0) := (others => '0');
    signal rxb   : std_logic_vector(7 downto 0);
    signal busy, done : std_logic;
    signal mosi, sck  : std_logic;
    signal miso  : std_logic := '0';

    -- modello MISO: presenta l'ID JEDEC del W25Q64 (EF 40 17), MSB first,
    -- ruotando sul fronte di discesa di SCK (mode 0: master campiona in salita).
    signal miso_sr : std_logic_vector(23 downto 0) := x"EF4017";
begin
    uut : entity work.SPI_Flash
        generic map ( PRESCALER => 64 )
        port map ( clk_i => clk, rst_i => rst, start_i => start, tx_i => txb,
                   rx_o => rxb, busy_o => busy, done_o => done,
                   MOSI => mosi, MISO => miso, SCK => sck );

    clk  <= not clk after TCLK/2;
    miso <= miso_sr(23);
    miso_model : process(sck)
    begin
        if falling_edge(sck) then
            miso_sr <= miso_sr(22 downto 0) & miso_sr(23);
        end if;
    end process;

    stim : process
        -- invia un byte: pulsa start_i con tx_i=b, aspetta done_o
        procedure spi_byte(b : integer) is
        begin
            wait until rising_edge(clk);
            txb <= std_logic_vector(to_unsigned(b, 8));
            start <= '1';
            wait until rising_edge(clk);
            start <= '0';
            wait until done = '1';
            wait until rising_edge(clk);
        end procedure;
    begin
        rst <= '0'; wait for 10*TCLK;
        rst <= '1'; wait for 10*TCLK;

        spi_byte(16#9F#);                        -- comando JEDEC ID
        spi_byte(16#00#);                        -- dummy -> rx = 0xEF
        spi_byte(16#00#);                        -- dummy -> rx = 0x40
        spi_byte(16#00#);                        -- dummy -> rx = 0x17
        wait for 5 us;

        report "tb_flash_spi: fine simulazione" severity note;
        std.env.stop;
    end process;
end architecture;
