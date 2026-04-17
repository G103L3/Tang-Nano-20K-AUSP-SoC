library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GPIO_GENERIC is
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
end GPIO_GENERIC;

architecture GPIO_GENERIC_BEHAVIORAL of GPIO_GENERIC is
signal reg_out : std_logic_vector(NBIT-1 downto 0) := (others => '0');
signal stb_old : std_logic;

begin

    seq_process_cki: process(clk_i) 
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                ack_o <= '0';
                stb_old <= '0';
                reg_out <= (others => '0');
                dat_o <= (others => '0');
            else
                ack_o <= '0';
                stb_old <= stb_i;
                if cyc_i = '1' AND stb_i = '1' AND stb_old = '0' then 
                    if we_i = '1' then
                        reg_out <= dat_i(NBIT-1 downto 0);
                    else
                        dat_o <= (others => '0');
                        dat_o(NBIT-1 downto 0) <= gpio_i;
                    end if;
                    ack_o <= '1';
                end if;
            end if;
        end if;
    end process seq_process_cki; 

    gpio_o <= reg_out;

end GPIO_GENERIC_BEHAVIORAL;