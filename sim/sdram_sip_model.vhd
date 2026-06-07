-- ============================================================================
-- Modello COMPORTAMENTALE dell'interfaccia utente del controller SDRAM Gowin
-- (SDRAM_controller_top_SIP, lato "HS"). Serve SOLO per la simulazione GHDL:
-- il controller vero e' un IP Verilog (non simulabile da GHDL, che e' solo-VHDL),
-- quindi qui riproduco il CONTRATTO lato utente che la FSM tst_ e il DMA usano
-- davvero, con una piccola memoria interna dietro.
--
-- Protocollo (semplificato ma fedele nello schema):
--   * dopo il reset, init_done sale dopo INIT_CYCLES.
--   * busy_n = 1 quando il controller e' pronto ad accettare un comando.
--   * WRITE burst: l'utente pulsa wr_n=0 con addr; per data_len colpi il modello
--                  alza wrd_ack e cattura I_sdrc_data in memoria (addr+i).
--   * READ  burst: l'utente pulsa rd_n=0 con addr; dopo RD_LAT colpi il modello
--                  alza rd_valid e presenta mem(addr+i) su O_sdrc_data per data_len.
-- NB: le LATENZE esatte del SIP reale differiscono; qui sono ragionevoli e servono
-- a mostrare la FORMA dell'accesso (handshake init/busy/ack/valid), non i ns esatti.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdram_sip_model is
    generic (
        INIT_CYCLES : natural := 64;     -- cicli di "inizializzazione" prima di init_done
        RD_LAT      : natural := 3;      -- latenza comando->primo dato in lettura
        MEM_WORDS   : natural := 1024
    );
    port (
        I_sdrc_rst_n     : in  std_logic;
        I_sdrc_clk       : in  std_logic;
        I_sdrc_wr_n      : in  std_logic;
        I_sdrc_rd_n      : in  std_logic;
        I_sdrc_addr      : in  std_logic_vector(20 downto 0);
        I_sdrc_data      : in  std_logic_vector(31 downto 0);
        I_sdrc_data_len  : in  std_logic_vector(7 downto 0);
        O_sdrc_data      : out std_logic_vector(31 downto 0);
        O_sdrc_init_done : out std_logic;
        O_sdrc_busy_n    : out std_logic;
        O_sdrc_rd_valid  : out std_logic;
        O_sdrc_wrd_ack   : out std_logic
    );
end entity;

architecture beh of sdram_sip_model is
    type mem_t is array(0 to MEM_WORDS-1) of std_logic_vector(31 downto 0);
    signal mem : mem_t := (others => (others => '0'));

    type st_t is (ST_INIT, ST_READY, ST_WRITE, ST_READ);
    signal st       : st_t := ST_INIT;
    signal init_cnt : natural range 0 to INIT_CYCLES := 0;
    signal base     : natural range 0 to MEM_WORDS-1 := 0;
    signal len      : natural range 0 to 255 := 0;
    signal cnt      : natural range 0 to 255 := 0;
    signal lat      : natural range 0 to 15 := 0;

    function idx(b, i : natural) return natural is
    begin
        return (b + i) mod MEM_WORDS;
    end function;
begin
    process(I_sdrc_clk)
    begin
        if rising_edge(I_sdrc_clk) then
            -- default dei pulse
            O_sdrc_wrd_ack  <= '0';
            O_sdrc_rd_valid <= '0';

            if I_sdrc_rst_n = '0' then
                st <= ST_INIT; init_cnt <= 0; cnt <= 0; lat <= 0;
                O_sdrc_init_done <= '0';
                O_sdrc_busy_n    <= '0';
                O_sdrc_data      <= (others => '0');
            else
                case st is
                    when ST_INIT =>
                        O_sdrc_busy_n <= '0';
                        if init_cnt = INIT_CYCLES then
                            O_sdrc_init_done <= '1';
                            O_sdrc_busy_n    <= '1';
                            st <= ST_READY;
                        else
                            init_cnt <= init_cnt + 1;
                        end if;

                    when ST_READY =>
                        O_sdrc_busy_n <= '1';
                        base <= to_integer(unsigned(I_sdrc_addr(9 downto 0)));
                        len  <= to_integer(unsigned(I_sdrc_data_len));
                        cnt  <= 0;
                        if I_sdrc_wr_n = '0' then
                            O_sdrc_busy_n <= '0';
                            st <= ST_WRITE;
                        elsif I_sdrc_rd_n = '0' then
                            O_sdrc_busy_n <= '0';
                            lat <= 0;
                            st  <= ST_READ;
                        end if;

                    when ST_WRITE =>
                        -- cattura un dato per colpo, ack alzato
                        O_sdrc_wrd_ack <= '1';
                        mem(idx(base, cnt)) <= I_sdrc_data;
                        if cnt = len - 1 then
                            O_sdrc_busy_n <= '1';
                            st <= ST_READY;
                        else
                            cnt <= cnt + 1;
                        end if;

                    when ST_READ =>
                        if lat < RD_LAT then
                            lat <= lat + 1;            -- latenza comando->dato
                        else
                            O_sdrc_rd_valid <= '1';
                            O_sdrc_data     <= mem(idx(base, cnt));
                            if cnt = len - 1 then
                                O_sdrc_busy_n <= '1';
                                st <= ST_READY;
                            else
                                cnt <= cnt + 1;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
