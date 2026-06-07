-- ============================================================================
-- Testbench: accesso alla RAM (SDRAM) lato utente del controller.
-- Usa il modello comportamentale sdram_sip_model (il controller vero e' un IP
-- Verilog non simulabile da GHDL): mostra la FORMA REALE del protocollo che la
-- FSM tst_ e il DMA usano per parlare con la SDRAM:
--   init_done -> WRITE burst (wr_n + addr + data + wrd_ack) -> READ burst
--   (rd_n + addr, poi rd_valid + O_sdrc_data per ogni parola).
-- Burst di 8 parole (data_len=8) per un diagramma pulito.
--
-- Run:  sim/run.sh  ->  sim/tb_sdram.vcd
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_sdram is
end entity;

architecture sim of tb_sdram is
    constant TCLK : time    := 25 ns;            -- ~40 MHz (clock SDRAM)
    constant LEN  : integer := 8;

    signal clk    : std_logic := '0';
    signal rst_n  : std_logic := '0';
    signal wr_n   : std_logic := '1';
    signal rd_n   : std_logic := '1';
    signal addr   : std_logic_vector(20 downto 0) := (others => '0');
    signal wdata  : std_logic_vector(31 downto 0) := (others => '0');
    signal dlen   : std_logic_vector(7 downto 0)  := std_logic_vector(to_unsigned(LEN, 8));
    signal rdata  : std_logic_vector(31 downto 0);
    signal init_done, busy_n, rd_valid, wrd_ack : std_logic;
begin
    uut : entity work.sdram_sip_model
        generic map ( INIT_CYCLES => 64, RD_LAT => 3, MEM_WORDS => 1024 )
        port map (
            I_sdrc_rst_n => rst_n, I_sdrc_clk => clk,
            I_sdrc_wr_n => wr_n, I_sdrc_rd_n => rd_n,
            I_sdrc_addr => addr, I_sdrc_data => wdata, I_sdrc_data_len => dlen,
            O_sdrc_data => rdata, O_sdrc_init_done => init_done,
            O_sdrc_busy_n => busy_n, O_sdrc_rd_valid => rd_valid,
            O_sdrc_wrd_ack => wrd_ack );

    clk <= not clk after TCLK/2;

    stim : process
    begin
        rst_n <= '0'; wait for 10*TCLK;
        rst_n <= '1';

        -- attende la fine dell'inizializzazione SDRAM (init_done sale dopo INIT_CYCLES).
        -- attesa a durata fissa per evitare wait-condition impiantabili.
        wait for 80*TCLK;                        -- > INIT_CYCLES(64)
        wait until rising_edge(clk);

        -- ---- WRITE burst di LEN parole all'indirizzo 0x000 ----
        addr  <= (others => '0');
        wdata <= x"0000_0100";
        wr_n  <= '0';                            -- 1 colpo: avvia il burst di scrittura
        wait until rising_edge(clk);
        wr_n  <= '1';
        for i in 0 to LEN-1 loop                 -- streaming dei dati (incrementali)
            wdata <= std_logic_vector(to_unsigned(16#100# + i, 32));
            wait until rising_edge(clk);
        end loop;
        wait for 10*TCLK;                        -- lascia chiudere il write, torna ready

        -- ---- READ burst dallo stesso indirizzo ----
        addr <= (others => '0');
        rd_n <= '0';                             -- 1 colpo: avvia il burst di lettura
        wait until rising_edge(clk);
        rd_n <= '1';
        -- abbastanza per latenza (RD_LAT) + LEN parole di rd_valid + margine
        wait for (LEN + 3 + 8)*TCLK;

        wait for 8*TCLK;
        report "tb_sdram: fine simulazione" severity note;
        std.env.stop;
    end process;
end architecture;
