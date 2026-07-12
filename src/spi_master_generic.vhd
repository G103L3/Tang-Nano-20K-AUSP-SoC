library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_master_generic is
    generic (
        PRESCALER  : natural := 16;
        FRAME_BITS : natural := 8
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
        MOSI  : out std_logic;
        MISO  : in  std_logic;
        SCK   : out std_logic;
        CS    : out std_logic
    );
end spi_master_generic;

architecture rtl of spi_master_generic is

    constant HALF_PRE : natural := PRESCALER / 2;

    -- mode 0 shifter: mosi changes on the falling edge, miso is sampled on
    -- the rising edge, msb first; cs is a plain register bit so the firmware
    -- can hold it low across the bytes of one flash frame
    type state_t is (S_IDLE, S_SHIFT);
    signal curr_state, next_state : state_t := S_IDLE;

    signal shift_tx : std_logic_vector(FRAME_BITS - 1 downto 0) := (others => '0');
    signal shift_rx : std_logic_vector(FRAME_BITS - 1 downto 0) := (others => '0');
    signal sck_s    : std_logic := '0';
    signal cs_r     : std_logic := '1';
    signal bit_cnt  : natural range 0 to FRAME_BITS - 1 := 0;
    signal pre_cnt  : natural range 0 to PRESCALER - 1 := 0;
    signal start    : std_logic := '0';
    signal done_s   : std_logic := '0';

begin

    SCK  <= sck_s;
    CS   <= cs_r;
    MOSI <= shift_tx(FRAME_BITS - 1);

    -- next state logic
    p_comb : process(curr_state, start, bit_cnt, pre_cnt)
    begin
        next_state <= curr_state;
        case curr_state is
            when S_IDLE =>
                if start = '1' then
                    next_state <= S_SHIFT;
                end if;
            when S_SHIFT =>
                if bit_cnt = FRAME_BITS - 1 and pre_cnt = PRESCALER - 1 then
                    next_state <= S_IDLE;
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
                sck_s    <= '0';
                cs_r     <= '1';
                bit_cnt  <= 0;
                pre_cnt  <= 0;
                shift_tx <= (others => '0');
                shift_rx <= (others => '0');
                start    <= '0';
                done_s   <= '0';
                dat_o    <= (others => '0');
            else
                curr_state <= next_state;
                ack_o <= '0';
                start <= '0';

                if cyc_i = '1' and stb_i = '1' then
                    ack_o <= '1';
                    if we_i = '1' then
                        case adr_i is
                            when x"04" =>
                                if curr_state = S_IDLE then
                                    shift_tx <= dat_i(FRAME_BITS - 1 downto 0);
                                    start    <= '1';
                                    done_s   <= '0';
                                end if;
                            when x"08" =>
                                cs_r <= not dat_i(0);
                            when others =>
                                null;
                        end case;
                    else
                        case adr_i is
                            when x"00" =>
                                dat_o <= std_logic_vector(resize(unsigned(shift_rx), 32));
                            when x"0C" =>
                                -- done survives any number of status reads,
                                -- only the next txdata write clears it
                                dat_o    <= (others => '0');
                                if curr_state = S_SHIFT then dat_o(0) <= '1'; end if;
                                dat_o(1) <= done_s;
                            when others =>
                                dat_o <= (others => '0');
                        end case;
                    end if;
                end if;

                case curr_state is
                    when S_IDLE =>
                        sck_s   <= '0';
                        bit_cnt <= 0;
                        pre_cnt <= 0;

                    when S_SHIFT =>
                        if pre_cnt = HALF_PRE - 1 then
                            sck_s    <= '1';
                            shift_rx <= shift_rx(FRAME_BITS - 2 downto 0) & MISO;
                            pre_cnt  <= pre_cnt + 1;
                        elsif pre_cnt = PRESCALER - 1 then
                            sck_s   <= '0';
                            pre_cnt <= 0;
                            if bit_cnt = FRAME_BITS - 1 then
                                done_s <= '1';
                            else
                                shift_tx <= shift_tx(FRAME_BITS - 2 downto 0) & '0';
                                bit_cnt  <= bit_cnt + 1;
                            end if;
                        else
                            pre_cnt <= pre_cnt + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

end rtl;
