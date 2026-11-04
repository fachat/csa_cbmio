-------------------------------------------------------------------------------
-- Title      : VIA 6522 Serial block
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity via6522_ser is
port (
    phi2            : in  std_logic;
    reset           : in  std_logic;
    acr             : in  std_logic_vector(7 downto 0);
    irq_flag2       : in  std_logic;
    addr            : in  std_logic_vector(3 downto 0);
    wen             : in  std_logic;
    ren             : in  std_logic;
    data_in         : in  std_logic_vector(7 downto 0);
    cb1_in          : in  std_logic;
    cb2_in          : in  std_logic;
    timer_b_sr_tick : in  std_logic;
    shift_reg       : out std_logic_vector(7 downto 0);
    serial_event    : out std_logic;
    serport_en      : out std_logic;
    ser_cb2_o       : out std_logic;
    cb1_t_int       : out std_logic;
    cb1_o_int       : out std_logic;
	 ser_dbg			  : out std_logic);
end via6522_ser;

architecture rtl of via6522_ser is

		signal so_cb2			: std_logic;
		signal t2l_ufl			: std_logic;
		signal asel_sr			: std_logic;
		signal sr_in			: std_logic;
		signal sflag_o			: std_logic_vector(1 downto 0);
		signal sr_done       : std_logic;
		signal sclo_cb1		: std_logic;
		signal sr_run        : std_logic;
		signal rd				: std_logic;
		signal we				: std_logic;
		signal sr_latch      : std_logic_vector(7 downto 0);
		signal sr_latch_pre  : std_logic_vector(7 downto 0);
		signal sr		      : std_logic_vector(7 downto 0);
		signal sr_latch_write: std_logic;
		signal sclk_edge     : std_logic;
		signal sclk_next     : std_logic;
		signal sclk_latch    : std_logic;
		signal sclk_toggle   : std_logic;
		signal sr_shift      : std_logic;
		signal sr_cnt        : std_logic_vector(4 downto 0);
		signal sr_cnt_latch  : std_logic_vector(4 downto 0);
		signal ifr				: std_logic_vector(2 downto 2);
		signal cb1_reg			: std_logic;
		signal cb1_prev		: std_logic;
begin

--	 ser_dbg <= sclk_edge;
--	 ser_dbg <= sr_shift;
--	 ser_dbg <= sr_latch(1);
--	 ser_dbg <= sr(0);
--	 ser_dbg <= sr_latch_write;
	 ser_dbg <= sr_in;
	 
	 ifr(2) <= irq_flag2;
	 
	 -- is the shift register selected? (async)
    asel_sr <= '1' when addr = "1010" else '0';
	 -- so_cb2 is the shift register output. si_cb2 input
	 -- when in output mode, shift register output feeds back into the input
    sr_in <= so_cb2 when acr(4) = '1' else cb2_in;

	 ser_cb2_o <= so_cb2;
	 serport_en <= acr(4);
	 
	 serial_event <= sflag_o(1);
	 we <= wen;
	 rd <= ren;
	 
	 cb1_t_int <= '0' when acr(4 downto 2) = "000" 		-- input when off
					else '0' when acr(3 downto 2) = "11"	-- input when under external clock
					else '1';										-- else output
	 cb1_o_int <= sclo_cb1;
	 
	 shift_reg <= sr_latch;
	 
	 t2l_ufl <= timer_b_sr_tick;

	 -- resetting / setting the interrupt flag?
    process (sr_done, acr, sclo_cb1, rd, we, asel_sr, sr, sr_latch)
    begin
        sflag_o(1) <= '0';
        if sr_done = '1' and acr(4 downto 2) /= "100"
           and (acr(3 downto 2) = "11" or sclo_cb1 = '1') then
            sflag_o(1) <= '1';
        end if;
        sflag_o(0) <= (rd or we) and asel_sr;
    end process;

    process (phi2, acr, cb1_prev, cb1_reg)
    begin
		-- sr_run (falling): set when SR is read or written to
		if (falling_edge(phi2)) then
            if (rd = '1' or we = '1') and asel_sr = '1' then
                sr_run <= '1';
            elsif acr(4 downto 2) = "000" or ifr(2) = '1' then
                sr_run <= '0';
            end if;
		end if;

		if (rising_edge(phi2)) then
			cb1_reg <= cb1_in;
		end if;
		if (rising_edge(phi2)) then
			cb1_prev <= cb1_reg;
		end if;
		
		-- falling edge for output, rising edge for input
 		if (acr(4) = '1') then
			-- output
			sclk_edge <= cb1_prev and not(cb1_reg);
		 else
			-- input
			sclk_edge <= not(cb1_prev) and cb1_reg;
		end if;

		if (falling_edge(phi2)) then
				-- <- data_in
				-- <- we,
				-- -> sr_latch_pre, _write (falling)
            if we = '1' and asel_sr = '1' then
                sr_latch_pre <= data_in;
					 sr_latch_write <= '1';
            else
					sr_latch_write <= '0';
				end if;
		end if;
 
		if (rising_edge(phi2)) then
				-- <- sr_latch_pre, _write
				--> sr_latch (rising)
				--> so_cb2 (rising)
            if sr_latch_write = '1' then
                sr_latch <= sr_latch_pre;
            else
                if sr_shift = '1' then
                    so_cb2 <= sr(7);
                    sr_latch <= sr(6 downto 0) & sr_in;
                else
                    so_cb2 <= so_cb2;
                    sr_latch <= sr;
                end if;
            end if;
		end if;

		if (falling_edge(phi2)) then
				-- falling
				-- <- sclk_edge (rising)
				-- <- sr_latch (rising)
				-- -> sr_shift (falling)
				-- -> sr (falling)
            sr_shift <= sclk_edge and not ifr(2);
            sr <= sr_latch;
		end if;

		if (falling_edge(phi2)) then
			 -- falling
			 -- <- t2_ufl (rising)
			 -- -> sclk_toggle (falling)
          if ((acr(4 downto 2) = "100" or acr(3 downto 2) = "01")
                and t2l_ufl = '1')
               or acr(3 downto 2) = "10" then
              sclk_toggle <= not ifr(2);
          else
              sclk_toggle <= '0';
          end if;
		end if;

		sclk_next <= sclk_latch or not sr_run;
		
		if (rising_edge(phi2)) then
			-- sclk_latch, sr_run are falling
            if sclk_toggle = '1' then
                sclk_latch <= not sclo_cb1;
				else
                sclk_latch <= sclk_next;
            end if;
		end if;
		
		if (falling_edge(phi2)) then
				-- falling
				-- <= sclk_next (rising)
				-- => sclk_latch (falling)
				-- => sclo_cb1
            sclo_cb1 <= sclk_next;
		end if;
		
		if (rising_edge(phi2)) then
				-- rising
				-- <= sr_run (falling)
				-- <= sr_cnt (falling)
				-- => sr_cnt_latch
            if sr_run = '0' then
                sr_cnt_latch <= (others => '1');
            elsif not (we = '1' and asel_sr = '1') then
                if sr_shift = '1' then
                    sr_cnt_latch <= (not sr_cnt(0)) & sr_cnt(4 downto 1);
                else
                    sr_cnt_latch <= sr_cnt;
                end if;
            end if;
		end if;

		if (falling_edge(phi2)) then
				-- falling
				-- <= sr_cnt_latch (rising)
				-- => sr_done
            sr_cnt <= sr_cnt_latch;
            sr_done <= sr_cnt_latch(2) and not sr_cnt_latch(1);
		end if;
		
    end process;

end rtl;
