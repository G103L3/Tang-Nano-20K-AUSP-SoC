library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- SPI master TX-only per display ST7789 (GMT020-02-7P), slave Wishbone.
-- Mode 3 (CPOL=1, CPHA=1): SCK a riposo ALTO, dato pilotato sul fronte di
-- discesa e campionato dal pannello sul fronte di salita. MSB first.
-- Funziona sia con CS pilotato sia con CS legato a GND.
--
-- Registri (adr_i):
--   0x00 W : TXDATA  - scrive un byte e avvia il trasferimento (ignorato se busy)
--   0x04 W : CTRL    - bit0 = DC (0=comando, 1=dato)
--                      bit1 = RST pin (0=reset attivo, 1=run); default 0
--                      bit2 = CS (1=assert -> pin basso, 0=release); default 0
--   0x08 R : STATUS  - bit0 = busy. Lettura NON distruttiva.
-- ack tenuto alto finche' cyc&stb (l'OPEN WB perde gli impulsi singoli).
entity spi_display is
    generic (
        PRESCALER : natural := 6
    );
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;                       -- attivo basso
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

    signal shift_tx : std_logic_vector(7 downto 0) := (others => '0');
    signal sck_s    : std_logic := '1';
    signal dc_r     : std_logic := '0';
    signal rst_r    : std_logic := '0';
    signal cs_r     : std_logic := '1';
    signal bit_cnt  : natural range 0 to 7 := 0;
    signal pre_cnt  : natural range 0 to PRESCALER - 1 := 0;
    signal active   : std_logic := '0';
    signal start    : std_logic := '0';

begin

    SCK_o <= sck_s;
    SDA_o <= shift_tx(7);
    DC_o  <= dc_r;
    RST_o <= rst_r;
    CS_o  <= cs_r;

    dat_o <= (0 => active, others => '0') when adr_i = x"08" else (others => '0');

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                ack_o    <= '0';
                sck_s    <= '1';
                dc_r     <= '0';
                rst_r    <= '0';
                cs_r     <= '1';
                bit_cnt  <= 0;
                pre_cnt  <= 0;
                shift_tx <= (others => '0');
                active   <= '0';
                start    <= '0';
            else
                ack_o <= '0';
                start <= '0';

                if cyc_i = '1' and stb_i = '1' then
                    ack_o <= '1';
                    if we_i = '1' then
                        case adr_i is
                            when x"00" =>
                                if active = '0' then
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

                if start = '1' and active = '0' then
                    active  <= '1';
                    bit_cnt <= 0;
                    pre_cnt <= 0;
                    sck_s   <= '0';                  -- primo fronte di discesa, MSB gia' su SDA
                elsif active = '1' then
                    if pre_cnt = HALF_PRE - 1 then
                        sck_s   <= '1';              -- salita: il pannello campiona
                        pre_cnt <= pre_cnt + 1;
                    elsif pre_cnt = PRESCALER - 1 then
                        pre_cnt <= 0;
                        if bit_cnt = 7 then
                            active <= '0';           -- SCK resta alto = idle mode 3
                        else
                            shift_tx <= shift_tx(6 downto 0) & '0';
                            bit_cnt  <= bit_cnt + 1;
                            sck_s    <= '0';         -- discesa + nuovo bit
                        end if;
                    else
                        pre_cnt <= pre_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end rtl;
