library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SPI_Master is
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

        MOSI : out STD_LOGIC;
        MISO : in  STD_LOGIC;
        SCK  : out STD_LOGIC;
        CS   : out STD_LOGIC
    );
end SPI_Master;

architecture SPI_Master_BEHAVIORAL of SPI_Master is

    type state_type is (S_IDLE, S_READING, S_CLOSE);
    signal curr_state : state_type;

    signal prescaler_cki : natural range 0 to 31 := 0;
    signal shift_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal data_o_s      : std_logic_vector(31 downto 0) := (others => '0');
    signal data_ready    : std_logic := '0';
    signal start         : std_logic := '0';

    signal SCK_s, CS_s   : std_logic;
    signal MISO_counter  : natural range 0 to 31 := 0;

begin

    dat_o <= data_o_s;
    SCK   <= SCK_s;
    CS    <= CS_s;
    MOSI  <= '0';
    
    seq_clk: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                ack_o         <= '0';
                start         <= '0';
                SCK_s         <= '0';
                prescaler_cki <= 0;
                MISO_counter  <= 0;
                shift_reg     <= (others => '0');
                data_o_s      <= (others => '0');
                data_ready    <= '0';
                curr_state    <= S_IDLE;
            else
                ack_o <= '0';
                CS_s  <= '0';

                if cyc_i = '1' and stb_i = '1' then
                    if we_i = '1' then
                        if adr_i = x"01" then
                            start         <= '1';
                        elsif adr_i = x"02" then
                            start <= '0';
                        end if;
                        ack_o <= '1';
                    else
                        --LETTURA
                        if adr_i = x"00" then
                            if data_ready = '1' then
                                ack_o <= '1';
                            end if;
                        end if;
                        --RESET FLAG
                        if adr_i = x"03" then
                            data_ready <= '0';
                            ack_o      <= '1';
                        end if;
                    end if;
                end if;
                case curr_state is
                    when S_IDLE =>
                        CS_s <= '1';
                        if start = '1' then
                            curr_state <= S_READING;
                            ack_o   <= '1';
                        else 
                            curr_state <= S_IDLE;
                        end if;
                    when S_READING =>
                        if prescaler_cki = 15 then
                            SCK_s         <= '1';
                            prescaler_cki <= prescaler_cki + 1;
                            if MISO_counter = 31 then
                                data_o_s     <= shift_reg(30 downto 0) & MISO;
                                data_ready   <= '1';
                                shift_reg    <= (others => '0');
                                MISO_counter <= 0;
                            else
                                shift_reg    <= shift_reg(30 downto 0) & MISO;
                                MISO_counter <= MISO_counter + 1;
                            end if;
                        elsif prescaler_cki = 31 then
                            SCK_s         <= '0';
                            prescaler_cki <= 0;
                        else
                            prescaler_cki <= prescaler_cki + 1;
                        end if;
                        if start = '1' then
                            curr_state <= S_READING;
                        else
                            curr_state <= S_CLOSE;
                        end if;

                    when S_CLOSE =>
                        CS_s       <= '1';
                        curr_state <= S_IDLE;

                    when others =>
                        CS_s       <= '1';
                        curr_state <= S_IDLE;
                end case;
            end if;
        end if;
    end process seq_clk;


end SPI_Master_BEHAVIORAL;
