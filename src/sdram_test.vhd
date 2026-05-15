library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Test diretto SDRAM: scrive 0xA55A1234 ad addr 0, poi lo rilegge ogni 0.3s
-- e manda il risultato come 8 cifre hex via UART (115200 baud @ 108 MHz).
-- Bypassa completamente memory_arbiter e wishbone.
--
-- Atteso su terminale: "=A55A1234\r\n" ripetuto
-- Se stampa "=FFFFFFFF" → write non funziona (SDRAM mai scritta)
-- Se stampa "=00000000" → read latch troppo presto
entity sdram_test is
    port (
        clk         : in    std_logic;  -- 108 MHz (da rPLL)
        pll_lock    : in    std_logic;  -- usato come rst_n per SDRAM IP
        uart_tx     : out   std_logic;
        init_done_o : out   std_logic;
        O_sdram_clk   : out   std_logic;
        O_sdram_cke   : out   std_logic;
        O_sdram_cs_n  : out   std_logic;
        O_sdram_cas_n : out   std_logic;
        O_sdram_ras_n : out   std_logic;
        O_sdram_wen_n : out   std_logic;
        O_sdram_dqm   : out   std_logic_vector(3 downto 0);
        O_sdram_addr  : out   std_logic_vector(10 downto 0);
        O_sdram_ba    : out   std_logic_vector(1 downto 0);
        IO_sdram_dq   : inout std_logic_vector(31 downto 0)
    );
end entity sdram_test;

