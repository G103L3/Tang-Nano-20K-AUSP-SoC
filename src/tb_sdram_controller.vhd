library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- =============================================================================
--  tb_sdram_controller  -  testbench self-checking (GHDL)
-- =============================================================================
--  Gate di verifica prima di flashare. Collega sdram_controller_fsm al modello
--  comportamentale sdram_model_sim e verifica:
--    1. la sequenza di bring-up: PRECHARGE ALL -> AUTO REFRESH x2 -> LMR;
--    2. due WRITE+READ loopback su indirizzi (bank/row) diversi, con dati
--       distinti, ciascuno confrontato parola per parola;
--    3. con AUTO REFRESH abilitato a intervallo breve: i refresh si intercalano
--       fra le transazioni (arbitraggio busy_n) senza corrompere i dati.
--  Stampa SIMULATION PASSED / FAILED e termina.
-- =============================================================================

entity tb_sdram_controller is
end entity;

architecture tb of tb_sdram_controller is

    constant TCK : time := 10 ns;
    constant N   : natural := 7;           -- data_len -> burst di N+1 = 8 parole

    signal clk   : std_logic := '0';
    signal rst_n : std_logic := '0';
    signal stop  : boolean   := false;

    -- die side
    signal s_clk, s_cke, s_cs_n, s_cas_n, s_ras_n, s_wen_n : std_logic;
    signal s_dqm  : std_logic_vector(3 downto 0);
    signal s_addr : std_logic_vector(10 downto 0);
    signal s_ba   : std_logic_vector(1 downto 0);
    signal s_dq   : std_logic_vector(31 downto 0);

    -- user side
    signal u_wr_n, u_rd_n : std_logic := '1';
    signal u_addr : std_logic_vector(20 downto 0) := (others => '0');
    signal u_len  : std_logic_vector(7 downto 0)  := (others => '0');
    signal u_dqm  : std_logic_vector(3 downto 0)  := (others => '0');
    signal u_data : std_logic_vector(31 downto 0) := (others => '0');
    signal o_data : std_logic_vector(31 downto 0);
    signal o_init_done, o_busy_n, o_rd_valid, o_wrd_ack : std_logic;

    -- registrazione comandi (per check bring-up)
    type cmd_arr is array (0 to 15) of std_logic_vector(3 downto 0);
    type adr_arr is array (0 to 15) of std_logic_vector(10 downto 0);
    signal init_cmd  : cmd_arr := (others => "0111");
    signal init_adr  : adr_arr := (others => (others => '0'));
    signal init_n    : natural := 0;
    signal rec_en    : std_logic := '1';   -- registra solo durante il bring-up

    -- raccolta letture
    type data_arr is array (0 to 63) of std_logic_vector(31 downto 0);
    signal rd_arr   : data_arr := (others => (others => '0'));
    signal rd_cnt   : natural := 0;
    signal rd_clear : std_logic := '0';   -- pilotato solo da stim, azzera rd_cnt

    constant CMD_NOP : std_logic_vector(3 downto 0) := "0111";
    constant CMD_INH : std_logic_vector(3 downto 0) := "1111";

    function mk_addr(ba : natural; row : natural; col : natural)
        return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(ba, 2)) &
               std_logic_vector(to_unsigned(row, 11)) &
               std_logic_vector(to_unsigned(col, 8));
    end function;

    function word_of(base : natural; k : natural) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(base + k, 32));
    end function;

