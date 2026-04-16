library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wb_interconnect is
    port (
        m0_adr_i : in std_logic_vector(31 downto 0);
        m0_dat_i : in std_logic_vector(31 downto 0);
        m0_dat_o : out std_logic_vector(31 downto 0);
        m0_we_i  : in std_logic;
        m0_sel_i : in std_logic_vector(3 downto 0);
        m0_stb_i : in std_logic;
        m0_cyc_i : in std_logic;
        m0_ack_o : out std_logic;
        
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
        
        s1_adr_o : out std_logic_vector(31 downto 0);
        s1_dat_o : out std_logic_vector(31 downto 0);
        s1_dat_i : in std_logic_vector(31 downto 0);
        s1_we_o  : out std_logic;
        s1_sel_o : out std_logic_vector(3 downto 0);
        s1_stb_o : out std_logic;
        s1_cyc_o : out std_logic;
        s1_ack_i : in std_logic;

        s2_adr_o : out std_logic_vector(31 downto 0);
        s2_dat_o : out std_logic_vector(31 downto 0);
        s2_dat_i : in std_logic_vector(31 downto 0);
        s2_we_o  : out std_logic;
        s2_sel_o : out std_logic_vector(3 downto 0);
        s2_stb_o : out std_logic;
        s2_cyc_o : out std_logic;
        s2_ack_i : in std_logic;

        s3_adr_o : out std_logic_vector(31 downto 0);
        s3_dat_o : out std_logic_vector(31 downto 0);
        s3_dat_i : in std_logic_vector(31 downto 0);
        s3_we_o  : out std_logic;
        s3_sel_o : out std_logic_vector(3 downto 0);
        s3_stb_o : out std_logic;
        s3_cyc_o : out std_logic;
        s3_ack_i : in std_logic;

        s4_adr_o : out std_logic_vector(31 downto 0);
        s4_dat_o : out std_logic_vector(31 downto 0);
        s4_dat_i : in std_logic_vector(31 downto 0);
        s4_we_o  : out std_logic;
        s4_sel_o : out std_logic_vector(3 downto 0);
        s4_stb_o : out std_logic;
        s4_cyc_o : out std_logic;
        s4_ack_i : in std_logic;

        s5_adr_o : out std_logic_vector(31 downto 0);
        s5_dat_o : out std_logic_vector(31 downto 0);
        s5_dat_i : in std_logic_vector(31 downto 0);
        s5_we_o  : out std_logic;
        s5_sel_o : out std_logic_vector(3 downto 0);
        s5_stb_o : out std_logic;
        s5_cyc_o : out std_logic;
        s5_ack_i : in std_logic;

        s6_adr_o : out std_logic_vector(31 downto 0);
        s6_dat_o : out std_logic_vector(31 downto 0);
        s6_dat_i : in std_logic_vector(31 downto 0);
        s6_we_o  : out std_logic;
        s6_sel_o : out std_logic_vector(3 downto 0);
        s6_stb_o : out std_logic;
        s6_cyc_o : out std_logic;
        s6_ack_i : in std_logic;

        s7_adr_o : out std_logic_vector(31 downto 0);
        s7_dat_o : out std_logic_vector(31 downto 0);
        s7_dat_i : in std_logic_vector(31 downto 0);
        s7_we_o  : out std_logic;
        s7_sel_o : out std_logic_vector(3 downto 0);
        s7_stb_o : out std_logic;
        s7_cyc_o : out std_logic;
        s7_ack_i : in std_logic
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

    process(current_adr, current_dat_m, current_we, current_sel, current_stb, current_cyc, 
            s0_ack_i, s1_ack_i, s2_ack_i, s3_ack_i, s4_ack_i, s5_ack_i, s6_ack_i, s7_ack_i,
            s0_dat_i, s1_dat_i, s2_dat_i, s3_dat_i, s4_dat_i, s5_dat_i, s6_dat_i, s7_dat_i, active_master)
    begin
        s0_adr_o <= current_adr; s0_dat_o <= current_dat_m; s0_we_o <= current_we; s0_sel_o <= current_sel;
        s1_adr_o <= current_adr; s1_dat_o <= current_dat_m; s1_we_o <= current_we; s1_sel_o <= current_sel;
        s2_adr_o <= current_adr; s2_dat_o <= current_dat_m; s2_we_o <= current_we; s2_sel_o <= current_sel;
        s3_adr_o <= current_adr; s3_dat_o <= current_dat_m; s3_we_o <= current_we; s3_sel_o <= current_sel;
        s4_adr_o <= current_adr; s4_dat_o <= current_dat_m; s4_we_o <= current_we; s4_sel_o <= current_sel;
        s5_adr_o <= current_adr; s5_dat_o <= current_dat_m; s5_we_o <= current_we; s5_sel_o <= current_sel;
        s6_adr_o <= current_adr; s6_dat_o <= current_dat_m; s6_we_o <= current_we; s6_sel_o <= current_sel;
        s7_adr_o <= current_adr; s7_dat_o <= current_dat_m; s7_we_o <= current_we; s7_sel_o <= current_sel;

        s0_stb_o <= '0'; s0_cyc_o <= '0';
        s1_stb_o <= '0'; s1_cyc_o <= '0';
        s2_stb_o <= '0'; s2_cyc_o <= '0';
        s3_stb_o <= '0'; s3_cyc_o <= '0';
        s4_stb_o <= '0'; s4_cyc_o <= '0';
        s5_stb_o <= '0'; s5_cyc_o <= '0';
        s6_stb_o <= '0'; s6_cyc_o <= '0';
        s7_stb_o <= '0'; s7_cyc_o <= '0';

        m0_ack_o <= '0'; m1_ack_o <= '0';
        m0_dat_o <= (others => '0'); m1_dat_o <= (others => '0');

        if current_adr(31 downto 28) = x"0" then
            s0_stb_o <= current_stb; s0_cyc_o <= current_cyc;
            if active_master = 0 then m0_ack_o <= s0_ack_i; m0_dat_o <= s0_dat_i; else m1_ack_o <= s0_ack_i; m1_dat_o <= s0_dat_i; end if;
        elsif current_adr(31 downto 28) = x"4" then
            s1_stb_o <= current_stb; s1_cyc_o <= current_cyc;
            if active_master = 0 then m0_ack_o <= s1_ack_i; m0_dat_o <= s1_dat_i; else m1_ack_o <= s1_ack_i; m1_dat_o <= s1_dat_i; end if;
        elsif current_adr(31 downto 28) = x"5" then
            s2_stb_o <= current_stb; s2_cyc_o <= current_cyc;
            if active_master = 0 then m0_ack_o <= s2_ack_i; m0_dat_o <= s2_dat_i; else m1_ack_o <= s2_ack_i; m1_dat_o <= s2_dat_i; end if;
        elsif current_adr(31 downto 28) = x"6" then
            s3_stb_o <= current_stb; s3_cyc_o <= current_cyc;
            if active_master = 0 then m0_ack_o <= s3_ack_i; m0_dat_o <= s3_dat_i; else m1_ack_o <= s3_ack_i; m1_dat_o <= s3_dat_i; end if;
        elsif current_adr(31 downto 28) = x"7" then
            s4_stb_o <= current_stb; s4_cyc_o <= current_cyc;
            if active_master = 0 then m0_ack_o <= s4_ack_i; m0_dat_o <= s4_dat_i; else m1_ack_o <= s4_ack_i; m1_dat_o <= s4_dat_i; end if;
        elsif current_adr(31 downto 28) = x"8" then
            s5_stb_o <= current_stb; s5_cyc_o <= current_cyc;
            if active_master = 0 then m0_ack_o <= s5_ack_i; m0_dat_o <= s5_dat_i; else m1_ack_o <= s5_ack_i; m1_dat_o <= s5_dat_i; end if;
        elsif current_adr(31 downto 28) = x"9" then
            s6_stb_o <= current_stb; s6_cyc_o <= current_cyc;
            if active_master = 0 then m0_ack_o <= s6_ack_i; m0_dat_o <= s6_dat_i; else m1_ack_o <= s6_ack_i; m1_dat_o <= s6_dat_i; end if;
        elsif current_adr(31 downto 28) = x"A" then
            s7_stb_o <= current_stb; s7_cyc_o <= current_cyc;
            if active_master = 0 then m0_ack_o <= s7_ack_i; m0_dat_o <= s7_dat_i; else m1_ack_o <= s7_ack_i; m1_dat_o <= s7_dat_i; end if;
        end if;
    end process;

end behavioral;