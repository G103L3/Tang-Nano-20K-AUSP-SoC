library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdram_controller_fsm is
    generic (
        -- timing in cycles of I_sdrc_clk (40.5 MHz, tCK = 24.69 ns)
        INIT_WAIT_CYCLES : natural := 8192;
        TRCD_CYCLES      : natural := 3;
        CL_CYCLES        : natural := 3;
        TRP_CYCLES       : natural := 2;
        TRFC_CYCLES      : natural := 4;
        TMRD_CYCLES      : natural := 2;
        TWR_CYCLES       : natural := 2;
        REFRESH_INTERVAL : natural := 312;
        -- read capture trim, keep at 0: a negative value samples dq before
        -- the die drives it and the burst starts with bus garbage
        RD_CAP_ADJ       : integer := 0;
        -- write pipe depth trim: 1 on the board adds one stage so word zero
        -- lines up with the write command, 0 in the ideal simulation model
        WR_ALIGN         : natural := 1
    );
    port (
        O_sdram_clk        : out   std_logic;
        O_sdram_cke        : out   std_logic;
        O_sdram_cs_n       : out   std_logic;
        O_sdram_cas_n      : out   std_logic;
        O_sdram_ras_n      : out   std_logic;
        O_sdram_wen_n      : out   std_logic;
        O_sdram_dqm        : out   std_logic_vector(3 downto 0);
        O_sdram_addr       : out   std_logic_vector(10 downto 0);
        O_sdram_ba         : out   std_logic_vector(1 downto 0);
        IO_sdram_dq        : inout std_logic_vector(31 downto 0);
        I_sdrc_rst_n       : in    std_logic;
        I_sdrc_clk         : in    std_logic;
        I_sdram_clk        : in    std_logic;
        I_sdrc_selfrefresh : in    std_logic;
        I_sdrc_power_down  : in    std_logic;
        I_sdrc_wr_n        : in    std_logic;
        I_sdrc_rd_n        : in    std_logic;
        I_sdrc_addr        : in    std_logic_vector(20 downto 0);
        I_sdrc_data_len    : in    std_logic_vector(7 downto 0);
        I_sdrc_dqm         : in    std_logic_vector(3 downto 0);
        I_sdrc_data        : in    std_logic_vector(31 downto 0);
        O_sdrc_data        : out   std_logic_vector(31 downto 0);
        O_sdrc_init_done   : out   std_logic;
        O_sdrc_busy_n      : out   std_logic;
        O_sdrc_rd_valid    : out   std_logic;
        O_sdrc_wrd_ack     : out   std_logic
    );
end entity sdram_controller_fsm;

architecture rtl of sdram_controller_fsm is

    -- jedec command encoding on {cs_n, ras_n, cas_n, wen_n}
    subtype cmd_t is std_logic_vector(3 downto 0);
    constant CMD_NOP  : cmd_t := "0111";
    constant CMD_ACT  : cmd_t := "0011";
    constant CMD_READ : cmd_t := "0101";
    constant CMD_WRITE: cmd_t := "0100";
    constant CMD_PRE  : cmd_t := "0010";
    constant CMD_REF  : cmd_t := "0001";
    constant CMD_LMR  : cmd_t := "0000";
    constant CMD_INH  : cmd_t := "1111";

    -- mode register: full page burst, sequential, cas latency 3
    constant MODE_REG : std_logic_vector(10 downto 0) := "00000110111";

    type state_t is (
        S_RESET, S_INIT_WAIT, S_INIT_PRE, S_INIT_REF1, S_INIT_REF2, S_INIT_LMR,
        S_IDLE, S_REF,
        S_ACT_RD, S_RD, S_RD_DATA,
        S_ACT_WR, S_WR_DATA, S_TWR,
        S_PRE
    );
    signal curr_state, next_state : state_t;

    -- one counter shared by every state, cleared on each state change
    signal tmr : unsigned(13 downto 0);

    -- debug taps, all off in normal use
    constant DIAG_READ_RAMP   : boolean := false;
    constant DIAG_WRITE_RAMP  : boolean := false;
    constant DIAG_WRITE_SPIKE : boolean := false;
    constant SPIKE_IDX        : natural := 20;

    -- command parameters latched when a strobe is accepted in idle
    signal ba_lat  : std_logic_vector(1 downto 0);
    signal col_lat : std_logic_vector(7 downto 0);
    signal len_lat : unsigned(7 downto 0);
    signal dqm_lat : std_logic_vector(3 downto 0);

    signal ref_cnt : unsigned(9 downto 0);
    signal ref_req : std_logic;

    -- write data delay line made of single registers: an indexed buffer
    -- array here gets mapped to ssram and corrupts part of the burst
    signal wpipe1 : std_logic_vector(31 downto 0);
    signal wpipe2 : std_logic_vector(31 downto 0);
    signal wpipe3 : std_logic_vector(31 downto 0);

    signal dq_in_r  : std_logic_vector(31 downto 0);
    signal dq_out_r : std_logic_vector(31 downto 0);
    signal dq_oe_r  : std_logic;

    signal cmd_r       : cmd_t;
    signal addr_r      : std_logic_vector(10 downto 0);
    signal bank_r      : std_logic_vector(1 downto 0);
    signal dqm_r       : std_logic_vector(3 downto 0);
    signal init_done_r : std_logic;
    signal busy_n_r    : std_logic;
    signal rd_valid_r  : std_logic;
    signal wrd_ack_r   : std_logic;
    signal data_r      : std_logic_vector(31 downto 0);

