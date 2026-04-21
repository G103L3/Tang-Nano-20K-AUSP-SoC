library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- MCP3201-BI/P SPI ADC driver
-- Frame: 16 bit-periods x 36 clk = 576 clk/sample (~46.875 kHz at 27 MHz)
--   periods  0     : null bit  (CS low,  SCK toggles, MISO not captured)
--   periods  1-12  : data bits B11..B0 (CS low,  SCK toggles, capture on rising edge)
--   periods 13-15  : idle      (CS high, SCK low)
-- dat_o[11:0] = 12-bit sample; dat_o[31:12] = 0
-- data_ready_o is a combinational copy of the internal flag for fast DMA polling

entity SPI_Master is
    Port (
        clk_i        : in  STD_LOGIC;
        rst_i        : in  STD_LOGIC;
        cyc_i        : in  STD_LOGIC;
        stb_i        : in  STD_LOGIC;
        we_i         : in  STD_LOGIC;
        adr_i        : in  STD_LOGIC_VECTOR(7 downto 0);
        dat_i        : in  STD_LOGIC_VECTOR(31 downto 0);
        dat_o        : out STD_LOGIC_VECTOR(31 downto 0);
        ack_o        : out STD_LOGIC;
        data_ready_o : out STD_LOGIC;
        MOSI         : out STD_LOGIC;
        MISO         : in  STD_LOGIC;
        SCK          : out STD_LOGIC;
        CS           : out STD_LOGIC
    );
end SPI_Master;

architecture SPI_Master_BEHAVIORAL of SPI_Master is

    constant PRESCALER  : natural := 36;
    constant HALF_PRE   : natural := PRESCALER / 2;
    constant TOTAL_BITS : natural := 16;

    signal shift_reg    : std_logic_vector(11 downto 0) := (others => '0');
    signal data_o_s     : std_logic_vector(31 downto 0) := (others => '0');
    signal data_ready_s : std_logic := '0';
    signal start        : std_logic := '0';
    signal SCK_s        : std_logic := '0';
    signal CS_s         : std_logic := '1';
    signal bit_cnt      : natural range 0 to TOTAL_BITS - 1 := 0;
    signal pre_cnt      : natural range 0 to PRESCALER - 1 := 0;
    signal active       : std_logic := '0';

begin

    dat_o        <= data_o_s;
    data_ready_o <= data_ready_s;
    SCK          <= SCK_s;
    CS           <= CS_s;
    MOSI         <= '0';

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                ack_o        <= '0';
                start        <= '0';
                SCK_s        <= '0';
                CS_s         <= '1';
                pre_cnt      <= 0;
                bit_cnt      <= 0;
                shift_reg    <= (others => '0');
                data_o_s     <= (others => '0');
                data_ready_s <= '0';
                active       <= '0';
            else
                ack_o <= '0';

                if cyc_i = '1' and stb_i = '1' then
                    if we_i = '1' then
                        case adr_i is
                            when x"01" =>
                                start <= '1';
                                ack_o <= '1';
                            when x"02" =>
                                start <= '0';
                                ack_o <= '1';
                            when x"03" =>
                                data_ready_s <= '0';
                                ack_o        <= '1';
                            when others =>
                                ack_o <= '1';
                        end case;
                    else
                        if adr_i = x"00" then
                            if data_ready_s = '1' then
                                ack_o <= '1';
                            end if;
                        elsif adr_i = x"03" then
                            data_ready_s <= '0';
                            ack_o        <= '1';
                        end if;
                    end if;
                end if;

                if start = '1' and active = '0' then
                    active  <= '1';
                    bit_cnt <= 0;
                    pre_cnt <= 0;
                    CS_s    <= '0';
                end if;

                if active = '1' then
                    if bit_cnt <= 12 then
                        CS_s <= '0';
                        if pre_cnt = HALF_PRE - 1 then
                            SCK_s <= '1';
                            if bit_cnt >= 1 then
                                shift_reg <= shift_reg(10 downto 0) & MISO;
                            end if;
                            pre_cnt <= pre_cnt + 1;
                        elsif pre_cnt = PRESCALER - 1 then
                            SCK_s   <= '0';
                            pre_cnt <= 0;
                            if bit_cnt = 12 then
                                data_o_s     <= x"00000" & shift_reg;
                                data_ready_s <= '1';
                                shift_reg    <= (others => '0');
                            end if;
                            if bit_cnt = TOTAL_BITS - 1 then
                                bit_cnt <= 0;
                                if start = '0' then
                                    active <= '0';
                                    CS_s   <= '1';
                                end if;
                            else
                                bit_cnt <= bit_cnt + 1;
                            end if;
                        else
                            pre_cnt <= pre_cnt + 1;
                        end if;
                    else
                        CS_s  <= '1';
                        SCK_s <= '0';
                        if pre_cnt = PRESCALER - 1 then
                            pre_cnt <= 0;
                            if bit_cnt = TOTAL_BITS - 1 then
                                bit_cnt <= 0;
                                if start = '0' then
                                    active <= '0';
                                end if;
                            else
                                bit_cnt <= bit_cnt + 1;
                            end if;
                        else
                            pre_cnt <= pre_cnt + 1;
                        end if;
                    end if;
                else
                    CS_s  <= '1';
                    SCK_s <= '0';
                end if;

            end if;
        end if;
    end process;

end SPI_Master_BEHAVIORAL;
