library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TestBench is
end TestBench;

architecture TBarch of TestBench is

    component SPI_Master is
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
        MOSI    : out STD_LOGIC;
        MISO    : in  STD_LOGIC;
        SCK     : out STD_LOGIC;
        CS      : out STD_LOGIC
    );
    end component;

    signal clk_i : std_logic := '0';
    signal rst_i : std_logic := '0';
    signal cyc_i : std_logic := '0';
    signal stb_i : std_logic := '0';
    signal we_i  : std_logic := '0';
    signal adr_i : std_logic_vector(7 downto 0)  := x"00";
    signal dat_i : std_logic_vector(31 downto 0) := x"00000000";
    signal dat_o : std_logic_vector(31 downto 0);
    signal ack_o : std_logic;
    signal MOSI  : std_logic;
    signal MISO  : std_logic := '0';
    signal SCK   : std_logic;
    signal CS    : std_logic;

begin

    UUT: SPI_Master
    port map (
        clk_i => clk_i,
        rst_i => rst_i,
        cyc_i => cyc_i,
        stb_i => stb_i,
        we_i  => we_i,
        adr_i => adr_i,
        dat_i => dat_i,
        dat_o => dat_o,
        ack_o => ack_o,
        MOSI  => MOSI,
        MISO  => MISO,
        SCK   => SCK,
        CS    => CS
    );

    clk_i <= not clk_i after 5 ns;

    process(SCK)
    begin
        if falling_edge(SCK) then
            MISO <= not MISO;
        end if;
    end process;

    process
    begin
        rst_i <= '0';
        wait for 20 ns;
        rst_i <= '1';
        wait for 20 ns;

        wait until rising_edge(clk_i);
        cyc_i <= '1'; stb_i <= '1'; we_i <= '1'; adr_i <= x"01";
        wait until rising_edge(clk_i);
        cyc_i <= '0'; stb_i <= '0'; we_i <= '0';

        -- 32 bit * 32 clk/bit * 10 ns = 10.24 us
        wait for 12 us;

        poll_loop: loop
            wait until rising_edge(clk_i);
            cyc_i <= '1'; stb_i <= '1'; we_i <= '0'; adr_i <= x"00";
            wait until rising_edge(clk_i);
            adr_i <= x"03";
            wait on ack_o for 15 ns;
            if ack_o = '1' then
                wait until rising_edge(clk_i);
                cyc_i <= '0'; stb_i <= '0';
                exit poll_loop;
            end if;

            wait until rising_edge(clk_i);
            cyc_i <= '0'; stb_i <= '0';
        end loop;
        wait for 24 us;
            wait until rising_edge(clk_i);
            cyc_i <= '1'; stb_i <= '1'; we_i <= '0'; adr_i <= x"00";
            wait until rising_edge(clk_i);
            adr_i <= x"03";
        wait until rising_edge(clk_i);
        cyc_i <= '1'; stb_i <= '1'; we_i <= '1'; adr_i <= x"02";
        wait until rising_edge(clk_i);
        cyc_i <= '0'; stb_i <= '0'; we_i <= '0';

        wait for 50 ns;

        assert false report "=== SIMULAZIONE COMPLETATA ===" severity failure;
        wait;
    end process;

end TBarch;
