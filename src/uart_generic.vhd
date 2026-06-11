library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_GENERIC is
    Port (
        clk_i   : in  STD_LOGIC;
        rst_i   : in  STD_LOGIC;
        cyc_i   : in  STD_LOGIC;
        stb_i   : in  STD_LOGIC;
        we_i    : in  STD_LOGIC;
        adr_i   : in  STD_LOGIC_VECTOR(7 downto 0);
        dat_i   : in  STD_LOGIC_VECTOR(31 downto 0);
        dat_o   : out STD_LOGIC_VECTOR(31 downto 0);
        ack_o   : out STD_LOGIC;
        TX_o    : out STD_LOGIC;
        RX_i    : in  STD_LOGIC
    );
end UART_GENERIC;

architecture UART_GENERIC_BEHAVIORAL of UART_GENERIC is

    type tx_state_type is (S_TX_IDLE, S_TX_START, S_TX_DATA, S_TX_PARITY, S_TX_STOP);
    type rx_state_type is (S_RX_IDLE, S_RX_START, S_RX_DATA, S_RX_PARITY, S_RX_STOP);

    signal tx_state    : tx_state_type;
    signal rx_state    : rx_state_type;

    signal enabled     : std_logic := '0';
    signal baud_div    : natural range 1 to 65535 := 234;
    signal parity_cfg  : std_logic_vector(1 downto 0) := "00";
    signal data_bits   : natural range 5 to 9 := 8;
    signal stop_bits   : natural range 1 to 2 := 1;

    signal tx_data     : std_logic_vector(8 downto 0) := (others => '0');
    signal tx_busy     : std_logic := '0';
    signal tx_bit_cnt  : natural range 0 to 8 := 0;
    signal tx_baud_cnt : natural range 0 to 65535 := 0;
    signal tx_parity   : std_logic := '0';
    signal tx_stop_cnt : natural range 0 to 1 := 0;
    signal TX_s        : std_logic := '1';

    signal rx_q0, rx_q1 : std_logic := '1';
    signal rx_shift    : std_logic_vector(8 downto 0) := (others => '0');
    signal rx_bit_cnt  : natural range 0 to 8 := 0;
    signal rx_baud_cnt : natural range 0 to 65535 := 0;
    signal rx_parity   : std_logic := '0';

    -- FIFO RX: il vecchio registro singolo veniva sovrascritto dai burst
    -- back-to-back (es. comandi NOR multi-byte) mentre la CPU era altrove.
    constant RXF_DEPTH : natural := 16;
    type rxf_t is array(0 to RXF_DEPTH - 1) of std_logic_vector(7 downto 0);
    signal rxf      : rxf_t := (others => (others => '0'));
    signal rxf_wr   : natural range 0 to RXF_DEPTH - 1 := 0;
    signal rxf_rd   : natural range 0 to RXF_DEPTH - 1 := 0;
    signal rxf_cnt  : natural range 0 to RXF_DEPTH := 0;
    signal rx_valid : std_logic;
    -- byte catturato al ciclo di accesso (pre-pop): dat_o e' campionato dal
    -- master al ciclo dopo, quando il puntatore e' gia' avanzato.
    signal rd_data  : std_logic_vector(8 downto 0) := (others => '0');
    signal ack_r    : std_logic := '0';