begin

    clk <= not clk after TCK/2 when not stop else '0';

    dut : entity work.sdram_controller_fsm
        generic map (
            INIT_WAIT_CYCLES => 16,
            REFRESH_INTERVAL => 60,        -- intervallo breve: refresh durante il test
            RD_CAP_ADJ       => 0,         -- modello sim ideale: latenza round-trip = CL+2
            WR_ALIGN         => 0          -- modello ideale: 2 stadi di delay line
        )
        port map (
            O_sdram_clk => s_clk,  O_sdram_cke => s_cke,
            O_sdram_cs_n => s_cs_n, O_sdram_cas_n => s_cas_n,
            O_sdram_ras_n => s_ras_n, O_sdram_wen_n => s_wen_n,
            O_sdram_dqm => s_dqm, O_sdram_addr => s_addr, O_sdram_ba => s_ba,
            IO_sdram_dq => s_dq,
            I_sdrc_rst_n => rst_n, I_sdrc_clk => clk, I_sdram_clk => clk,
            I_sdrc_selfrefresh => '0', I_sdrc_power_down => '0',
            I_sdrc_wr_n => u_wr_n, I_sdrc_rd_n => u_rd_n,
            I_sdrc_addr => u_addr, I_sdrc_data_len => u_len,
            I_sdrc_dqm => u_dqm, I_sdrc_data => u_data,
            O_sdrc_data => o_data, O_sdrc_init_done => o_init_done,
            O_sdrc_busy_n => o_busy_n, O_sdrc_rd_valid => o_rd_valid,
            O_sdrc_wrd_ack => o_wrd_ack
        );

    mem : entity work.sdram_model_sim
        generic map ( CL_MODEL => 3 )
        port map (
            Clk => s_clk, Cke => s_cke, Cs_n => s_cs_n, Ras_n => s_ras_n,
            Cas_n => s_cas_n, We_n => s_wen_n, Addr => s_addr, Ba => s_ba,
            Dqm => s_dqm, Dq => s_dq
        );

    -- registra i comandi del bring-up (fino a init_done)
    record_cmd : process(clk)
        variable c : std_logic_vector(3 downto 0);
    begin
        if rising_edge(clk) then
            if rec_en = '1' and rst_n = '1' then
                c := s_cs_n & s_ras_n & s_cas_n & s_wen_n;
                if c /= CMD_NOP and c /= CMD_INH and init_n < 16 then
                    init_cmd(init_n) <= c;
                    init_adr(init_n) <= s_addr;
                    init_n           <= init_n + 1;
                end if;
            end if;
            if o_init_done = '1' then
                rec_en <= '0';
            end if;
        end if;
    end process;

    collect : process(clk)
    begin
        if rising_edge(clk) then
            if rd_clear = '1' then
                rd_cnt <= 0;
            elsif o_rd_valid = '1' and rd_cnt < 64 then
                rd_arr(rd_cnt) <= o_data;
                rd_cnt         <= rd_cnt + 1;
            end if;
        end if;
    end process;

    stim : process
        variable errors : natural := 0;

        -- una transazione WRITE seguita da READ+confronto
        procedure wr_rd(ba, row, col, base : natural) is
        begin
            -- WRITE: attende busy_n, pulsa wr_n=0 1 ciclo, poi presenta le parole
            wait until rising_edge(clk) and o_busy_n = '1';
            u_addr <= mk_addr(ba, row, col);
            u_data <= word_of(base, 0);
            u_wr_n <= '0';
            wait until rising_edge(clk);
            u_wr_n <= '1';
            for k in 0 to N loop
                u_data <= word_of(base, k);
                wait until rising_edge(clk);
            end loop;
            u_data <= (others => '0');

            -- READ sullo stesso indirizzo
            rd_clear <= '1';
            wait until rising_edge(clk);
            rd_clear <= '0';
            wait until rising_edge(clk) and o_busy_n = '1';
            u_addr <= mk_addr(ba, row, col);
            u_rd_n <= '0';
            wait until rising_edge(clk);
            u_rd_n <= '1';
            for i in 0 to 300 loop
                exit when rd_cnt >= N + 1;
                wait until rising_edge(clk);
            end loop;

            report "WR/RD ba=" & integer'image(ba) & " row=" & integer'image(row) &
                   ": parole rilette = " & integer'image(rd_cnt);
            for k in 0 to N loop
                if rd_arr(k) /= word_of(base, k) then
                    errors := errors + 1;
                    report "  MISMATCH parola " & integer'image(k) &
                           " attesa=" & to_hstring(word_of(base, k)) &
                           " ottenuta=" & to_hstring(rd_arr(k)) severity warning;
                end if;
            end loop;
            if rd_cnt /= N + 1 then
                errors := errors + 1;
                report "  CONTEGGIO PAROLE errato: " & integer'image(rd_cnt) severity warning;
            end if;
        end procedure;

    begin
        u_len  <= std_logic_vector(to_unsigned(N, 8));
        u_dqm  <= "0000";
        rst_n  <= '0';
        for i in 0 to 4 loop wait until rising_edge(clk); end loop;
        rst_n <= '1';

        ----------------------------------------------------------------------
        -- 1) bring-up
        ----------------------------------------------------------------------
        wait until o_init_done = '1';
        wait until rising_edge(clk);
        report "bring-up: registrati " & integer'image(init_n) & " comandi";
        if not (init_cmd(0) = "0010" and init_adr(0)(10) = '1') then
            errors := errors + 1;
            report "  bring-up[0] non e' PRECHARGE ALL" severity warning;
        end if;
        if init_cmd(1) /= "0001" then
            errors := errors + 1; report "  bring-up[1] non e' AUTO REFRESH" severity warning;
        end if;
        if init_cmd(2) /= "0001" then
            errors := errors + 1; report "  bring-up[2] non e' AUTO REFRESH" severity warning;
        end if;
        if not (init_cmd(3) = "0000" and init_adr(3) = "00000110111") then
            errors := errors + 1; report "  bring-up[3] non e' LMR con mode reg atteso" severity warning;
        end if;

        ----------------------------------------------------------------------
        -- 2) due transazioni su indirizzi diversi (refresh abilitato)
        ----------------------------------------------------------------------
        wr_rd(2,  2, 5, 16#1000#);
        wr_rd(1, 13, 9, 16#A500#);

        ----------------------------------------------------------------------
        if errors = 0 then
            report "===== SIMULATION PASSED =====" severity note;
        else
            report "===== SIMULATION FAILED (" & integer'image(errors) &
                   " errori) =====" severity error;
        end if;
        stop <= true;
        wait;
    end process;

end architecture tb;