begin

    -- the die is clocked by the phase shifted copy of the user clock
    O_sdram_clk <= I_sdram_clk;
    O_sdram_cke <= '1';

    O_sdram_cs_n  <= cmd_r(3);
    O_sdram_ras_n <= cmd_r(2);
    O_sdram_cas_n <= cmd_r(1);
    O_sdram_wen_n <= cmd_r(0);
    O_sdram_addr  <= addr_r;
    O_sdram_ba    <= bank_r;
    O_sdram_dqm   <= dqm_r;

    IO_sdram_dq <= dq_out_r when dq_oe_r = '1' else (others => 'Z');

    O_sdrc_data      <= data_r;
    O_sdrc_init_done <= init_done_r;
    O_sdrc_busy_n    <= busy_n_r;
    O_sdrc_rd_valid  <= rd_valid_r;
    O_sdrc_wrd_ack   <= wrd_ack_r;

    p_comb : process(curr_state, tmr, ref_req, I_sdrc_wr_n, I_sdrc_rd_n, len_lat)
    begin
        next_state <= curr_state;
        case curr_state is
            when S_RESET     => next_state <= S_INIT_WAIT;

            when S_INIT_WAIT =>
                if tmr = INIT_WAIT_CYCLES - 1 then next_state <= S_INIT_PRE; end if;
            when S_INIT_PRE  =>
                if tmr = TRP_CYCLES  - 1 then next_state <= S_INIT_REF1; end if;
            when S_INIT_REF1 =>
                if tmr = TRFC_CYCLES - 1 then next_state <= S_INIT_REF2; end if;
            when S_INIT_REF2 =>
                if tmr = TRFC_CYCLES - 1 then next_state <= S_INIT_LMR;  end if;
            when S_INIT_LMR  =>
                if tmr = TMRD_CYCLES - 1 then next_state <= S_IDLE;      end if;

            when S_IDLE =>
                -- user strobes last one cycle and cannot be missed, so they
                -- win over a pending refresh, which waits for the next idle
                if    I_sdrc_wr_n  = '0' then next_state <= S_ACT_WR;
                elsif I_sdrc_rd_n  = '0' then next_state <= S_ACT_RD;
                elsif ref_req      = '1' then next_state <= S_REF;
                end if;

            when S_REF =>
                if tmr = TRFC_CYCLES - 1 then next_state <= S_IDLE; end if;

            when S_ACT_RD =>
                if tmr = TRCD_CYCLES - 1 then next_state <= S_RD; end if;
            when S_RD =>
                -- wait cas latency plus the two capture registers on the read path
                if tmr = CL_CYCLES + 1 + RD_CAP_ADJ then next_state <= S_RD_DATA; end if;
            when S_RD_DATA =>
                if tmr = len_lat then next_state <= S_PRE; end if;

            when S_ACT_WR =>
                if tmr = TRCD_CYCLES - 1 then next_state <= S_WR_DATA; end if;
            when S_WR_DATA =>
                if tmr = len_lat then next_state <= S_TWR; end if;
            when S_TWR =>
                if tmr = TWR_CYCLES - 1 then next_state <= S_PRE; end if;

            when S_PRE =>
                if tmr = TRP_CYCLES - 1 then next_state <= S_IDLE; end if;
        end case;
    end process;

    -- state register, counters and all registered outputs
    p_sync : process(I_sdrc_clk)
        variable ntmr : unsigned(13 downto 0);
    begin
        if rising_edge(I_sdrc_clk) then
            if I_sdrc_rst_n = '0' then
                curr_state  <= S_RESET;
                tmr         <= (others => '0');
                wpipe1      <= (others => '0');
                wpipe2      <= (others => '0');
                wpipe3      <= (others => '0');
                ref_cnt     <= (others => '0');
                ref_req     <= '0';
                init_done_r <= '0';
                busy_n_r    <= '0';
                rd_valid_r  <= '0';
                wrd_ack_r   <= '0';
                dq_oe_r     <= '0';
                cmd_r       <= CMD_INH;
                addr_r      <= (others => '0');
                bank_r      <= (others => '0');
                dqm_r       <= (others => '0');
                data_r      <= (others => '0');
            else
                curr_state <= next_state;
                if next_state /= curr_state then ntmr := (others => '0');
                else                             ntmr := tmr + 1;
                end if;
                tmr <= ntmr;

                -- free running refresh timer, served at the next idle
                if ref_cnt = REFRESH_INTERVAL - 1 then
                    ref_cnt <= (others => '0');
                    ref_req <= '1';
                else
                    ref_cnt <= ref_cnt + 1;
                end if;
                if curr_state = S_REF then
                    ref_req <= '0';
                end if;

                if curr_state = S_INIT_LMR and next_state = S_IDLE then
                    init_done_r <= '1';
                end if;
                -- ready only in idle with no refresh pending, so a user strobe
                -- can never land on the cycle the refresh starts
                if next_state = S_IDLE and ref_req = '0' then busy_n_r <= '1';
                else                                          busy_n_r <= '0';
                end if;

                if curr_state = S_IDLE and
                   (I_sdrc_wr_n = '0' or I_sdrc_rd_n = '0') then
                    ba_lat  <= I_sdrc_addr(20 downto 19);
                    col_lat <= I_sdrc_addr( 7 downto  0);
                    len_lat <= unsigned(I_sdrc_data_len);
                    dqm_lat <= I_sdrc_dqm;
                end if;

                -- the delay line always shifts, so the word streamed one cycle
                -- after the strobe reaches dq exactly when the write command does
                wpipe1 <= I_sdrc_data;
                wpipe2 <= wpipe1;
                wpipe3 <= wpipe2;
                wrd_ack_r <= '0';

                if next_state = S_WR_DATA then
                    if DIAG_WRITE_SPIKE then
                        if ntmr = SPIKE_IDX then dq_out_r <= x"00004000";
                        else                     dq_out_r <= (others => '0'); end if;
                    elsif DIAG_WRITE_RAMP then
                        dq_out_r <= x"0000" & std_logic_vector(shift_left(resize(ntmr, 16), 11));
                    elsif WR_ALIGN = 1 then
                        dq_out_r <= wpipe3;
                    else
                        dq_out_r <= wpipe2;
                    end if;
                    dq_oe_r <= '1';
                else
                    dq_oe_r <= '0';
                end if;

                -- dq is sampled on the user clock; the die drives it on the
                -- shifted clock, so the edge lands in the middle of the window
                dq_in_r <= IO_sdram_dq;
                if next_state = S_RD_DATA then
                    if DIAG_READ_RAMP then
                        data_r <= std_logic_vector(resize(ntmr, 32));
                    else
                        data_r <= dq_in_r;
                    end if;
                    rd_valid_r <= '1';
                else
                    rd_valid_r <= '0';
                end if;

                -- each command goes out on the first cycle of its state
                cmd_r  <= CMD_NOP;
                addr_r <= (others => '0');
                bank_r <= ba_lat;
                if next_state /= curr_state then
                    case next_state is
                        when S_INIT_PRE | S_PRE =>
                            cmd_r  <= CMD_PRE;
                            addr_r <= "10000000000";
                        when S_INIT_REF1 | S_INIT_REF2 | S_REF =>
                            cmd_r  <= CMD_REF;
                        when S_INIT_LMR =>
                            cmd_r  <= CMD_LMR;
                            addr_r <= MODE_REG;
                            bank_r <= "00";
                        when S_ACT_RD | S_ACT_WR =>
                            -- row and bank come straight from the port: the
                            -- latch is still loading on this same cycle
                            cmd_r  <= CMD_ACT;
                            addr_r <= I_sdrc_addr(18 downto 8);
                            bank_r <= I_sdrc_addr(20 downto 19);
                        when S_RD =>
                            cmd_r  <= CMD_READ;
                            addr_r <= "000" & col_lat;
                        when S_WR_DATA =>
                            cmd_r  <= CMD_WRITE;
                            addr_r <= "000" & col_lat;
                        when others =>
                            cmd_r  <= CMD_NOP;
                    end case;
                end if;

                -- mask the data bus outside the data windows
                if next_state = S_RD or next_state = S_RD_DATA then
                    dqm_r <= "0000";
                elsif next_state = S_WR_DATA then
                    dqm_r <= dqm_lat;
                else
                    dqm_r <= "1111";
                end if;

            end if;
        end if;
    end process;

end architecture rtl;
