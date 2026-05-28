library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SPI_Flash is
    Generic (
        PRESCALER : natural := 16
    );
    Port (
        clk_i   : in  STD_LOGIC;
        rst_i   : in  STD_LOGIC;
        start_i : in  STD_LOGIC;
        tx_i    : in  STD_LOGIC_VECTOR(7 downto 0);
        rx_o    : out STD_LOGIC_VECTOR(7 downto 0);
        busy_o  : out STD_LOGIC;
        done_o  : out STD_LOGIC;
        MOSI    : out STD_LOGIC;
        MISO    : in  STD_LOGIC;
        SCK     : out STD_LOGIC
    );
end SPI_Flash;

architecture SPI_Flash_BEHAVIORAL of SPI_Flash is

    constant HALF_PRE   : natural := PRESCALER / 2;
    constant TOTAL_BITS : natural := 8;

    signal shift_tx : std_logic_vector(7 downto 0) := (others => '0');
    signal shift_rx : std_logic_vector(7 downto 0) := (others => '0');
    signal SCK_s    : std_logic := '0';
    signal bit_cnt  : natural range 0 to TOTAL_BITS - 1 := 0;
    signal pre_cnt  : natural range 0 to PRESCALER - 1 := 0;
    signal active   : std_logic := '0';
    signal done_s   : std_logic := '0';

begin

    SCK    <= SCK_s;
    MOSI   <= shift_tx(7);
    rx_o   <= shift_rx;
    busy_o <= active;
    done_o <= done_s;

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                active   <= '0';
                SCK_s    <= '0';
                bit_cnt  <= 0;
                pre_cnt  <= 0;
                shift_tx <= (others => '0');
                shift_rx <= (others => '0');
                done_s   <= '0';
            else
                done_s <= '0';

                if start_i = '1' and active = '0' then
                    active   <= '1';
                    shift_tx <= tx_i;
                    bit_cnt  <= 0;
                    pre_cnt  <= 0;
                    SCK_s    <= '0';
                elsif active = '1' then
                    if pre_cnt = HALF_PRE - 1 then
                        SCK_s    <= '1';
                        shift_rx <= shift_rx(6 downto 0) & MISO;
                        pre_cnt  <= pre_cnt + 1;
                    elsif pre_cnt = PRESCALER - 1 then
                        SCK_s   <= '0';
                        pre_cnt <= 0;
                        if bit_cnt = TOTAL_BITS - 1 then
                            active <= '0';
                            done_s <= '1';
                        else
                            shift_tx <= shift_tx(6 downto 0) & '0';
                            bit_cnt  <= bit_cnt + 1;
                        end if;
                    else
                        pre_cnt <= pre_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end SPI_Flash_BEHAVIORAL;
