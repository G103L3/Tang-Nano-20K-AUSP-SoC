library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity testbench is
end testbench;

architecture tbarch of testbench is
    component GPIO_GENERIC is
        Generic (
            NBIT : integer := 8
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

            gpio_i  : in  STD_LOGIC_VECTOR(NBIT-1 downto 0);
            gpio_o  : out STD_LOGIC_VECTOR(NBIT-1 downto 0)
        );
    end component;

    signal clk_i   : STD_LOGIC := '0';
    signal rst_i   : STD_LOGIC := '0';
    signal cyc_i   : STD_LOGIC := '0';
    signal stb_i   : STD_LOGIC := '0';
    signal we_i    : STD_LOGIC := '0';
    signal adr_i   : STD_LOGIC_VECTOR(7 downto 0) := x"00";
    signal dat_i   : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal dat_o   : STD_LOGIC_VECTOR(31 downto 0);
    signal ack_o   : STD_LOGIC;
    
    constant N     : integer := 8;
    signal gpio_in : STD_LOGIC_VECTOR(N-1 downto 0) := (others => '0');
    signal gpio_out: STD_LOGIC_VECTOR(N-1 downto 0);

begin

    uut: GPIO_GENERIC
    generic map ( NBIT => N )
    port map (
        clk_i  => clk_i,
        rst_i  => rst_i,
        cyc_i  => cyc_i,
        stb_i  => stb_i,
        we_i   => we_i,
        adr_i  => adr_i,
        dat_i  => dat_i,
        dat_o  => dat_o,
        ack_o  => ack_o,
        gpio_i => gpio_in,
        gpio_o => gpio_out
    );

    clk_i <= NOT clk_i after 5 ns;

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
        dat_i <= x"000000FF";
        wait until rising_edge(clk_i);
        cyc_i <= '0';
        stb_i <= '0';
        we_i  <= '0';

        wait for 50 ns;

        gpio_in <= x"55";
        wait for 20 ns;
        
        wait until rising_edge(clk_i);
        cyc_i <= '1';
        stb_i <= '1';
        we_i  <= '0';
        wait until rising_edge(clk_i);
        cyc_i <= '0';
        stb_i <= '0';

        wait for 100 ns;

        assert false report "=== SIMULAZIONE GPIO COMPLETATA CON SUCCESSO ===" severity failure;
        wait;
    end process;

end tbarch;