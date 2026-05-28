library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity flash_ctrl is
    generic (
        CLK_HZ  : integer := 27_000_000;
        BAUD    : integer := 115200;
        SPI_DIV : integer := 8
    );
    port (
        clk_i        : in  std_logic;
        rst_i        : in  std_logic;
        fcmd_rx_i    : in  std_logic;
        fresp_tx_o   : out std_logic;
        flash_sck_o  : out std_logic;
        flash_cs_o   : out std_logic;
        flash_mosi_o : out std_logic;
        flash_miso_i : in  std_logic
    );
end flash_ctrl;

architecture rtl of flash_ctrl is

    component uart_rx_char is
        generic ( CLK_HZ : integer; BAUD : integer );
        port ( clk_i : in std_logic; rst_i : in std_logic; rx_i : in std_logic;
               data_o : out std_logic_vector(7 downto 0); valid_o : out std_logic );
    end component;

    component uart_tx_char is
        generic ( CLK_HZ : integer; BAUD : integer );
        port ( clk_i : in std_logic; rst_i : in std_logic;
               char_i : in std_logic_vector(7 downto 0); stb_i : in std_logic;
               tx_o : out std_logic; busy_o : out std_logic );
    end component;

    component SPI_Flash is
        generic ( PRESCALER : natural );
        port ( clk_i : in std_logic; rst_i : in std_logic; start_i : in std_logic;
               tx_i : in std_logic_vector(7 downto 0); rx_o : out std_logic_vector(7 downto 0);
               busy_o : out std_logic; done_o : out std_logic;
               MOSI : out std_logic; MISO : in std_logic; SCK : out std_logic );
    end component;

    constant BUF_N    : integer := 72;
    constant REC      : integer := 16;
    constant SET_N    : integer := 32;
    constant N_SLOTS  : integer := 512;
    constant SECT0    : integer := 16#1000#;
    constant SECT1    : integer := 16#2000#;
    constant SETADDR  : integer := 16#0000#;

    type buf_t is array(0 to BUF_N - 1) of std_logic_vector(7 downto 0);
    signal buf : buf_t := (others => (others => '0'));

    type st_t is (
        BOOT, B_WE, B_WRSR, B_WP, SCAN_RD, SCAN_CHK, IDLE, RX_COLLECT, G_PARSE,
        AP_ERCHK, AP_WE_E, AP_ERASE, AP_EP, AP_WE_P, AP_PROG, AP_PP, AP_DONE,
        CL_W0, CL_E0, CL_P0, CL_W1, CL_E1, CL_P1, CL_DONE,
        SW_WE_E, SW_ERASE, SW_EP, SW_WE_P, SW_PROG, SW_PP, SW_DONE,
        Q_RD, G_RD, I_RD, T_RD, H_SEND, RD_SEND,
        RF_CSL, RF_LOAD, RF_WAIT, RF_STORE, RF_CSH,
        POLL_SET, POLL_CHK, POLL_FAIL, TX_SEND, TX_WAIT
    );
    signal st       : st_t := BOOT;
    signal ret      : st_t := IDLE;
    signal poll_ret : st_t := IDLE;
    signal tret     : st_t := IDLE;

    signal fn       : integer range 0 to BUF_N := 0;
    signal idx      : integer range 0 to BUF_N := 0;
    signal head     : integer range 0 to N_SLOTS - 1 := 0;
    signal scan_i   : integer range 0 to N_SLOTS := 0;
    signal gslot    : integer range 0 to N_SLOTS - 1 := 0;
    signal gn       : integer range 0 to 4 := 0;
    signal tx_off   : integer range 0 to BUF_N := 0;
    signal tn       : integer range 0 to BUF_N := 0;
    signal tidx     : integer range 0 to BUF_N := 0;
    signal rx_need  : integer range 0 to BUF_N := 0;
    signal rx_off   : integer range 0 to BUF_N := 0;
    signal rx_cnt   : integer range 0 to BUF_N := 0;
    signal cmd_r    : std_logic_vector(7 downto 0) := (others => '0');

    constant POLL_MAX : integer := 200000;
    signal poll_to    : integer range 0 to POLL_MAX := 0;

    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;
    signal tx_char  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_stb   : std_logic := '0';
    signal tx_busy  : std_logic;

    signal spi_start : std_logic := '0';
    signal spi_tx    : std_logic_vector(7 downto 0) := (others => '0');
    signal spi_rx    : std_logic_vector(7 downto 0);
    signal spi_busy  : std_logic;
    signal spi_done  : std_logic;

    signal cs_r  : std_logic := '1';

    function b8(v : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(v mod 256, 8));
    end function;