begin

    TX_o  <= TX_s;
    ack_o <= ack_r;

    rx_valid <= '1' when rxf_cnt /= 0 else '0';

    dat_o <= "00000000000000000000000" & rd_data                  when adr_i = x"00" else
             x"0000000" & "00" & rx_valid & tx_busy               when adr_i = x"14" else
             (others => '0');

    seq_clk: process(clk_i)
        variable cnt_v : natural range 0 to RXF_DEPTH;
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                ack_r       <= '0';
                enabled     <= '0';
                baud_div    <= 234;
                parity_cfg  <= "00";
                data_bits   <= 8;
                stop_bits   <= 1;
                tx_state    <= S_TX_IDLE;
                tx_busy     <= '0';
                tx_baud_cnt <= 0;
                tx_bit_cnt  <= 0;
                tx_parity   <= '0';
                tx_stop_cnt <= 0;
                TX_s        <= '1';
                rx_state    <= S_RX_IDLE;
                rx_q0       <= '1';
                rx_q1       <= '1';
                rx_baud_cnt <= 0;
                rx_bit_cnt  <= 0;
                rx_parity   <= '0';
                rx_shift    <= (others => '0');
                rxf_wr      <= 0;
                rxf_rd      <= 0;
                rxf_cnt     <= 0;
                rd_data     <= (others => '0');
            else
                cnt_v := rxf_cnt;
                ack_r <= '0';

                rx_q0 <= RX_i;
                rx_q1 <= rx_q0;

                if cyc_i = '1' and stb_i = '1' then
                    ack_r <= '1';
                    if we_i = '1' then
                        case adr_i is
                            when x"00" =>
                                if tx_busy = '0' and enabled = '1' then
                                    tx_data    <= '0' & dat_i(7 downto 0);
                                    tx_busy    <= '1';
                                    tx_parity  <= '0';
                                end if;
                            when x"04" =>
                                enabled <= '1';
                            when x"08" =>
                                enabled <= '0';
                            when x"0C" =>
                                baud_div <= to_integer(unsigned(dat_i(15 downto 0)));
                            when x"10" =>
                                parity_cfg <= dat_i(1 downto 0);
                                if dat_i(2) = '1' then
                                    stop_bits <= 2;
                                else
                                    stop_bits <= 1;
                                end if;
                                data_bits <= to_integer(unsigned(dat_i(6 downto 3))) + 5;
                            when others =>
                                null;
                        end case;
                    else
                        if adr_i = x"00" and ack_r = '0' then
                            rd_data <= rx_valid & rxf(rxf_rd);
                            if rxf_cnt /= 0 then
                                rxf_rd <= (rxf_rd + 1) mod RXF_DEPTH;
                                cnt_v  := cnt_v - 1;
                            end if;
                        end if;
                    end if;
                end if;

                case tx_state is
                    when S_TX_IDLE =>
                        TX_s <= '1';
                        if tx_busy = '1' then
                            tx_state    <= S_TX_START;
                            tx_baud_cnt <= 0;
                            tx_bit_cnt  <= 0;
                        end if;

                    when S_TX_START =>
                        TX_s <= '0';
                        if tx_baud_cnt = baud_div - 1 then
                            tx_baud_cnt <= 0;
                            tx_state    <= S_TX_DATA;
                        else
                            tx_baud_cnt <= tx_baud_cnt + 1;
                        end if;

                    when S_TX_DATA =>
                        TX_s <= tx_data(tx_bit_cnt);
                        if tx_baud_cnt = baud_div - 1 then
                            tx_parity   <= tx_parity xor tx_data(tx_bit_cnt);
                            tx_baud_cnt <= 0;
                            if tx_bit_cnt = data_bits - 1 then
                                tx_bit_cnt <= 0;
                                if parity_cfg = "00" then
                                    tx_stop_cnt <= 0;
                                    tx_state    <= S_TX_STOP;
                                else
                                    tx_state <= S_TX_PARITY;
                                end if;
                            else
                                tx_bit_cnt <= tx_bit_cnt + 1;
                            end if;
                        else
                            tx_baud_cnt <= tx_baud_cnt + 1;
                        end if;

                    when S_TX_PARITY =>
                        if parity_cfg = "01" then
                            TX_s <= tx_parity;
                        else
                            TX_s <= not tx_parity;
                        end if;
                        if tx_baud_cnt = baud_div - 1 then
                            tx_baud_cnt <= 0;
                            tx_stop_cnt <= 0;
                            tx_state    <= S_TX_STOP;
                        else
                            tx_baud_cnt <= tx_baud_cnt + 1;
                        end if;

                    when S_TX_STOP =>
                        TX_s <= '1';
                        if tx_baud_cnt = baud_div - 1 then
                            tx_baud_cnt <= 0;
                            if tx_stop_cnt = stop_bits - 1 then
                                tx_busy  <= '0';
                                tx_state <= S_TX_IDLE;
                            else
                                tx_stop_cnt <= tx_stop_cnt + 1;
                            end if;
                        else
                            tx_baud_cnt <= tx_baud_cnt + 1;
                        end if;

                    when others =>
                        TX_s     <= '1';
                        tx_state <= S_TX_IDLE;
                end case;

                case rx_state is
                    when S_RX_IDLE =>
                        if rx_q1 = '0' then
                            rx_state    <= S_RX_START;
                            rx_baud_cnt <= 0;
                            rx_parity   <= '0';
                        end if;

                    when S_RX_START =>
                        if rx_baud_cnt = baud_div / 2 - 1 then
                            rx_baud_cnt <= 0;
                            if rx_q1 = '0' then
                                rx_state   <= S_RX_DATA;
                                rx_bit_cnt <= 0;
                            else
                                rx_state <= S_RX_IDLE;
                            end if;
                        else
                            rx_baud_cnt <= rx_baud_cnt + 1;
                        end if;

                    when S_RX_DATA =>
                        if rx_baud_cnt = baud_div - 1 then
                            rx_baud_cnt          <= 0;
                            rx_shift(rx_bit_cnt) <= rx_q1;
                            rx_parity            <= rx_parity xor rx_q1;
                            if rx_bit_cnt = data_bits - 1 then
                                rx_bit_cnt <= 0;
                                if parity_cfg = "00" then
                                    rx_state <= S_RX_STOP;
                                else
                                    rx_state <= S_RX_PARITY;
                                end if;
                            else
                                rx_bit_cnt <= rx_bit_cnt + 1;
                            end if;
                        else
                            rx_baud_cnt <= rx_baud_cnt + 1;
                        end if;

                    when S_RX_PARITY =>
                        if rx_baud_cnt = baud_div - 1 then
                            rx_baud_cnt <= 0;
                            rx_state    <= S_RX_STOP;
                        else
                            rx_baud_cnt <= rx_baud_cnt + 1;
                        end if;

                    when S_RX_STOP =>
                        if rx_baud_cnt = baud_div - 1 then
                            rx_baud_cnt <= 0;
                            -- Accetta SEMPRE il byte, come fa uart_rx_char del flash (che
                            -- funziona): NON scartare se lo stop bit campiona '0' (jitter,
                            -- baud 0.16% off, framing back-to-back) -> ricezione affidabile.
                            if cnt_v < RXF_DEPTH then
                                rxf(rxf_wr) <= rx_shift(7 downto 0);
                                rxf_wr <= (rxf_wr + 1) mod RXF_DEPTH;
                                cnt_v  := cnt_v + 1;
                            end if;
                            rx_state <= S_RX_IDLE;
                        else
                            rx_baud_cnt <= rx_baud_cnt + 1;
                        end if;

                    when others =>
                        rx_state <= S_RX_IDLE;
                end case;

                rxf_cnt <= cnt_v;
            end if;
        end if;
    end process seq_clk;

end UART_GENERIC_BEHAVIORAL;
