library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_display is
    generic (
        PRESCALER : natural := 6
    );
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        cyc_i : in  std_logic;
        stb_i : in  std_logic;
        we_i  : in  std_logic;
        adr_i : in  std_logic_vector(7 downto 0);
        dat_i : in  std_logic_vector(31 downto 0);
        dat_o : out std_logic_vector(31 downto 0);
        ack_o : out std_logic;
        SCK_o : out std_logic;
        SDA_o : out std_logic;
        DC_o  : out std_logic;
        RST_o : out std_logic;
        CS_o  : out std_logic
    );
end spi_display;

architecture rtl of spi_display is

    constant HALF_PRE : natural := PRESCALER / 2;

    -- mode 3 transmit only shifter: sck rests high, the bit is driven while
    -- sck is low and the panel samples it on the rising edge, msb first
    type state_t is (S_IDLE, S_DRIVE, S_SAMPLE);
    signal curr_state, next_state : state_t := S_IDLE;

    signal shift_tx : std_logic_vector(7 downto 0) := (others => '0');
    signal sck_s    : std_logic := '1';
    signal dc_r     : std_logic := '0';
    signal rst_r    : std_logic := '0';
    signal cs_r     : std_logic := '1';
    signal bit_cnt  : natural range 0 to 7 := 0;
    signal pre_cnt  : natural range 0 to PRESCALER - 1 := 0;
    signal start    : std_logic := '0';

begin

    SCK_o <= sck_s;
    SDA_o <= shift_tx(7);
    DC_o  <= dc_r;
    RST_o <= rst_r;
    CS_o  <= cs_r;

    dat_o <= (0 => '1', others => '0') when (adr_i = x"08" and curr_state /= S_IDLE)
             else (others => '0');

    -- next state logic
    p_comb : process(curr_state, start, bit_cnt, pre_cnt)
    begin
        next_state <= curr_state;
        case curr_state is
            when S_IDLE =>
                if start = '1' then
                    next_state <= S_DRIVE;
                end if;
            when S_DRIVE =>
                if pre_cnt = HALF_PRE - 1 then
                    next_state <= S_SAMPLE;
                end if;
            when S_SAMPLE =>
                if pre_cnt = PRESCALER - 1 then
                    if bit_cnt = 7 then
                        next_state <= S_IDLE;
                    else
                        next_state <= S_DRIVE;
                    end if;
                end if;
        end case;
    end process;

    -- state register, bus interface and shift datapath
    p_sync : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                curr_state <= S_IDLE;
                ack_o    <= '0';
                sck_s    <= '1';
                dc_r     <= '0';
                rst_r    <= '0';
                cs_r     <= '1';
                bit_cnt  <= 0;
                pre_cnt  <= 0;
                shift_tx <= (others => '0');
                start    <= '0';
            else
                curr_state <= next_state;
                ack_o <= '0';
                start <= '0';

                -- ack is held for the whole strobe, the cpu bus loses
                -- single cycle pulses
                if cyc_i = '1' and stb_i = '1' then
                    ack_o <= '1';
                    if we_i = '1' then
                        case adr_i is
                            when x"00" =>
                                if curr_state = S_IDLE then
                                    shift_tx <= dat_i(7 downto 0);
                                    start    <= '1';
                                end if;
                            when x"04" =>
                                dc_r  <= dat_i(0);
                                rst_r <= dat_i(1);
                                cs_r  <= not dat_i(2);
                            when others =>
                                null;
                        end case;
                    end if;
                end if;

                -- sck follows the state, registered so the pin is clean
                if next_state = S_DRIVE then
                    sck_s <= '0';
                elsif next_state = S_SAMPLE then
                    sck_s <= '1';
                end if;

                if curr_state = S_IDLE then
                    pre_cnt <= 0;
                    bit_cnt <= 0;
                else
                    if pre_cnt = PRESCALER - 1 then
                        pre_cnt <= 0;
                    else
                        pre_cnt <= pre_cnt + 1;
                    end if;
                    if curr_state = S_SAMPLE and pre_cnt = PRESCALER - 1
                       and bit_cnt < 7 then
                        shift_tx <= shift_tx(6 downto 0) & '0';
                        bit_cnt  <= bit_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end rtl;
