library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx_char is
    Generic (
        CLK_HZ : integer := 27_000_000;
        BAUD   : integer := 115200
    );
    Port (
        clk_i   : in  std_logic;
        rst_i   : in  std_logic;
        rx_i    : in  std_logic;
        data_o  : out std_logic_vector(7 downto 0);
        valid_o : out std_logic
    );
end uart_rx_char;

architecture behavioral of uart_rx_char is

    constant DIV  : integer := CLK_HZ / BAUD;
    constant HALF : integer := DIV / 2;

    type state_t is (ST_IDLE, ST_START, ST_DATA, ST_STOP);
    signal state : state_t := ST_IDLE;

    signal baud_cnt : integer range 0 to DIV - 1 := 0;
    signal bit_cnt  : integer range 0 to 7 := 0;
    signal sreg     : std_logic_vector(7 downto 0) := (others => '0');
    signal data_r   : std_logic_vector(7 downto 0) := (others => '0');
    signal valid_r  : std_logic := '0';

    signal rx_meta : std_logic := '1';
    signal rx_s    : std_logic := '1';

begin

    data_o  <= data_r;
    valid_o <= valid_r;

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            rx_meta <= rx_i;
            rx_s    <= rx_meta;

            if rst_i = '0' then
                state    <= ST_IDLE;
                valid_r  <= '0';
                baud_cnt <= 0;
                bit_cnt  <= 0;
            else
                valid_r <= '0';
                case state is

                    when ST_IDLE =>
                        if rx_s = '0' then
                            baud_cnt <= 0;
                            state    <= ST_START;
                        end if;

                    when ST_START =>
                        if baud_cnt = HALF - 1 then
                            baud_cnt <= 0;
                            if rx_s = '0' then
                                bit_cnt <= 0;
                                state   <= ST_DATA;
                            else
                                state <= ST_IDLE;
                            end if;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;

                    when ST_DATA =>
                        if baud_cnt = DIV - 1 then
                            baud_cnt <= 0;
                            sreg <= rx_s & sreg(7 downto 1);
                            if bit_cnt = 7 then
                                state <= ST_STOP;
                            else
                                bit_cnt <= bit_cnt + 1;
                            end if;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;

                    when ST_STOP =>
                        if baud_cnt = DIV - 1 then
                            baud_cnt <= 0;
                            data_r  <= sreg;
                            valid_r <= '1';
                            state   <= ST_IDLE;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

end behavioral;
