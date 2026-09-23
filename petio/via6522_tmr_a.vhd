-------------------------------------------------------------------------------
-- Title      : VIA 6522 Timer A
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity via6522_tmr_a is
port (
    phi2           : in  std_logic;
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

	signal t1_count		: std_logic_vector(15 downto 0);
	signal t1_count_prev	: std_logic_vector(15 downto 0);
	signal t1_latch		: std_logic_vector(15 downto 0);
	
	signal t1_load   		: std_logic;
	signal t1_ufl   		: std_logic;
	signal t1_ufl_prev		: std_logic;
	signal t1_run			: std_logic;
	signal w_t1c_h			: std_logic;
	signal s_t1				: std_logic;
	signal s_t1_prev		: std_logic;
	signal t1_pb7			: std_logic;
	signal t1_pb7_reg		: std_logic;
	signal t1_pb7_prev	: std_logic;
	
begin

	t1_latch <= timer_a_latch;
	timer_a_count <= t1_count;
	timer_a_event <= s_t1;
	
    --w_t1l_h <= '1' when we = '1' and addr = ADDR_T1L_H else '0';
    t1_load <= '1' when t1_ufl_prev = '1' or w_t1c_h = '1' else '0';

    process (phi2)
    begin
        if rising_edge(phi2) then
                if t1_load = '1' then
                    t1_count <= t1_latch;
                else
                    t1_count <= std_logic_vector(unsigned(t1_count_prev) - 1);
                end if;

                if t1_count_prev = x"0000" and w_t1c_h = '0' then
                    t1_ufl <= '1';
                else
                    t1_ufl <= '0';
                end if;
        end if;

        if falling_edge(phi2) then
                t1_count_prev <= t1_count;
                t1_ufl_prev   <= t1_ufl;
        end if;

        if falling_edge(phi2) then
				w_t1c_h <= write_t1c_h;
			end if;

        if rising_edge(phi2) then
            if w_t1c_h = '1' then
                t1_run <= '1';
            elsif reset = '1' or (s_t1 = '1' and acr(6) = '0') then
                t1_run <= '0';
            end if;
		  end if;

--				-- w_t1c_h is set at falling, s_t1_prev is set a rising
--            if w_t1c_h = '1' then
--                t1_run <= '1';
--            elsif reset = '1' or (s_t1_prev = '1' and acr(6) = '0') then
--                t1_run <= '0';
--            end if;

        if falling_edge(phi2) then
                if t1_run = '1' and t1_ufl = '1' then
                    s_t1 <= '1';
                else
                    s_t1 <= '0';
                end if;
        end if;

        if rising_edge(phi2) then
                s_t1_prev   <= s_t1;
                t1_pb7_prev <= t1_pb7_reg;
        end if;

            if w_t1c_h = '1' then
                t1_pb7_reg <= '0';
            elsif acr(7) = '0' then
                t1_pb7_reg <= '1';
            elsif phi2 = '1' and t1_run = '1' and t1_ufl = '1' then
                t1_pb7_reg <= not t1_pb7_prev;
            end if;

    end process;
	 
    --tflag_s_t1 <= s_t1;
    --tflag_r_t1 <= '1' when (rd = '1' and addr = ADDR_T1C_L) or w_t1c_h = '1' or w_t1l_h = '1' else '0';

    t1_pb7     <= t1_pb7_reg;

end rtl;