begin

    flash_cs_o <= cs_r;

    u_rx : uart_rx_char
        generic map ( CLK_HZ => CLK_HZ, BAUD => BAUD )
        port map ( clk_i => clk_i, rst_i => rst_i, rx_i => fcmd_rx_i,
                   data_o => rx_data, valid_o => rx_valid );

    u_tx : uart_tx_char
        generic map ( CLK_HZ => CLK_HZ, BAUD => BAUD )
        port map ( clk_i => clk_i, rst_i => rst_i, char_i => tx_char, stb_i => tx_stb,
                   tx_o => fresp_tx_o, busy_o => tx_busy );

    u_spi : SPI_Flash
        generic map ( PRESCALER => SPI_DIV )
        port map ( clk_i => clk_i, rst_i => rst_i, start_i => spi_start,
                   tx_i => spi_tx, rx_o => spi_rx, busy_o => spi_busy, done_o => spi_done,
                   MOSI => flash_mosi_o, MISO => flash_miso_i, SCK => flash_sck_o );

    process(clk_i)
        variable saddr : integer;
        variable sbase : integer;
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                st <= BOOT; cs_r <= '1'; spi_start <= '0'; tx_stb <= '0';
                idx <= 0; fn <= 0; head <= 0; scan_i <= 0;
            else
                spi_start <= '0';
                tx_stb    <= '0';

                case st is

                    when BOOT =>
                        scan_i <= 0;
                        st <= B_WE;

                    when B_WE =>
                        buf(0) <= x"06"; fn <= 1; ret <= B_WRSR; st <= RF_CSL;

                    when B_WRSR =>
                        buf(0) <= x"01"; buf(1) <= x"00";
                        fn <= 2; ret <= B_WP; st <= RF_CSL;

                    when B_WP =>
                        poll_ret <= SCAN_RD; poll_to <= 0; st <= POLL_SET;

                    when SCAN_RD =>
                        saddr := SECT0 + scan_i * REC;
                        buf(0) <= x"03";
                        buf(1) <= b8(saddr / 65536);
                        buf(2) <= b8(saddr / 256);
                        buf(3) <= b8(saddr);
                        buf(4) <= x"00";
                        fn  <= 5;
                        ret <= SCAN_CHK;
                        st  <= RF_CSL;

                    when SCAN_CHK =>
                        if buf(4) = x"FF" or scan_i = N_SLOTS - 1 then
                            head <= scan_i;
                            st   <= IDLE;
                        else
                            scan_i <= scan_i + 1;
                            st     <= SCAN_RD;
                        end if;

                    when IDLE =>
                        cs_r <= '1';
                        if rx_valid = '1' then
                            cmd_r  <= rx_data;
                            rx_cnt <= 0;
                            case rx_data is
                                when x"4C" => rx_need <= REC;   rx_off <= 4;  st <= RX_COLLECT;
                                when x"53" => rx_need <= SET_N; rx_off <= 4;  st <= RX_COLLECT;
                                when x"47" => rx_need <= 3;     rx_off <= 64; st <= RX_COLLECT;
                                when x"48" => st <= H_SEND;
                                when x"43" => st <= CL_W0;
                                when x"51" => st <= Q_RD;
                                when x"49" => st <= I_RD;
                                when x"54" => st <= T_RD;
                                when others => st <= IDLE;
                            end case;
                        end if;

                    when RX_COLLECT =>
                        if rx_valid = '1' then
                            buf(rx_off + rx_cnt) <= rx_data;
                            if rx_cnt = rx_need - 1 then
                                if cmd_r = x"4C" then
                                    st <= AP_ERCHK;
                                elsif cmd_r = x"53" then
                                    st <= SW_WE_E;
                                else
                                    st <= G_PARSE;
                                end if;
                            else
                                rx_cnt <= rx_cnt + 1;
                            end if;
                        end if;

                    when G_PARSE =>
                        gslot <= to_integer(unsigned(buf(64))) * 256 + to_integer(unsigned(buf(65)));
                        gn    <= to_integer(unsigned(buf(66)));
                        st    <= G_RD;

                    when AP_ERCHK =>
                        if head = 0 or head = 256 then
                            st <= AP_WE_E;
                        else
                            st <= AP_WE_P;
                        end if;

                    when AP_WE_E =>
                        buf(0) <= x"06"; fn <= 1; ret <= AP_ERASE; st <= RF_CSL;

                    when AP_ERASE =>
                        if head < 256 then sbase := SECT0; else sbase := SECT1; end if;
                        buf(0) <= x"20";
                        buf(1) <= b8(sbase / 65536);
                        buf(2) <= b8(sbase / 256);
                        buf(3) <= b8(sbase);
                        fn <= 4; ret <= AP_EP; st <= RF_CSL;

                    when AP_EP =>
                        poll_ret <= AP_WE_P; poll_to <= 0; st <= POLL_SET;

                    when AP_WE_P =>
                        buf(0) <= x"06"; fn <= 1; ret <= AP_PROG; st <= RF_CSL;

                    when AP_PROG =>
                        saddr := SECT0 + head * REC;
                        buf(0) <= x"02";
                        buf(1) <= b8(saddr / 65536);
                        buf(2) <= b8(saddr / 256);
                        buf(3) <= b8(saddr);
                        fn <= 4 + REC; ret <= AP_PP; st <= RF_CSL;

                    when AP_PP =>
                        poll_ret <= AP_DONE; poll_to <= 0; st <= POLL_SET;

                    when AP_DONE =>
                        if head = N_SLOTS - 1 then head <= 0; else head <= head + 1; end if;
                        buf(0) <= x"4B"; tx_off <= 0; tn <= 1; tidx <= 0; tret <= IDLE;
                        st <= TX_SEND;

                    when CL_W0 =>
                        buf(0) <= x"06"; fn <= 1; ret <= CL_E0; st <= RF_CSL;
                    when CL_E0 =>
                        buf(0) <= x"20"; buf(1) <= b8(SECT0/65536); buf(2) <= b8(SECT0/256); buf(3) <= b8(SECT0);
                        fn <= 4; ret <= CL_P0; st <= RF_CSL;
                    when CL_P0 =>
                        poll_ret <= CL_W1; poll_to <= 0; st <= POLL_SET;
                    when CL_W1 =>
                        buf(0) <= x"06"; fn <= 1; ret <= CL_E1; st <= RF_CSL;
                    when CL_E1 =>
                        buf(0) <= x"20"; buf(1) <= b8(SECT1/65536); buf(2) <= b8(SECT1/256); buf(3) <= b8(SECT1);
                        fn <= 4; ret <= CL_P1; st <= RF_CSL;
                    when CL_P1 =>
                        poll_ret <= CL_DONE; poll_to <= 0; st <= POLL_SET;
                    when CL_DONE =>
                        head <= 0;
                        buf(0) <= x"4B"; tx_off <= 0; tn <= 1; tidx <= 0; tret <= IDLE;
                        st <= TX_SEND;

                    when SW_WE_E =>
                        buf(0) <= x"06"; fn <= 1; ret <= SW_ERASE; st <= RF_CSL;
                    when SW_ERASE =>
                        buf(0) <= x"20"; buf(1) <= b8(SETADDR/65536); buf(2) <= b8(SETADDR/256); buf(3) <= b8(SETADDR);
                        fn <= 4; ret <= SW_EP; st <= RF_CSL;
                    when SW_EP =>
                        poll_ret <= SW_WE_P; poll_to <= 0; st <= POLL_SET;
                    when SW_WE_P =>
                        buf(0) <= x"06"; fn <= 1; ret <= SW_PROG; st <= RF_CSL;
                    when SW_PROG =>
                        buf(0) <= x"02"; buf(1) <= b8(SETADDR/65536); buf(2) <= b8(SETADDR/256); buf(3) <= b8(SETADDR);
                        fn <= 4 + SET_N; ret <= SW_PP; st <= RF_CSL;
                    when SW_PP =>
                        poll_ret <= SW_DONE; poll_to <= 0; st <= POLL_SET;
                    when SW_DONE =>
                        buf(0) <= x"4B"; tx_off <= 0; tn <= 1; tidx <= 0; tret <= IDLE;
                        st <= TX_SEND;

                    when Q_RD =>
                        buf(0) <= x"03"; buf(1) <= b8(SETADDR/65536); buf(2) <= b8(SETADDR/256); buf(3) <= b8(SETADDR);
                        fn <= 4 + SET_N; ret <= RD_SEND; st <= RF_CSL;
                        tx_off <= 4; tn <= SET_N; tret <= IDLE;

                    when G_RD =>
                        saddr := SECT0 + gslot * REC;
                        buf(0) <= x"03"; buf(1) <= b8(saddr/65536); buf(2) <= b8(saddr/256); buf(3) <= b8(saddr);
                        fn <= 4 + gn * REC; ret <= RD_SEND; st <= RF_CSL;
                        tx_off <= 4; tn <= gn * REC; tret <= IDLE;

                    when I_RD =>
                        buf(0) <= x"9F"; buf(1) <= x"00"; buf(2) <= x"00"; buf(3) <= x"00";
                        fn <= 4; ret <= RD_SEND; st <= RF_CSL;
                        tx_off <= 1; tn <= 3; tret <= IDLE;

                    when T_RD =>
                        buf(0) <= x"05"; buf(1) <= x"00";
                        fn <= 2; ret <= RD_SEND; st <= RF_CSL;
                        tx_off <= 1; tn <= 1; tret <= IDLE;

                    when H_SEND =>
                        buf(0) <= b8(head / 256); buf(1) <= b8(head);
                        tx_off <= 0; tn <= 2; tret <= IDLE; tidx <= 0;
                        st <= TX_SEND;

                    when RD_SEND =>
                        tidx <= 0;
                        st <= TX_SEND;

                    when RF_CSL =>
                        cs_r <= '0'; idx <= 0; st <= RF_LOAD;
                    when RF_LOAD =>
                        spi_tx <= buf(idx); spi_start <= '1'; st <= RF_WAIT;
                    when RF_WAIT =>
                        if spi_done = '1' then st <= RF_STORE; end if;
                    when RF_STORE =>
                        buf(idx) <= spi_rx;
                        if idx = fn - 1 then st <= RF_CSH;
                        else idx <= idx + 1; st <= RF_LOAD; end if;
                    when RF_CSH =>
                        cs_r <= '1'; st <= ret;

                    when POLL_SET =>
                        buf(0) <= x"05"; buf(1) <= x"00"; fn <= 2; ret <= POLL_CHK; st <= RF_CSL;
                    when POLL_CHK =>
                        if buf(1)(0) = '1' then
                            if poll_to >= POLL_MAX then
                                st <= POLL_FAIL;
                            else
                                poll_to <= poll_to + 1;
                                st      <= POLL_SET;
                            end if;
                        else
                            st <= poll_ret;
                        end if;

                    when POLL_FAIL =>
                        buf(0) <= x"45"; tx_off <= 0; tn <= 1; tidx <= 0; tret <= IDLE;
                        st <= TX_SEND;

                    when TX_SEND =>
                        if tx_busy = '0' then
                            tx_char <= buf(tx_off + tidx);
                            tx_stb  <= '1';
                            st      <= TX_WAIT;
                        end if;
                    when TX_WAIT =>
                        if tx_busy = '1' then
                            if tidx = tn - 1 then st <= tret;
                            else tidx <= tidx + 1; st <= TX_SEND; end if;
                        end if;

                end case;
            end if;
        end if;
    end process;

end rtl;
