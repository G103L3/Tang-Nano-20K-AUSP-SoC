library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Generic full-duplex SPI master, Wishbone slave.
-- Mode 0 (CPOL=0, CPHA=0): MOSI changes on SCK falling edge, MISO sampled on
-- SCK rising edge. MSB first. CS is software controlled (held across multiple
-- byte transfers, as the W25Q flash protocol requires).
--
-- Register map (byte address on adr_i):
--   0x00 R : RXDATA  - last received frame in bits (FRAME_BITS-1 downto 0)
--   0x04 W : TXDATA  - write a frame to (FRAME_BITS-1 downto 0) -> starts a transfer
--                      (clears the done flag)
--   0x08 W : CTRL    - bit0: CS control (1 = assert CS low/active, 0 = release CS high)
--   0x0C R : STATUS  - bit0 = busy, bit1 = done. NON-destructive read: done stays
--                      set until the next TXDATA write. (Le letture OPEN WB della
--                      CPU possono tornare sporche: un done azzerato alla lettura
--                      andava perso per sempre e il polling restava appeso.)
--
-- Generics:
--   PRESCALER  - SCK = clk_i / PRESCALER (must be even, >= 2)
--   FRAME_BITS - bits per transfer (8 for the W25Q byte protocol)

entity spi_master_generic is
    generic (
        PRESCALER  : natural := 16;
        FRAME_BITS : natural := 8
    );
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;                       -- active low
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

    signal shift_tx : std_logic_vector(FRAME_BITS - 1 downto 0) := (others => '0');
    signal shift_rx : std_logic_vector(FRAME_BITS - 1 downto 0) := (others => '0');
    signal sck_s    : std_logic := '0';
    signal cs_r     : std_logic := '1';
    signal bit_cnt  : natural range 0 to FRAME_BITS - 1 := 0;
    signal pre_cnt  : natural range 0 to PRESCALER - 1 := 0;
    signal active   : std_logic := '0';
    signal start    : std_logic := '0';
    signal done_s   : std_logic := '0';

begin

    SCK  <= sck_s;
    CS   <= cs_r;
    MOSI <= shift_tx(FRAME_BITS - 1);

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                ack_o    <= '0';
                sck_s    <= '0';
                cs_r     <= '1';
                bit_cnt  <= 0;
                pre_cnt  <= 0;
                shift_tx <= (others => '0');
                shift_rx <= (others => '0');
                active   <= '0';
                start    <= '0';
                done_s   <= '0';
                dat_o    <= (others => '0');
            else
                ack_o <= '0';
                start <= '0';

                if cyc_i = '1' and stb_i = '1' then
                    ack_o <= '1';
                    if we_i = '1' then
                        case adr_i is
                            when x"04" =>
                                if active = '0' then
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
                                dat_o    <= (others => '0');
                                dat_o(0) <= active;
                                dat_o(1) <= done_s;
                            when others =>
                                dat_o <= (others => '0');
                        end case;
                    end if;
                end if;

                if start = '1' and active = '0' then
                    active  <= '1';
                    bit_cnt <= 0;
                    pre_cnt <= 0;
                    sck_s   <= '0';
                    done_s  <= '0';
                elsif active = '1' then
                    if pre_cnt = HALF_PRE - 1 then
                        sck_s    <= '1';
                        shift_rx <= shift_rx(FRAME_BITS - 2 downto 0) & MISO;
                        pre_cnt  <= pre_cnt + 1;
                    elsif pre_cnt = PRESCALER - 1 then
                        sck_s   <= '0';
                        pre_cnt <= 0;
                        if bit_cnt = FRAME_BITS - 1 then
                            active <= '0';
                            done_s <= '1';
                        else
                            shift_tx <= shift_tx(FRAME_BITS - 2 downto 0) & '0';
                            bit_cnt  <= bit_cnt + 1;
                        end if;
                    else
                        pre_cnt <= pre_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end rtl;
