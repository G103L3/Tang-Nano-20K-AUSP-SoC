library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TestBench is
end TestBench;

architecture tbarch of TestBench is
component PWM_GENERIC is
    Generic(
        NBIT : integer := 10
    );
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

        PWM_o   : OUT STD_LOGIC
    );
end component;

    signal clk_i : std_logic := '0';
    signal rst_i : std_logic := '0';
    signal cyc_i : std_logic := '0';
    signal stb_i : std_logic := '0';
    signal we_i  : std_logic := '0';
    signal adr_i : std_logic_vector(7 downto 0) := x"00";
    signal dat_i : std_logic_vector(31 downto 0) := x"00000000";
    signal dat_o : std_logic_vector(31 downto 0);
    signal ack_o : std_logic;
    signal pwm_o : std_logic;

begin

    uut: PWM_GENERIC
    generic map (10) 
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
        pwm_o => pwm_o
    );

    clk_i <= not clk_i after 5 ns;

    process
    begin
        rst_i <= '0';
        wait for 15 ns;
        rst_i <= '1';
        wait for 25 ns;

        wait until rising_edge(clk_i);
        cyc_i <= '1';
        stb_i <= '1';
        we_i  <= '1';
        adr_i <= x"00";
        dat_i <= x"00000005";
        wait until rising_edge(clk_i);
        cyc_i <= '0';
        stb_i <= '0';
        we_i  <= '0';

        wait for 1 us;

        wait until rising_edge(clk_i);
        cyc_i <= '1';
        stb_i <= '1';
        we_i  <= '1';
        adr_i <= x"00";
        dat_i <= x"80000000";
        wait until rising_edge(clk_i);
        cyc_i <= '0';
        stb_i <= '0';
        we_i  <= '0';

        wait for 200 ns;

        wait until rising_edge(clk_i);
        cyc_i <= '1';
        stb_i <= '1';
        we_i  <= '1';
        adr_i <= x"00";
        dat_i <= x"00000002";
        wait until rising_edge(clk_i);
        cyc_i <= '0';
        stb_i <= '0';
        we_i  <= '0';

        wait for 500 ns;

        wait until rising_edge(clk_i);
        assert false report "=== SIMULAZIONE COMPLETATA CON SUCCESSO ===" severity failure;
        wait;
    end process;

end tbarch;