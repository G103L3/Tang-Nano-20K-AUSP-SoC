library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


--
-- Register map (WB slave, byte-addressed, offset rispetto a 0x30000000):
--   0x01  WR: start   — avvia acquisizione continua SPI→SDRAM
--   0x02  WR: stop    — ferma acquisizione (azzera start)
--   0x03  WR: base    — imposta indirizzo base SDRAM (dat[20:0] = word address 21-bit)
--
-- Il DMA legge 32 bit dall'SPI e li scrive come 2 parole da 16 bit in SDRAM:
--   word[N]   = SPI[31:16],  word[N+1] = SPI[15:0]
-- IRQ ogni 512 parole SDRAM scritte (256 letture SPI); dopo 1024 parole torna a base.

entity dma is
    port (
        clk_i    : in  std_logic;
        rst_i    : in  std_logic; 

        -- Wishbone Slave: CPU configures the DMA
        s_cyc_i  : in  std_logic;
        s_stb_i  : in  std_logic;
        s_we_i   : in  std_logic;
        s_adr_i  : in  std_logic_vector(31 downto 0);
        s_dat_i  : in  std_logic_vector(31 downto 0);
        s_dat_o  : out std_logic_vector(31 downto 0);
        s_ack_o  : out std_logic;

        -- Wishbone Master
        m_cyc_o  : out std_logic;
        m_stb_o  : out std_logic;
        m_we_o   : out std_logic;
        m_adr_o  : out std_logic_vector(31 downto 0);
        m_dat_o  : out std_logic_vector(31 downto 0);
        m_dat_i  : in  std_logic_vector(31 downto 0);
        m_ack_i  : in  std_logic;

        irq_o    : out std_logic
    );
end dma;

architecture behavioral of dma is

    type state_type is (S_IDLE, S_OPEN, S_CLOSE, S_READ_1, S_READ_2, S_R_DEV, S_WRITE_1, S_WRITE_2, S_SCALER, S_IRQ, S_C_BASE);
    signal curr_state    : state_type;
    signal data          : std_logic_vector(31 downto 0) := (others => '0');
    signal scaler_counter: natural range 0 to 1023 := 0;
    signal address_local : unsigned(20 downto 0) := (others => '0');
    signal base_address  : unsigned(20 downto 0) := (others => '0');
    signal start         : std_logic := '0';
    constant lost_cycles        : natural := 0; 
    constant prescaler_cycles   : natural := 32;
    constant total_cycles       : natural := prescaler_cycles * 32;

    
begin

    seq_clk: process(clk_i)
    begin
        if rising_edge(clk_i) then
            s_ack_o <= '0';
            s_dat_o <= (others => '0');
            m_cyc_o <= '0';
            m_stb_o <= '0';
            m_we_o  <= '0';
            irq_o   <= '0';

            if rst_i = '0' then
                curr_state     <= S_IDLE;
                m_adr_o        <= (others => '0');
                m_dat_o        <= (others => '0');
                start          <= '0';
                base_address   <= (others => '0');
                address_local  <= (others => '0');
                scaler_counter <= 0;
            else
                if s_cyc_i = '1' and s_stb_i = '1' then
                    s_ack_o <= '1';
                    if s_we_i = '1' then
                        if s_adr_i = x"00000003" then
                            base_address <= unsigned(s_dat_i(20 downto 0));
                        elsif s_adr_i = x"00000001" then
                            start <= '1';
                        elsif s_adr_i = x"00000002" then
                            start <= '0';
                        end if;
                    end if;
                end if;

                case curr_state is
                    when S_IDLE =>
                        address_local <= base_address;
                        if start = '1' then
                            curr_state <= S_OPEN;
                        end if;

                    when S_OPEN =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '1';
                        m_adr_o <= x"40000001";
                        m_dat_o <= x"00000001";
                        if m_ack_i = '1' then
                            m_cyc_o        <= '0';
                            m_stb_o        <= '0';
                            scaler_counter <= 0;
                            curr_state     <= S_SCALER;
                        end if;

                    when S_SCALER =>
                        if scaler_counter = total_cycles-1 then --Ci sono 32 * 32 = 2^5 * 2^5 = 2^10 = 1024 inputs prima dell'spi output
                            scaler_counter <= 0;
                            curr_state     <= S_READ_1;
                        else
                            scaler_counter <= scaler_counter + 1;
                        end if;

                    when S_READ_1 =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '0';
                        m_adr_o <= x"40000000";
                        if m_ack_i = '1' then
                            data    <= m_dat_i;
                            m_cyc_o <= '0';
                            m_stb_o <= '0';
                            curr_state <= S_R_DEV;
                        end if;

                    when S_R_DEV =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '1';
                        m_adr_o <= x"40000003";
                        m_dat_o <= (others => '0');
                        if m_ack_i = '1' then
                            m_cyc_o    <= '0';
                            m_stb_o    <= '0';
                            curr_state <= S_WRITE_1;
                        end if;

                    when S_WRITE_1 =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '1';
                        m_adr_o <= "00000000000" & std_logic_vector(address_local);
                        m_dat_o <= x"0000" & data(31 downto 16);
                        if m_ack_i = '1' then
                            address_local <= address_local + 1;
                            m_cyc_o       <= '0';
                            m_stb_o       <= '0';
                            curr_state    <= S_WRITE_2;
                        end if;

                    when S_WRITE_2 =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '1';
                        m_adr_o <= "00000000000" & std_logic_vector(address_local);
                        m_dat_o <= x"0000" & data(15 downto 0);
                        if m_ack_i = '1' then
                            address_local <= address_local + 1;
                            m_cyc_o       <= '0';
                            m_stb_o       <= '0';
                            if to_integer(address_local + 1 - base_address) mod 512 = 0 then
                                curr_state <= S_IRQ;
                            else
                                scaler_counter <= 12; --lo imposta a 12 perché è il numero di cicli persi rispetto al SPI in questo punto
                                curr_state     <= S_SCALER;
                            end if;
                        end if;

                    when S_IRQ =>
                        irq_o <= '1';
                        if to_integer(address_local - base_address) = 1024 then
                            curr_state <= S_C_BASE;
                        else
                            scaler_counter <= 13; --lo imposta a 13 perché è il numero di cicli persi rispetto al SPI in questo punto
                            curr_state     <= S_SCALER;
                        end if;

                    when S_C_BASE =>
                        irq_o         <= '1';
                        address_local <= base_address;
                        scaler_counter <= 14; --lo imposta a 14 perché è il numero di cicli persi rispetto al SPI in questo punto
                        curr_state    <= S_SCALER;

                    when S_CLOSE =>
                        m_cyc_o <= '1';
                        m_stb_o <= '1';
                        m_we_o  <= '1';
                        m_adr_o <= x"40000002";
                        m_dat_o <= x"00000000";
                        if m_ack_i = '1' then
                            m_cyc_o    <= '0';
                            m_stb_o    <= '0';
                            curr_state <= S_IDLE;
                        end if;

                    when others =>
                        curr_state <= S_IDLE;
                end case;
            end if;
        end if;
    end process;

end behavioral;
