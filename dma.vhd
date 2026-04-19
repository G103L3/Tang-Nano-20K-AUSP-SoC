library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


--
-- Register map (WB slave, byte-addressed, 32-bit words):
--   0x00  CTRL   [0]=start  [1]=enable  (write 1 to start, auto-clears)
--   0x04  SRC    source address in SDRAM
--   0x08  DST    destination address in SDRAM
--   0x0C  LEN    transfer length in 32-bit words
--   0x10  STATUS [0]=busy   [1]=done (write 1 to clear done flag)

entity dma is
    port (
        clk_i    : in  std_logic;
        rst_i    : in  std_logic;  -- active low

        -- Wishbone Slave: CPU configures the DMA
        s_cyc_i  : in  std_logic;
        s_stb_i  : in  std_logic;
        s_we_i   : in  std_logic;
        s_adr_i  : in  std_logic_vector(31 downto 0);
        s_dat_i  : in  std_logic_vector(31 downto 0);
        s_dat_o  : out std_logic_vector(31 downto 0);
        s_ack_o  : out std_logic;

        -- Wishbone Master: DMA accesses SDRAM via memory_arbiter M1
        m_cyc_o  : out std_logic;
        m_stb_o  : out std_logic;
        m_we_o   : out std_logic;
        m_adr_o  : out std_logic_vector(31 downto 0);
        m_dat_o  : out std_logic_vector(31 downto 0);
        m_dat_i  : in  std_logic_vector(31 downto 0);
        m_ack_i  : in  std_logic;

        -- Interrupt to CPU (connect to irq_in(20) of PicoRV32)
        irq_o    : out std_logic
    );
end dma;

architecture behavioral of dma is

    type state_type is ( S_IDLE, S_OPEN, S_CLOSE, S_READ_1, S_READ_2, S_R_DEV, S_WRITE_1, S_WRITE_2, S_SCALER, S_IRQ, S_C_BASE);
    signal curr_state, next_state : state_type := S_IDLE;
    signal data : std_logic_vector(31 downto 0);
    signal scaler_counter: natural range 0 to 31;
    signal address_local : unsigned(20 downto 0);
    signal base_address : std_logic_vectr(20 downto 0);

begin


    seq_clk: process(clk_i)
        variable reg_sel : std_logic_vector(3 downto 0);
    begin
        if rising_edge(clk_i) then
            s_ack_o  <= '0';
            s_dat_o  <= (others => '0');
            start_req <= '0';

            if rst_i = '0' then
                s_ack_o <= '0';
                s_dat_o <= (others => '0');
                m_adr_o <= (others => '0');
                m_dat_o <= (others => '0');
            elsif s_cyc_i = '1' and s_stb_i = '1' then
                s_ack_o <= '1';

                if s_we_i = '1' then
                    -- Write
                    case reg_sel is
                        if s_adr_i = x"00000003" then
                            base_address <= s_dat_i;
                        elsif s_adr_i = x"00000001" then
                            start <= '1';
                        elsif s_adr_i = x"00000002" then
                            start <= '0';
                        end if;
                    end case;
                else
                    -- Read
                    case reg_sel is

                    end case;
                end if;
            end if;
        end if;
    end process;


    m_cyc_o <= '0';
    m_stb_o <= '0';
    m_we_o  <= '0';
    m_adr_o <= (others => '0');
    m_dat_o <= (others => '0');
    irq_o   <= '0';

    comb_proc: process(curr_state, samples_counter, scaler_counter) begin
        case curr_state is
            when S_IDLE =>
                address_local <= unsigned(base_address);
                if start = '1' then
                    next_state <= S_OPEN;
                else
                    next_state <= S_IDLE;
                end if;
            when S_OPEN =>
                m_cyc_o     <= '1';
                m_stb_o     <= '1';
                m_we_o      <= '1';
                m_addr_o    <= x"40000001";
                if m_ack_i = '1' then 
                    next_state <= S_CLOSE;
                else
                    next_state <= S_OPEN;
                end if;
            when S_READ_1 =>
                m_we_o      <= '0';
                m_addr_o    <= x"40000000";
                m_irq_o     <= '1';
                if m_ack_i = '1' then
                    next_state <= S_READ_2;
                else
                    next_state <= S_READ_1;
                end if;
            when S_READ_2 =>
                data        <= m_data_i;
                m_addr_o    <= x"3";
                next_state  <= S_WRITE_1;
            when S_WRITE_1 =>
                m_addr_o        <= "00000000000" & address_local;
                m_dat_o         <= data(31 downto to 16); --Scrive i primi 16 bit
                address_local   <= address_local + 1;
                if ack = '1' then
                    next_state <= S_WRITE_2;
                else
                    next_state <= S_WRITE_1;
                end if;
            when S_WRITE_2 =>
                m_addr_o        <= "00000000000" & address_local;
                m_dat_o         <= data(15 downto 0); --Scrive gli ultimi 16 bit
                address_local   <= address_local + 1;
                if ack = '1' then
                    if (address_local - base_address mod 512) = 0 then --inserisce i blocchi in maniera continua
                                                      --quando si arriva alla fine del secondo
                                                      --blocco l'indirizzo torna all'indirizzo base del primo blocco
                        next_state <= S_IRQ;
                    else 
                        next_state <= S_SCALER;
                    end if;                        
                else
                    next_state <= S_WRITE_2;
                end if;
            when S_IRQ =>
                m_irq_o <= '1';
                if address_local - base_address = 1024 then --inserisce i blocchi in maniera continua
                                    --quando si arriva alla fine del secondo
                                    --blocco l'indirizzo torna all'indirizzo base del primo blocco
                    next_state <= S_C_BASE;
                else
                    next_state <= S_SCALER;    
            when S_C_BASE =>
                m_irq_o <= '1';
                address_local <= base_address;
                next_state <= S_SCALER;
            when S_SCALER => 
                scaler_counter <= scaler_counter + 1;
                if scaler_counter = 31 then
                    next_state <= S_READ_1;
                else
                    next_state <= S_SCALER;
                end if;
            when others => 
                next_state <= S_IDLE;
            end case;
    end process comb_proc;

end behavioral;
