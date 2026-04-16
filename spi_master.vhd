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
        --adr_i   : in  STD_LOGIC_VECTOR(7 downto 0);
        dat_i   : in  STD_LOGIC_VECTOR(31 downto 0);
        dat_o   : out STD_LOGIC_VECTOR(31 downto 0);
        ack_o   : out STD_LOGIC;

        MOSI : out STD_LOGIC;
        MISO : in  STD_LOGIC;
        SCK  : out STD_LOGIC;
        CS   : out STD_LOGIC
    );
end SPI_Master;

architecture SPI_Master_STRUCTURAL of SPI_Master is
    constant CPOL : std_logic := '0'; 
    constant CPHA : std_logic := '0'; 

    type state_type is (S_IDLE, S_START, S_READING, S_RESTART, S_CLOSE);
    signal curr_state, next_state : state_type;

    signal prescaler_cki : natural range 0 to 31 := 0;
    signal data_i_s : std_logic_vector(31 downto 0);
    signal data_o_s : std_logic_vector(31 downto 0);
    signal start : std_logic;

    signal SCK_s, CS_s : std_logic;
    signal MISO_counter : natural range 0 to 31 := 0;

begin

    dat_o <= data_o_s;
    SCK <= SCK_s;
    CS <= CS_s;
    MOSI <= '0';
    
    seq_process_cki: process(clk_i) 
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                ack_o <= '0';
                start <= '0';
                SCK_s <= '0';
                prescaler_cki <= 0;
                MISO_counter <= 0;
                data_o_s <= (others => '0');
                curr_state <= S_IDLE;
            else
                curr_state <= next_state;
                
                if prescaler_cki = 15 then
                    SCK_s <= '1';
                    prescaler_cki <= prescaler_cki + 1;
                    
                    if curr_state = S_READING then
                        data_o_s(MISO_counter) <= MISO;
                        
                        if MISO_counter = 31 then
                            MISO_counter <= 0;
                        else
                            MISO_counter <= MISO_counter + 1;
                        end if;
                    end if;

                elsif prescaler_cki = 31 then
                    SCK_s <= '0';
                    prescaler_cki <= 0;
                else
                    prescaler_cki <= prescaler_cki + 1;
                end if;
                
                if cyc_i = '1' AND stb_i = '1' then 
                    if we_i = '1' then
                        if dat_i = x"00000001" then
                            start <= '1';
                            prescaler_cki <= 0;
                            SCK_s <= '0';
                        elsif dat_i = x"00000000" then 
                            start <= '0';
                        end if;
                    end if;
                    if we_i = '0' then
                        ack_o <= '1';
                    end if;
                    

                end if;
            end if;
        end if;
    end process seq_process_cki; 

    comb_process_sck: process(curr_state, start)
    begin
        next_state <= curr_state;
        CS_s <= '0'; 
        
        case curr_state is
            when S_IDLE =>
                CS_s <= '1';
                if start = '1' then
                    next_state <= S_START;
                else
                    next_state <= S_IDLE;
                end if;
                
            when S_START =>
                next_state <= S_READING;

            when S_READING =>
                if start = '1' then
                    next_state <= S_READING;
                else
                    next_state <= S_CLOSE;
                end if;
                
            when S_CLOSE => 
                CS_s <= '1';
                next_state <= S_IDLE;
                
            when others =>
                CS_s <= '1';
                next_state <= S_IDLE;
                
        end case;
    end process comb_process_sck;

end SPI_Master_STRUCTURAL;