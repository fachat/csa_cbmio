-------------------------------------------------------------------------------
-- Title      : VIA 6522 Timer B
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity via6522_tmr_b is
port (
    phi2x8         : in  std_logic;
    phi2falling_en : in  std_logic;
    phi2rising_en  : in  std_logic;
    reset          : in  std_logic;
    acr            : in  std_logic_vector(7 downto 0);
    port_b_i       : in  std_logic_vector(7 downto 0);
    write_t2c_h    : in  std_logic;
    last_data      : in  std_logic_vector(7 downto 0);
    timer_b_latch  : in  std_logic_vector(7 downto 0);
    timer_b_count  : out std_logic_vector(15 downto 0);
    timer_b_event  : out std_logic;
    timer_b_sr_tick: out std_logic);
end via6522_tmr_b;

architecture rtl of via6522_tmr_b is
    constant latch_reset_pattern : std_logic_vector(15 downto 0) := X"5550";

    alias shift_mode_control : std_logic_vector(2 downto 0) is acr(4 downto 2);

    signal timer_b_count_i : std_logic_vector(15 downto 0) := latch_reset_pattern;
    signal timer_b_event_i : std_logic := '0';
    signal timer_b_sr_tick_i : std_logic := '0';
    signal t2_count        : std_logic_vector(15 downto 0);
    signal t2_count_next   : std_logic_vector(15 downto 0);
    signal t2l_latch       : std_logic_vector(7 downto 0);
    signal w_t2c_h         : std_logic;
    signal t2_pb6_reg      : std_logic;
    signal t2_pb6_fall     : std_logic;
    signal t2_count_en     : std_logic;
    signal t2l_ufl_now     : std_logic;
    signal t2h_ufl         : std_logic;
    signal t2l_load        : std_logic;
    signal t2_run          : std_logic;
    signal s_t2            : std_logic;
    signal s_t2_prev       : std_logic;
begin
    timer_b_count <= timer_b_count_i;
    timer_b_event <= timer_b_event_i;
    timer_b_sr_tick <= timer_b_sr_tick_i;

    timer_b_event_i <= s_t2;
    timer_b_count_i <= t2_count;
    t2l_latch <= timer_b_latch;
    timer_b_sr_tick_i <= t2l_ufl_now;

    t2_count_en <= '1' when acr(5) = '0' or t2_pb6_fall = '1' else '0';
    t2l_load <= '1' when (t2l_ufl_now = '1' and (shift_mode_control = "100" or shift_mode_control(1 downto 0) = "01")) or w_t2c_h = '1' else '0';
    t2_count_next <= (t2_count - 1) when t2_count_en = '1' else t2_count;
    t2l_ufl_now <= '1' when t2_count(7 downto 0) = x"00" and t2_count_en = '1' and w_t2c_h = '0' else '0';

    process(phi2x8)
        variable pb6_sampled : std_logic;
    begin
        if (falling_edge(phi2x8) and phi2falling_en = '1') then
            if (reset = '1') then
                t2_count <= latch_reset_pattern;
                w_t2c_h <= '0';
                t2_pb6_reg <= '1';
                t2_pb6_fall <= '0';
                t2h_ufl <= '0';
                s_t2_prev <= '0';
            else
                pb6_sampled := To_X01(port_b_i(6));
                if (t2_pb6_reg = '1' and pb6_sampled = '0') then
                    t2_pb6_fall <= '1';
                else
                    t2_pb6_fall <= '0';
                end if;
                t2_pb6_reg <= pb6_sampled;

                if (write_t2c_h = '1') then
                    w_t2c_h <= '1';
                else
                    w_t2c_h <= '0';
                end if;

                if (t2l_load = '1') then
                    t2_count(7 downto 0) <= t2l_latch;
                else
                    t2_count(7 downto 0) <= t2_count_next(7 downto 0);
                end if;

                if (w_t2c_h = '1') then
                    t2_count(15 downto 8) <= last_data;
                else
                    t2_count(15 downto 8) <= t2_count_next(15 downto 8);
                end if;

                if (t2_count = x"0000" and t2_count_en = '1' and w_t2c_h = '0') then
                    t2h_ufl <= '1';
                else
                    t2h_ufl <= '0';
                end if;

                s_t2_prev <= s_t2;
            end if;
        end if;
    end process;

    process(phi2x8)
        variable t2_run_next : std_logic;
    begin
        if (falling_edge(phi2x8) and phi2rising_en = '1') then
            if (reset = '1') then
                t2_run <= '0';
                s_t2 <= '0';
            else
                t2_run_next := t2_run;

                if (w_t2c_h = '1') then
                    t2_run_next := '1';
                elsif (s_t2_prev = '1') then
                    t2_run_next := '0';
                end if;
                t2_run <= t2_run_next;

                if (t2_run_next = '1' and t2h_ufl = '1') then
                    s_t2 <= '1';
                else
                    s_t2 <= '0';
                end if;
            end if;
        end if;
    end process;
end rtl;
