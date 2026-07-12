library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

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
        dbg_cap_o    : out STD_LOGIC;
        MOSI         : out STD_LOGIC;
        MISO         : in  STD_LOGIC;
        SCK          : out STD_LOGIC;
        CS           : out STD_LOGIC
    );
end SPI_Master;

architecture SPI_Master_BEHAVIORAL of SPI_Master is

    -- 16 sck periods of 54 clocks each: one mcp3201 frame every 864 cycles
    constant PRESCALER  : natural := 54;
    constant HALF_PRE   : natural := PRESCALER / 2;
    constant TOTAL_BITS : natural := 16;

    -- S_SHIFT covers bit periods 0 to 13 with cs low, the 12 data bits are
    -- captured on periods 2 to 13; S_GAP is periods 14 and 15 with cs high
    type state_t is (S_IDLE, S_SHIFT, S_GAP);
    signal curr_state, next_state : state_t := S_IDLE;

    signal shift_reg    : std_logic_vector(11 downto 0) := (others => '0');
    signal data_o_s     : std_logic_vector(31 downto 0) := (others => '0');
    signal data_ready_s : std_logic := '0';
    signal start        : std_logic := '0';
    signal SCK_s        : std_logic := '0';
    signal CS_s         : std_logic := '1';
    signal bit_cnt      : natural range 0 to TOTAL_BITS - 1 := 0;
    signal pre_cnt      : natural range 0 to PRESCALER - 1 := 0;

begin

    dat_o        <= data_o_s;
    data_ready_o <= data_ready_s;
    dbg_cap_o    <= MISO when (curr_state = S_SHIFT and bit_cnt >= 2) else '0';
    SCK          <= SCK_s;
    CS           <= CS_s;
    MOSI         <= '0';

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
                if bit_cnt = 13 and pre_cnt = PRESCALER - 1 then
                    next_state <= S_GAP;
                end if;
            when S_GAP =>
                if bit_cnt = TOTAL_BITS - 1 and pre_cnt = PRESCALER - 1 then
                    if start = '1' then
                        next_state <= S_SHIFT;
                    else
                        next_state <= S_IDLE;
                    end if;
                end if;
        end case;
    end process;

    -- state register, bus interface and shift datapath
    p_sync : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                curr_state   <= S_IDLE;
                ack_o        <= '0';
                start        <= '0';
                SCK_s        <= '0';
                CS_s         <= '1';
                pre_cnt      <= 0;
                bit_cnt      <= 0;
                shift_reg    <= (others => '0');
                data_o_s     <= (others => '0');
                data_ready_s <= '0';
            else
                curr_state <= next_state;
                ack_o <= '0';

                if cyc_i = '1' and stb_i = '1' then
                    if we_i = '1' then
                        case adr_i is
                            when x"04" =>
                                start <= '1';
                                ack_o <= '1';
                            when x"08" =>
                                start <= '0';
                                ack_o <= '1';
                            when x"0C" =>
                                data_ready_s <= '0';
                                ack_o        <= '1';
                            when others =>
                                ack_o <= '1';
                        end case;
                    else
                        -- the sample read acks only when a sample is ready
                        if adr_i = x"00" then
                            if data_ready_s = '1' then
                                ack_o <= '1';
                            end if;
                        elsif adr_i = x"0C" then
                            data_ready_s <= '0';
                            ack_o        <= '1';
                        end if;
                    end if;
                end if;

                case curr_state is
                    when S_IDLE =>
                        CS_s    <= '1';
                        SCK_s   <= '0';
                        bit_cnt <= 0;
                        pre_cnt <= 0;

                    when S_SHIFT =>
                        CS_s <= '0';
                        if pre_cnt = HALF_PRE - 1 then
                            SCK_s <= '1';
                            if bit_cnt >= 2 then
                                shift_reg <= shift_reg(10 downto 0) & MISO;
                            end if;
                            pre_cnt <= pre_cnt + 1;
                        elsif pre_cnt = PRESCALER - 1 then
                            SCK_s   <= '0';
                            pre_cnt <= 0;
                            if bit_cnt = 13 then
                                -- last data bit: latch the sample and flag it
                                data_o_s     <= x"00000" & shift_reg;
                                data_ready_s <= '1';
                                shift_reg    <= (others => '0');
                            end if;
                            bit_cnt <= bit_cnt + 1;
                        else
                            pre_cnt <= pre_cnt + 1;
                        end if;

                    when S_GAP =>
                        CS_s  <= '1';
                        SCK_s <= '0';
                        if pre_cnt = PRESCALER - 1 then
                            pre_cnt <= 0;
                            if bit_cnt = TOTAL_BITS - 1 then
                                bit_cnt <= 0;
                            else
                                bit_cnt <= bit_cnt + 1;
                            end if;
                        else
                            pre_cnt <= pre_cnt + 1;
                        end if;
                end case;

            end if;
        end if;
    end process;

end SPI_Master_BEHAVIORAL;
