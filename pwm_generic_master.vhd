library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PWM_GENERIC is
    Generic (
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
end PWM_GENERIC;

architecture PWM_GENERIC_BEHAVIORAL of PWM_GENERIC is
signal resolution, counter : unsigned(NBIT-1 downto 0) := (others => '0');

signal start : std_logic;
signal stb_old : std_logic;

begin
    dat_o <= (others => '0');

    seq_process_cki: process(clk_i) 
    begin
        if rising_edge(clk_i) then
            if rst_i = '0' then
                ack_o <= '0';
                counter <= (others => '0');
                start <= '0';
                PWM_o <= '0';
                stb_old <= '0';
            else
                ack_o <= '0';
                stb_old <= stb_i;
                if cyc_i = '1' AND stb_i = '1' AND stb_old = '0' then 
                    if we_i = '1' then
                        if dat_i(31) = '1' then -- The dat_i = 10000000000000000000000000000000 means stop sending (silent)
                            start <= '0';
                            ack_o <= '0';
                            PWM_o <= '0';
                        else
                            if start = '0' then
                                resolution <= unsigned(dat_i(NBIT-1 downto 0));
                                counter <= (others => '0');
                                start <= '1';
                            end if;
                        end if;
                    end if;
                    if we_i = '0' then
                    end if;
                    ack_o <= '1';
                end if;
                if start = '1' then
                    if counter = resolution-1 then
                        counter <= (others => '0');
                        PWM_o <= '1';
                    else
                        counter <= counter + 1;
                        PWM_o <= '0';

                    end if;
                end if;

            end if;
        end if;
    end process seq_process_cki; 

end PWM_GENERIC_BEHAVIORAL;