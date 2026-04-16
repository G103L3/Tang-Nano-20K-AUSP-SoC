library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wb_interconnect is
    port (
        --CPU
        m0_adr_i : in std_logic_vector(31 downto 0);
        m0_dat_i : in std_logic_vector(31 downto 0);
        m0_dat_o : out std_logic_vector(31 downto 0);
        m0_we_i  : in std_logic;
        m0_sel_i : in std_logic_vector(3 downto 0);
        m0_stb_i : in std_logic;
        m0_cyc_i : in std_logic;
        m0_ack_o : out std_logic;
        
        --DMA
        m1_adr_i : in std_logic_vector(31 downto 0);
        m1_dat_i : in std_logic_vector(31 downto 0);
        m1_dat_o : out std_logic_vector(31 downto 0);
        m1_we_i  : in std_logic;
        m1_sel_i : in std_logic_vector(3 downto 0);
        m1_stb_i : in std_logic;
        m1_cyc_i : in std_logic;
        m1_ack_o : out std_logic;

        s0_adr_o : out std_logic_vector(31 downto 0);
        s0_dat_o : out std_logic_vector(31 downto 0);
        s0_dat_i : in std_logic_vector(31 downto 0);
        s0_we_o  : out std_logic;
        s0_sel_o : out std_logic_vector(3 downto 0);
        s0_stb_o : out std_logic;
        s0_cyc_o : out std_logic;
        s0_ack_i : in std_logic;
        
        --SPI
        s1_adr_o : out std_logic_vector(31 downto 0);
        s1_dat_o : out std_logic_vector(31 downto 0);
        s1_dat_i : in std_logic_vector(31 downto 0);
        s1_we_o  : out std_logic;
        s1_sel_o : out std_logic_vector(3 downto 0);
        s1_stb_o : out std_logic;
        s1_cyc_o : out std_logic;
        s1_ack_i : in std_logic
    );
end wb_interconnect;

architecture behavioral of wb_interconnect is
    signal active_master : integer range 0 to 1 := 0;
    signal current_adr   : std_logic_vector(31 downto 0);
    signal current_dat_m : std_logic_vector(31 downto 0);
    signal current_we    : std_logic;
    signal current_sel   : std_logic_vector(3 downto 0);
    signal current_stb   : std_logic;
    signal current_cyc   : std_logic;
begin

    --Processo per capire da quale Master prendere gli ingressi
    process(m0_cyc_i, m1_cyc_i, m0_adr_i, m1_adr_i, m0_dat_i, m1_dat_i, m0_stb_i, m1_stb_i, m0_we_i, m1_we_i, m0_sel_i, m1_sel_i)
    begin
        if m1_cyc_i = '1' then
            active_master <= 1;
            current_adr   <= m1_adr_i;
            current_dat_m <= m1_dat_i;
            current_we    <= m1_we_i;
            current_sel   <= m1_sel_i;
            current_stb   <= m1_stb_i;
            current_cyc   <= m1_cyc_i;
        else
            active_master <= 0;
            current_adr   <= m0_adr_i;
            current_dat_m <= m0_dat_i;
            current_we    <= m0_we_i;
            current_sel   <= m0_sel_i;
            current_stb   <= m0_stb_i;
            current_cyc   <= m0_cyc_i;
        end if;
    end process;

    --Processo per individuare lo slave a cui mandarli
    process(current_adr, current_dat_m, current_we, current_sel, current_stb, current_cyc, s0_ack_i, s1_ack_i, s0_dat_i, s1_dat_i, active_master)
    begin
        s0_adr_o <= current_adr;
        s0_dat_o <= current_dat_m;
        s0_we_o  <= current_we;
        s0_sel_o <= current_sel;
        s0_stb_o <= '0';
        s0_cyc_o <= '0';

        s1_adr_o <= current_adr;
        s1_dat_o <= current_dat_m;
        s1_we_o  <= current_we;
        s1_sel_o <= current_sel;
        s1_stb_o <= '0';
        s1_cyc_o <= '0';

        m0_ack_o <= '0';
        m1_ack_o <= '0';
        m0_dat_o <= (others => '0');
        m1_dat_o <= (others => '0');

        if current_adr(31 downto 28) = "0000" then
            s0_stb_o <= current_stb;
            s0_cyc_o <= current_cyc;
            if active_master = 0 then
                m0_ack_o <= s0_ack_i;
                m0_dat_o <= s0_dat_i;
            else
                m1_ack_o <= s0_ack_i;
                m1_dat_o <= s0_dat_i;
            end if;
            --SPI indirizzo 0x40000000
        elsif current_adr(31 downto 28) = "0100" then
            s1_stb_o <= current_stb;
            s1_cyc_o <= current_cyc;
            if active_master = 0 then
                m0_ack_o <= s1_ack_i;
                m0_dat_o <= s1_dat_i;
            else
                m1_ack_o <= s1_ack_i;
                m1_dat_o <= s1_dat_i;
            end if;
        end if;
    end process;

end behavioral;