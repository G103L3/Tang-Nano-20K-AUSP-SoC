-- ============================================================================
-- Testbench: SPI_Master (il master SPI che legge l'ADC MCP3201)
-- Scopo: catturare la waveform REALE di una transazione SPI (CS, SCK, MOSI, MISO)
-- e il flag data_ready_o.
-- Stimolo: reset, "start" lettura (reg 0x04). Un modello MISO minimale fa ruotare
-- un pattern noto (0xA5C3) ad ogni fronte di discesa di SCK, cosi' la linea MISO
-- e' deterministica rispetto a SCK e in GTKWave si vede un dato pulito.
-- Quando data_ready_o si alza, si legge il dato (reg 0x00) e si ferma (0x08).
--
-- Run:  sim/run.sh  ->  sim/tb_spi_adc.vcd
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_spi_adc is
end entity;

architecture sim of tb_spi_adc is
    constant TCLK : time := 37 ns;               -- ~27 MHz

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';             -- SPI_Master: reset ATTIVO BASSO
    signal cyc, stb, we, ack : std_logic := '0';
    signal adr   : std_logic_vector(7 downto 0)  := (others => '0');
    signal dat_i : std_logic_vector(31 downto 0) := (others => '0');
    signal dat_o : std_logic_vector(31 downto 0);
    signal mosi, sck, cs : std_logic;
    signal miso  : std_logic := '0';
    signal data_ready, dbg : std_logic;

    -- modello MISO: pattern che ruota sul fronte di discesa di SCK
    signal miso_sr : std_logic_vector(15 downto 0) := x"A5C3";
begin
    uut : entity work.SPI_Master
        port map ( clk_i => clk, rst_i => rst, cyc_i => cyc, stb_i => stb,
                   we_i => we, adr_i => adr, dat_i => dat_i, dat_o => dat_o,
                   ack_o => ack, data_ready_o => data_ready, dbg_cap_o => dbg,
                   MOSI => mosi, MISO => miso, SCK => sck, CS => cs );

    clk <= not clk after TCLK/2;

    -- MISO deterministico: MSB del pattern, ruotato ad ogni discesa di SCK
    miso <= miso_sr(15);
    miso_model : process(sck)
    begin
        if falling_edge(sck) then
            miso_sr <= miso_sr(14 downto 0) & miso_sr(15);
        end if;
    end process;

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
        rst <= '0'; wait for 10*TCLK;
        rst <= '1'; wait for 10*TCLK;

        wb_write(16#04#, 1);                     -- START una lettura SPI

        -- aspetta che il dato sia pronto (o timeout di sicurezza)
        for i in 0 to 5000 loop
            wait until rising_edge(clk);
            exit when data_ready = '1';
        end loop;

        wb_write(16#00#, 0);                     -- (read del dato -> dat_o)
        wb_write(16#08#, 1);                     -- STOP
        wb_write(16#0C#, 1);                     -- clear data_ready
        wait for 5 us;

        report "tb_spi_adc: fine simulazione" severity note;
        std.env.stop;
    end process;
end architecture;
