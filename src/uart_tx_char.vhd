library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Semplice UART TX 8N1.
-- Su stb_i pulse di 1 colpo, serializza char_i sul filo tx_o.
-- Mentre trasmette busy_o = '1' (un nuovo stb_i durante busy viene ignorato).
entity uart_tx_char is
    Generic (
        CLK_HZ : integer := 27_000_000;
        BAUD   : integer := 115200
    );
    Port (
        clk_i  : in  std_logic;
        rst_i  : in  std_logic;     -- reset attivo basso
        char_i : in  std_logic_vector(7 downto 0);
        stb_i  : in  std_logic;
        tx_o   : out std_logic;
        busy_o : out std_logic
    );
end uart_tx_char;

architecture behavioral of uart_tx_char is

    constant DIV : integer := CLK_HZ / BAUD;

    type state_t is (ST_IDLE, ST_START, ST_DATA, ST_STOP);
    signal state : state_t := ST_IDLE;

    signal baud_cnt : integer range 0 to DIV - 1 := 0;
    signal bit_cnt  : integer range 0 to 7 := 0;
    signal sreg     : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_r     : std_logic := '1';

begin

    tx_o   <= tx_r;
    busy_o <= '0' when state = ST_IDLE else '1';

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                state    <= ST_IDLE;
                tx_r     <= '1';
                baud_cnt <= 0;
                bit_cnt  <= 0;
                sreg     <= (others => '0');
            else
                case state is

                    when ST_IDLE =>
                        tx_r     <= '1';
                        baud_cnt <= 0;
                        if stb_i = '1' then
                            sreg  <= char_i;
                            state <= ST_START;
                        end if;

                    when ST_START =>
                        tx_r <= '0';
                        if baud_cnt = DIV - 1 then
                            baud_cnt <= 0;
                            bit_cnt  <= 0;
                            state    <= ST_DATA;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;

                    when ST_DATA =>
                        tx_r <= sreg(0);
                        if baud_cnt = DIV - 1 then
                            baud_cnt <= 0;
                            sreg     <= '0' & sreg(7 downto 1);
                            if bit_cnt = 7 then
                                state <= ST_STOP;
                            else
                                bit_cnt <= bit_cnt + 1;
                            end if;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;

                    when ST_STOP =>
                        tx_r <= '1';
                        if baud_cnt = DIV - 1 then
                            baud_cnt <= 0;
                            state    <= ST_IDLE;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

end behavioral;
