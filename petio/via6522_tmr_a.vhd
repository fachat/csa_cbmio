-------------------------------------------------------------------------------
-- Title      : VIA 6522 Timer A
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity via6522_tmr_a is
port (
    phi2x8         : in  std_logic;
    phi2falling_en : in  std_logic;
    phi2rising_en  : in  std_logic;
    reset          : in  std_logic;
    acr            : in  std_logic_vector(7 downto 0);
    data_in        : in  std_logic_vector(7 downto 0);
    write_t1c_h    : in  std_logic;
    timer_a_latch  : in  std_logic_vector(15 downto 0);
    timer_a_count  : out std_logic_vector(15 downto 0);
    timer_a_out    : out std_logic;
    timer_a_event  : out std_logic);
end via6522_tmr_a;

architecture rtl of via6522_tmr_a is
    constant latch_reset_pattern : std_logic_vector(15 downto 0) := X"5550";

    alias tmr_a_output_en : std_logic is acr(7);
    alias tmr_a_freerun   : std_logic is acr(6);

    signal timer_a_count_i              : std_logic_vector(15 downto 0) := latch_reset_pattern;
    signal timer_a_out_i                : std_logic := '1';
    signal timer_a_event_i              : std_logic := '0';
    signal timer_a_input_latch          : std_logic_vector(7 downto 0);
    signal timer_a_write_t1c_h          : std_logic;
    signal timer_a_underflow_next       : std_logic;
    signal timer_a_underflow_next_d     : std_logic;
    signal timer_a_underflow_next_d2    : std_logic;
    signal timer_a_active_ff            : std_logic;
    signal timer_a_active_underflow     : std_logic;
    signal timer_a_active_underflow_d   : std_logic;
    signal timer_a_reload               : std_logic;
    signal timer_a_toggle               : std_logic;
    signal timer_a_may_interrupt        : std_logic;
begin
    timer_a_count <= timer_a_count_i;
    timer_a_out <= timer_a_out_i;
    timer_a_event <= timer_a_event_i;

    process(phi2x8, reset, data_in, write_t1c_h, timer_a_input_latch,
            timer_a_reload, timer_a_latch, timer_a_count_i, timer_a_write_t1c_h,
            timer_a_underflow_next, timer_a_underflow_next_d, timer_a_underflow_next_d2,
            timer_a_active_ff, timer_a_active_underflow, timer_a_active_underflow_d, acr)
    begin
        if (falling_edge(phi2x8) and phi2falling_en = '1') then
            if reset='1' then
                timer_a_toggle <= '1';
            elsif write_t1c_h = '1' then
                timer_a_toggle <= not tmr_a_output_en;
            elsif timer_a_event_i = '1' and tmr_a_output_en = '1' then
                timer_a_toggle <= not timer_a_toggle;
            end if;

            if (write_t1c_h = '1') then
                timer_a_input_latch <= data_in;
                timer_a_write_t1c_h <= '1';
            else
                timer_a_write_t1c_h <= '0';
            end if;
        end if;

        if (falling_edge(phi2x8) and phi2rising_en = '1') then
            if reset='1' then
                timer_a_may_interrupt <= '0';
                timer_a_count_i <= latch_reset_pattern;
            elsif timer_a_write_t1c_h = '1' then
                timer_a_may_interrupt <= '1';
                timer_a_count_i <= timer_a_input_latch & timer_a_latch(7 downto 0);
            elsif timer_a_reload = '1' then
                timer_a_count_i <= timer_a_latch;
                timer_a_may_interrupt <= timer_a_may_interrupt and tmr_a_freerun;
            else
                timer_a_count_i <= timer_a_count_i - X"0001";
            end if;

            if (timer_a_reload = '1' and timer_a_may_interrupt = '1') then
                timer_a_event_i <= '1';
            else
                timer_a_event_i <= '0';
            end if;

            timer_a_underflow_next_d <= timer_a_underflow_next;
        end if;

        if falling_edge(phi2x8) and phi2falling_en = '1' then
            if reset='1' then
                timer_a_underflow_next <= '0';
            else
                timer_a_underflow_next <= '0';
                if timer_a_count_i = X"0000" and write_t1c_h = '0' then
                    timer_a_underflow_next <= '1';
                end if;
            end if;

            timer_a_active_underflow_d <= timer_a_active_underflow;
            timer_a_underflow_next_d2 <= timer_a_underflow_next_d;
        end if;

        if (timer_a_write_t1c_h = '1') then
            timer_a_active_ff <= '1';
        elsif (reset = '1' or (timer_a_active_underflow_d = '1' and acr(6) = '0')) then
            timer_a_active_ff <= '0';
        end if;

        timer_a_active_underflow <= timer_a_active_ff and timer_a_underflow_next;
        timer_a_reload <= timer_a_underflow_next_d2 and not(timer_a_write_t1c_h);
    end process;

    timer_a_out_i <= timer_a_toggle;
end rtl;
