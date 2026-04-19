library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Dual-port Wishbone→SDRAM bridge with fixed-priority arbiter.
-- M1 (DMA) always preempts M0 (CPU) when both are requesting.
-- All SDRAM physical signals are kept internal so P&R routes them
-- to the GW2AR-18C embedded SDRAM die without creating package I/Os.
entity memory_arbiter is
    port (
        wb_clk_i  : in  std_logic;
        wb_rst_i  : in  std_logic;
        -- Wishbone Master 0 – CPU (low priority)
        m0_cyc_i  : in  std_logic;
        m0_stb_i  : in  std_logic;
        m0_we_i   : in  std_logic;
        m0_adr_i  : in  std_logic_vector(31 downto 0);
        m0_dat_i  : in  std_logic_vector(31 downto 0);
        m0_dat_o  : out std_logic_vector(31 downto 0);
        m0_ack_o  : out std_logic;
        -- Wishbone Master 1 – DMA (high priority)
        m1_cyc_i  : in  std_logic;
        m1_stb_i  : in  std_logic;
        m1_we_i   : in  std_logic;
        m1_adr_i  : in  std_logic_vector(31 downto 0);
        m1_dat_i  : in  std_logic_vector(31 downto 0);
        m1_dat_o  : out std_logic_vector(31 downto 0);
        m1_ack_o  : out std_logic
    );
end memory_arbiter;

architecture structural of memory_arbiter is

    component sdram_controller_hs_top
        port (
            o_sdram_clk           : out   std_logic;
            o_sdram_cke           : out   std_logic;
            o_sdram_cs_n          : out   std_logic;
            o_sdram_cas_n         : out   std_logic;
            o_sdram_ras_n         : out   std_logic;
            o_sdram_wen_n         : out   std_logic;
            o_sdram_dqm           : out   std_logic_vector(3 downto 0);
            o_sdram_addr          : out   std_logic_vector(10 downto 0);
            o_sdram_ba            : out   std_logic_vector(1 downto 0);
            io_sdram_dq           : inout std_logic_vector(31 downto 0);
            i_sdrc_rst_n          : in    std_logic;
            i_sdrc_clk            : in    std_logic;
            i_sdram_clk           : in    std_logic;
            i_sdrc_cmd_en         : in    std_logic;
            i_sdrc_cmd            : in    std_logic_vector(2 downto 0);
            i_sdrc_precharge_ctrl : in    std_logic;
            i_sdram_power_down    : in    std_logic;
            i_sdram_selfrefresh   : in    std_logic;
            i_sdrc_addr           : in    std_logic_vector(20 downto 0);
            i_sdrc_dqm            : in    std_logic_vector(3 downto 0);
            i_sdrc_data           : in    std_logic_vector(31 downto 0);
            i_sdrc_data_len       : in    std_logic_vector(7 downto 0);
            o_sdrc_data           : out   std_logic_vector(31 downto 0);
            o_sdrc_init_done      : out   std_logic;
            o_sdrc_cmd_ack        : out   std_logic
        );
    end component;

    -- SDRAM physical interface – all internal, no package pins
    signal sdram_clk_s   : std_logic;
    signal sdram_cke_s   : std_logic;
    signal sdram_cs_n_s  : std_logic;
    signal sdram_cas_n_s : std_logic;
    signal sdram_ras_n_s : std_logic;
    signal sdram_wen_n_s : std_logic;
    signal sdram_dqm_s   : std_logic_vector(3 downto 0);
    signal sdram_addr_s  : std_logic_vector(10 downto 0);
    signal sdram_ba_s    : std_logic_vector(1 downto 0);
    signal sdram_dq_s    : std_logic_vector(31 downto 0);

    -- SDRAM controller user bus
    signal sdrc_cmd      : std_logic_vector(2 downto 0);
    signal sdrc_cmd_en   : std_logic;
    signal sdrc_cmd_ack  : std_logic;
    signal sdrc_data_out : std_logic_vector(31 downto 0);
    signal sdrc_init_done: std_logic;

    -- Arbiter state
    type arb_t is (IDLE, SERVING_M0, SERVING_M1);
    signal arb_state : arb_t;
    signal state_ack : std_logic;

    -- Muxed signals to SDRAM controller
    signal sel_cyc : std_logic;
    signal sel_stb : std_logic;
    signal sel_we  : std_logic;
    signal sel_adr : std_logic_vector(31 downto 0);
    signal sel_dat : std_logic_vector(31 downto 0);