architecture rtl of sdram_test is

    component SDRAM_Controller_HS_Top
        port (
            O_sdram_clk           : out   std_logic;
            O_sdram_cke           : out   std_logic;
            O_sdram_cs_n          : out   std_logic;
            O_sdram_cas_n         : out   std_logic;
            O_sdram_ras_n         : out   std_logic;
            O_sdram_wen_n         : out   std_logic;
            O_sdram_dqm           : out   std_logic_vector(3 downto 0);
            O_sdram_addr          : out   std_logic_vector(10 downto 0);
            O_sdram_ba            : out   std_logic_vector(1 downto 0);
            IO_sdram_dq           : inout std_logic_vector(31 downto 0);
            I_sdrc_rst_n          : in    std_logic;
            I_sdrc_clk            : in    std_logic;
            I_sdram_clk           : in    std_logic;
            I_sdrc_cmd_en         : in    std_logic;
            I_sdrc_cmd            : in    std_logic_vector(2 downto 0);
            I_sdrc_precharge_ctrl : in    std_logic;
            I_sdram_power_down    : in    std_logic;
            I_sdram_selfrefresh   : in    std_logic;
            I_sdrc_addr           : in    std_logic_vector(20 downto 0);
            I_sdrc_dqm            : in    std_logic_vector(3 downto 0);
            I_sdrc_data           : in    std_logic_vector(31 downto 0);
            I_sdrc_data_len       : in    std_logic_vector(7 downto 0);
            O_sdrc_data           : out   std_logic_vector(31 downto 0);
            O_sdrc_init_done      : out   std_logic;
            O_sdrc_cmd_ack        : out   std_logic
        );
    end component;

    -- SDRAM controller signals
    signal cmd_en    : std_logic := '0';
    signal cmd       : std_logic_vector(2 downto 0) := "111";
    signal sdrc_addr : std_logic_vector(20 downto 0) := (others => '0');
    signal wr_data   : std_logic_vector(31 downto 0) := (others => '0');
    signal rd_data   : std_logic_vector(31 downto 0);
    signal init_done : std_logic;

    constant TEST_WORD : std_logic_vector(31 downto 0) := x"A55A1234";

    -- Test FSM
    type t_state is (
        ST_INIT,
        ST_WRITE, ST_WRITE_WAIT,
        ST_READ,  ST_READ_WAIT,
        ST_TX,
        ST_PAUSE
    );
    signal state : t_state := ST_INIT;

    signal timer    : unsigned(25 downto 0) := (others => '0');
    signal rd_latch : std_logic_vector(31 downto 0) := (others => '0');
    signal tx_seq   : integer range 0 to 15 := 0;

    -- UART TX @ 108 MHz, 115200 baud: divisore = 108e6/115200 = 937.5 → 937
    constant BAUD_DIV : integer := 937;
    signal baud_cnt  : unsigned(9 downto 0) := (others => '0');
    signal baud_tick : std_logic := '0';

    -- Shift register: stop(1) + data[7:0] + start(0), trasmesso LSB-first
    signal tx_sr    : std_logic_vector(9 downto 0) := (others => '1');
    signal tx_cnt   : unsigned(3 downto 0) := (others => '0');
    signal tx_busy  : std_logic := '0';
    signal tx_load  : std_logic := '0';
    signal tx_byte  : std_logic_vector(7 downto 0) := (others => '0');

    function to_hex_char(n : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable v : integer;
    begin
        v := to_integer(unsigned(n));
        if v < 10 then
            return std_logic_vector(to_unsigned(48 + v, 8));  -- '0'..'9'
        else
            return std_logic_vector(to_unsigned(55 + v, 8));  -- 'A'..'F'
        end if;
    end function;

begin

    init_done_o <= init_done;
    uart_tx     <= tx_sr(0);

    u_sdrc: SDRAM_Controller_HS_Top
    port map (
        O_sdram_clk           => O_sdram_clk,
        O_sdram_cke           => O_sdram_cke,
        O_sdram_cs_n          => O_sdram_cs_n,
        O_sdram_cas_n         => O_sdram_cas_n,
        O_sdram_ras_n         => O_sdram_ras_n,
        O_sdram_wen_n         => O_sdram_wen_n,
        O_sdram_dqm           => O_sdram_dqm,
        O_sdram_addr          => O_sdram_addr,
        O_sdram_ba            => O_sdram_ba,
        IO_sdram_dq           => IO_sdram_dq,
        I_sdrc_rst_n          => pll_lock,
        I_sdrc_clk            => clk,
        I_sdram_clk           => clk,
        I_sdrc_cmd_en         => cmd_en,
        I_sdrc_cmd            => cmd,
        I_sdrc_precharge_ctrl => '1',
        I_sdram_power_down    => '0',
        I_sdram_selfrefresh   => '0',
        I_sdrc_addr           => sdrc_addr,
        I_sdrc_dqm            => "0000",
        I_sdrc_data           => wr_data,
        I_sdrc_data_len       => x"00",  -- length-1: x"00" = 1 word
        O_sdrc_data           => rd_data,
        O_sdrc_init_done      => init_done,
        O_sdrc_cmd_ack        => open
    );

    -- Baud tick
    process(clk)
    begin
        if rising_edge(clk) then
            baud_tick <= '0';
            if baud_cnt = BAUD_DIV - 1 then
                baud_cnt  <= (others => '0');
                baud_tick <= '1';
            else
                baud_cnt <= baud_cnt + 1;
            end if;
        end if;
    end process;

    -- UART shift register: carica su tx_load, trasmette su baud_tick
    process(clk)
    begin
        if rising_edge(clk) then
            if baud_tick = '1' and tx_busy = '1' then
                tx_sr  <= '1' & tx_sr(9 downto 1);  -- shift out LSB
                tx_cnt <= tx_cnt + 1;
                if tx_cnt = 9 then
                    tx_busy <= '0';
                    tx_cnt  <= (others => '0');
                end if;
            end if;
            if tx_load = '1' and tx_busy = '0' then
                tx_sr   <= '1' & tx_byte & '0';  -- {stop, data7..0, start}
                tx_busy <= '1';
                tx_cnt  <= (others => '0');
            end if;
        end if;
    end process;

    -- Test FSM principale
    process(clk)
    begin
        if rising_edge(clk) then
            cmd_en  <= '0';
            cmd     <= "111";  -- NOP default
            tx_load <= '0';

            case state is

                when ST_INIT =>
                    if init_done = '1' then
                        state <= ST_WRITE;
                    end if;

                when ST_WRITE =>
                    cmd_en    <= '1';
                    cmd       <= "100";        -- WRITE
                    sdrc_addr <= (others => '0');
                    wr_data   <= TEST_WORD;
                    timer     <= (others => '0');
                    state     <= ST_WRITE_WAIT;

                when ST_WRITE_WAIT =>
                    timer <= timer + 1;
                    if timer = 200 then        -- 200 cicli @ 108 MHz = 1.85 µs >> tWR+tRP
                        state <= ST_READ;
                    end if;

                when ST_READ =>
                    cmd_en    <= '1';
                    cmd       <= "101";        -- READ
                    sdrc_addr <= (others => '0');
                    timer     <= (others => '0');
                    state     <= ST_READ_WAIT;

                when ST_READ_WAIT =>
                    timer <= timer + 1;
                    if timer = 12 then         -- 13 cicli da cmd_en: ACTIVATE(4)+CL(3)+margine
                        rd_latch <= rd_data;
                        tx_seq   <= 0;
                        state    <= ST_TX;
                    end if;

                when ST_TX =>
                    if tx_busy = '0' and tx_load = '0' then
                        tx_load <= '1';
                        tx_seq  <= tx_seq + 1;
                        case tx_seq is
                            when 0  => tx_byte <= x"3D";  -- '='
                            when 1  => tx_byte <= to_hex_char(rd_latch(31 downto 28));
                            when 2  => tx_byte <= to_hex_char(rd_latch(27 downto 24));
                            when 3  => tx_byte <= to_hex_char(rd_latch(23 downto 20));
                            when 4  => tx_byte <= to_hex_char(rd_latch(19 downto 16));
                            when 5  => tx_byte <= to_hex_char(rd_latch(15 downto 12));
                            when 6  => tx_byte <= to_hex_char(rd_latch(11 downto 8));
                            when 7  => tx_byte <= to_hex_char(rd_latch(7 downto 4));
                            when 8  => tx_byte <= to_hex_char(rd_latch(3 downto 0));
                            when 9  => tx_byte <= x"0D";  -- '\r'
                            when 10 => tx_byte <= x"0A";  -- '\n'
                            when others =>
                                tx_load <= '0';
                                timer   <= (others => '0');
                                state   <= ST_PAUSE;
                        end case;
                    end if;

                when ST_PAUSE =>
                    timer <= timer + 1;
                    -- ~0.3 s a 108 MHz = 32.4M cicli → bit 25 del timer (2^25 = 33.5M)
                    if timer(25) = '1' then
                        state <= ST_READ;  -- rilegge senza riscrivere
                    end if;

            end case;
        end if;
    end process;

end rtl;
