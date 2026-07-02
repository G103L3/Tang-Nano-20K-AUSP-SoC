library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- =============================================================================
--  sdram_model_sim  -  modello SDR SDRAM comportamentale (SOLO simulazione)
-- =============================================================================
--  Modello minimale per validare sdram_controller_fsm in GHDL. NON sintetizzabile,
--  NON un modello timing-accurate del die reale: implementa solo il protocollo
--  comandi (ACTIVE / READ / WRITE / PRECHARGE / REFRESH / LMR), CAS latency
--  parametrica, full-page burst, mascheramento DQM. Memoria ridotta (4 bank x 16
--  righe basse x 256 colonne) sufficiente per il test write/read loopback.
-- =============================================================================

entity sdram_model_sim is
    generic (
        CL_MODEL : natural := 3
    );
    port (
        Clk   : in    std_logic;
        Cke   : in    std_logic;
        Cs_n  : in    std_logic;
        Ras_n : in    std_logic;
        Cas_n : in    std_logic;
        We_n  : in    std_logic;
        Addr  : in    std_logic_vector(10 downto 0);
        Ba    : in    std_logic_vector(1 downto 0);
        Dqm   : in    std_logic_vector(3 downto 0);
        Dq    : inout std_logic_vector(31 downto 0)
    );
end entity sdram_model_sim;

architecture sim of sdram_model_sim is

    constant N_ROW : natural := 16;   -- solo le 16 righe basse modellate
    type mem_t is array (0 to 4*N_ROW*256 - 1) of std_logic_vector(31 downto 0);

    function idx(ba : std_logic_vector(1 downto 0);
                 row : std_logic_vector(10 downto 0);
                 col : unsigned(7 downto 0)) return integer is
    begin
        return (to_integer(unsigned(ba)) * N_ROW
                + (to_integer(unsigned(row)) mod N_ROW)) * 256
               + to_integer(col);
    end function;

    signal mem : mem_t := (others => (others => '0'));

    signal act_ba  : std_logic_vector(1 downto 0)  := (others => '0');
    signal act_row : std_logic_vector(10 downto 0) := (others => '0');

    signal rd_active : std_logic := '0';
    signal wr_active : std_logic := '0';
    signal rdc       : unsigned(7 downto 0) := (others => '0');
    signal wrc       : unsigned(7 downto 0) := (others => '0');

    type pipe_data_t  is array (0 to CL_MODEL-1) of std_logic_vector(31 downto 0);
    signal pl_v : std_logic_vector(CL_MODEL-1 downto 0) := (others => '0');
    signal pl_d : pipe_data_t := (others => (others => '0'));

    -- comando decodificato combinatoriamente
    signal cmd : std_logic_vector(3 downto 0);

begin

    cmd <= Cs_n & Ras_n & Cas_n & We_n;

    -- DQ guidato in lettura dall'ultimo stadio della pipeline
    Dq <= pl_d(CL_MODEL-1) when (pl_v(CL_MODEL-1) = '1' and wr_active = '0')
          else (others => 'Z');

    process(Clk)
        variable i : integer;
    begin
        if rising_edge(Clk) then
            if Cke = '1' then
                ------------------------------------------------------------------
                -- pipeline di lettura: shift; lo stadio 0 viene caricato sotto
                -- (dato di col entra in pipeline NELLO STESSO ciclo della READ,
                --  cosi' appare sul bus esattamente CL_MODEL cicli dopo)
                ------------------------------------------------------------------
                for i in CL_MODEL-1 downto 1 loop
                    pl_v(i) <= pl_v(i-1);
                    pl_d(i) <= pl_d(i-1);
                end loop;
                pl_v(0) <= '0';

                ------------------------------------------------------------------
                -- scrittura del burst in corso (cicli successivi al comando WRITE)
                ------------------------------------------------------------------
                if wr_active = '1' and cmd /= "0100" then
                    if Dqm = "0000" then
                        mem(idx(act_ba, act_row, wrc)) <= Dq;
                    end if;
                    wrc <= wrc + 1;
                end if;

                ------------------------------------------------------------------
                -- lettura del burst in corso (cicli successivi al comando READ)
                ------------------------------------------------------------------
                if rd_active = '1' and cmd /= "0101" then
                    pl_v(0) <= '1';
                    pl_d(0) <= mem(idx(act_ba, act_row, rdc));
                    rdc     <= rdc + 1;
                end if;

                ------------------------------------------------------------------
                -- decodifica comando
                ------------------------------------------------------------------
                case cmd is
                    when "0011" =>                         -- ACTIVE
                        act_ba  <= Ba;
                        act_row <= Addr;
                    when "0101" =>                         -- READ (carica subito col)
                        rd_active <= '1';
                        wr_active <= '0';
                        pl_v(0)   <= '1';
                        pl_d(0)   <= mem(idx(act_ba, act_row, unsigned(Addr(7 downto 0))));
                        rdc       <= unsigned(Addr(7 downto 0)) + 1;
                    when "0100" =>                         -- WRITE (word0 sul bus ora)
                        wr_active <= '1';
                        rd_active <= '0';
                        if Dqm = "0000" then
                            mem(idx(act_ba, act_row, unsigned(Addr(7 downto 0)))) <= Dq;
                        end if;
                        wrc <= unsigned(Addr(7 downto 0)) + 1;
                    when "0010" =>                         -- PRECHARGE
                        rd_active <= '0';
                        wr_active <= '0';
                    when others =>                         -- NOP / REF / LMR / INH
                        null;
                end case;
            end if;
        end if;
    end process;

end architecture sim;