begin

    -- Fixed-priority arbiter: M1 (DMA) > M0 (CPU).
    -- A transaction runs to completion before the grant changes.
    process(wb_clk_i)
    begin
        if rising_edge(wb_clk_i) then
            if wb_rst_i = '0' then
                arb_state <= IDLE;
                state_ack <= '0';
                m0_ack_o  <= '0';
                m1_ack_o  <= '0';
            else
                m0_ack_o <= '0';
                m1_ack_o <= '0';

                case arb_state is

                    when IDLE =>
                        state_ack <= '0';
                        if sdrc_init_done = '1' then
                            if m1_cyc_i = '1' and m1_stb_i = '1' then
                                arb_state <= SERVING_M1;
                            elsif m0_cyc_i = '1' and m0_stb_i = '1' then
                                arb_state <= SERVING_M0;
                            end if;
                        end if;

                    when SERVING_M0 =>
                        if sdrc_cmd_ack = '1' then
                            state_ack <= '1';
                            m0_ack_o  <= '1';
                        end if;
                        if m0_cyc_i = '0' or m0_stb_i = '0' then
                            arb_state <= IDLE;
                            state_ack <= '0';
                        end if;

                    when SERVING_M1 =>
                        if sdrc_cmd_ack = '1' then
                            state_ack <= '1';
                            m1_ack_o  <= '1';
                        end if;
                        if m1_cyc_i = '0' or m1_stb_i = '0' then
                            arb_state <= IDLE;
                            state_ack <= '0';
                        end if;

                end case;
            end if;
        end if;
    end process;

    -- Steer signals from the currently granted master
    sel_cyc <= m1_cyc_i when arb_state = SERVING_M1 else
               m0_cyc_i when arb_state = SERVING_M0 else '0';
    sel_stb <= m1_stb_i when arb_state = SERVING_M1 else
               m0_stb_i when arb_state = SERVING_M0 else '0';
    sel_we  <= m1_we_i  when arb_state = SERVING_M1 else m0_we_i;
    sel_adr <= m1_adr_i when arb_state = SERVING_M1 else m0_adr_i;
    sel_dat <= m1_dat_i when arb_state = SERVING_M1 else m0_dat_i;

    -- Read data available to both masters; only the acked one reads it
    m0_dat_o <= sdrc_data_out;
    m1_dat_o <= sdrc_data_out;

    sdrc_cmd    <= "001" when sel_we = '1' else "010";
    sdrc_cmd_en <= sel_cyc and sel_stb and sdrc_init_done and not state_ack;

    u_sdram: sdram_controller_hs_top
    port map (
        o_sdram_clk           => sdram_clk_s,
        o_sdram_cke           => sdram_cke_s,
        o_sdram_cs_n          => sdram_cs_n_s,
        o_sdram_cas_n         => sdram_cas_n_s,
        o_sdram_ras_n         => sdram_ras_n_s,
        o_sdram_wen_n         => sdram_wen_n_s,
        o_sdram_dqm           => sdram_dqm_s,
        o_sdram_addr          => sdram_addr_s,
        o_sdram_ba            => sdram_ba_s,
        io_sdram_dq           => sdram_dq_s,
        i_sdrc_rst_n          => wb_rst_i,
        i_sdrc_clk            => wb_clk_i,
        i_sdram_clk           => wb_clk_i,
        i_sdrc_cmd_en         => sdrc_cmd_en,
        i_sdrc_cmd            => sdrc_cmd,
        i_sdrc_precharge_ctrl => '0',
        i_sdram_power_down    => '0',
        i_sdram_selfrefresh   => '0',
        i_sdrc_addr           => sel_adr(20 downto 0),
        i_sdrc_dqm            => "0000",
        i_sdrc_data           => sel_dat,
        i_sdrc_data_len       => x"01",
        o_sdrc_data           => sdrc_data_out,
        o_sdrc_init_done      => sdrc_init_done,
        o_sdrc_cmd_ack        => sdrc_cmd_ack
    );

end structural;
