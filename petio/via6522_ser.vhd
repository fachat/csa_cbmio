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
    cb1_pos         : in  std_logic;	-- falling
    cb1_neg         : in  std_logic;	-- falling
    cb2_d1          : in  std_logic;
    timer_b_sr_tick : in  std_logic;
    shift_reg       : out std_logic_vector(7 downto 0);
    serial_event    : out std_logic;
    serport_en      : out std_logic;
    ser_cb2_o       : out std_logic;
    cb1_t_int       : out std_logic;
    cb1_o_int       : out std_logic);
end via6522_ser;

architecture rtl of via6522_ser is

		signal so_cb2			: std_logic;
		signal t2l_ufl			: std_logic;
		signal asel_sr			: std_logic;
		signal sr_in			: std_logic;
		signal sflag_o			: std_logic_vector(1 downto 0);
		signal sr_done       : std_logic;
		signal si_cb2 			: std_logic;
		signal sclo_cb1		: std_logic;
		signal sr_run        : std_logic;
		signal rd				: std_logic;
		signal we				: std_logic;
		signal sr_latch      : std_logic_vector(7 downto 0);
		signal sr		      : std_logic_vector(7 downto 0);
		signal sclk_edge     : std_logic;
		signal sclk_next     : std_logic;
		signal sclk_latch    : std_logic;
		signal sclk_toggle   : std_logic;
		signal sr_shift      : std_logic;
		signal sr_cnt        : std_logic_vector(4 downto 0);
		signal sr_cnt_latch  : std_logic_vector(4 downto 0);
		signal ifr				: std_logic_vector(2 downto 2);
--    signal asel_sr       : std_logic;
--    signal sr_in         : std_logic;
--    signal sclk_reg      : std_logic;
--    signal sclk_prev     : std_logic;

begin

	 ifr(2) <= irq_flag2;
	 
	 -- is the shift register selected? (async)
    asel_sr <= '1' when addr = "1010" else '0';
	 -- so_cb2 is the shift register output. si_cb2 input
	 -- when in output mode, shift register output feeds back into the input
    sr_in <= so_cb2 when acr(4) = '1' else si_cb2;
	 ser_cb2_o <= so_cb2;
	 
	 serial_event <= sflag_o(1);
	 si_cb2 <= cb2_d1;
	 we <= wen;
	 rd <= ren;
	 
	 -- sclk_latch, sr_run are falling
--    sclk_next <= sclk_latch or not sr_run;
	 -- <= sclk_prev is rising
	 -- <= sclk_reg is falling(!)
	 -- used in falling!
--    sclk_edge <= (sclk_prev and not sclk_reg) when acr(4) = '1'
--                 else (not sclk_prev and sclk_reg);
					
	 t2l_ufl <= timer_b_sr_tick;

	 -- resetting / setting the interrupt flag?
    process (sr_done, acr, sclo_cb1, rd, we, asel_sr)
    begin
        sflag_o(1) <= '0';
        if sr_done = '1' and acr(4 downto 2) /= "100"
           and (acr(3 downto 2) = "11" or sclo_cb1 = '1') then
            sflag_o(1) <= '1';
        end if;
        sflag_o(0) <= (rd or we) and asel_sr;
    end process;

    process (phi2)
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
			if (acr(4) = '1') then
				sclk_edge <= cb1_neg;
			else
				sclk_edge <= cb1_pos;
			end if;
		end if;

		if (rising_edge(phi2)) then
				-- <- data_in
				-- <- we,
				-- -> sr_latch (falling)
				-- TODO: use latched input byte (last_data)
				--> sr_latch (rising)
				--> so_cb2 (rising)
            if we = '1' and asel_sr = '1' then
                sr_latch <= data_in;
            else
                if sr_shift = '1' then
                    so_cb2 <= sr(0);
                    sr_latch <= sr(7 downto 1) & sr_in;
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

		if (rising_edge(phi2)) then
			-- sclk_latch, sr_run are falling
			sclk_next <= sclk_latch or not sr_run;
		end if;
		
		if (falling_edge(phi2)) then
				-- falling
				-- <= sclk_next (rising)
				-- => sclk_latch (falling)
				-- => sclo_cb1
            sclo_cb1 <= sclk_next;
            if sclk_toggle = '1' then
                sclk_latch <= not sclo_cb1;
				else
                sclk_latch <= sclk_next;
            end if;
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
		
--        if rising_edge(clk) then

		  
--				-- <- data_in
--				-- <- we,
--				-- -> sr_latch (falling)
--				-- TODO: use latched input byte (last_data)
--				--> sr_latch (rising)
--				--> so_cb2 (rising)
--            if we = '1' and asel_sr = '1' then
--                sr_latch <= data_in;
--            elsif phi2 = '0' then
--                if sr_shift = '1' then
--                    so_cb2 <= sr(0);
--                    sr_latch <= sr(7 downto 1) & sr_in;
--                else
--                    so_cb2 <= so_cb2;
--                    sr_latch <= sr;
--                end if;
--            end if;

--				-- falling
--				-- <- sclk_edge (rising)
--				-- <- sr_latch (rising)
--				-- -> sr_shift (falling)
--				-- -> sr (falling)
--            if phi2 = '1' then
--                sr_shift <= sclk_edge and not ifr(2);
--                sr <= sr_latch;
--            end if;

--				-- falling
--				-- <- t2_ufl (rising)
--				-- -> sclk_toggle
--           if phi2 = '1' then
--                if ((acr(4 downto 2) = "100" or acr(3 downto 2) = "01")
--                    and t2l_ufl = '1')
--                   or acr(3 downto 2) = "10" then
--                    sclk_toggle <= not ifr(2);
--                else
--                    sclk_toggle <= '0';
--                end if;
--            end if;

--				-- falling
--				-- <= sclk_next (rising)
--				-- => sclk_latch (falling)
--				-- => sclo_cb1
--            if phi2 = '1' then
--                sclk_latch <= sclk_next;
--                sclo_cb1 <= sclk_next;
--            elsif sclk_toggle = '1' then
--                sclk_latch <= not sclo_cb1;
--            end if;

--				-- rising
--				-- <= sr_run (falling)
--				-- <= sr_cnt (falling)
--				-- => sr_cnt_latch
--            if sr_run = '0' then
--                sr_cnt_latch <= (others => '1');
--            elsif not (we = '1' and asel_sr = '1') and phi2 = '0' then
--                if sr_shift = '1' then
--                    sr_cnt_latch <= (not sr_cnt(0)) & sr_cnt(4 downto 1);
--                else
--                    sr_cnt_latch <= sr_cnt;
--                end if;
--            end if;

--				-- falling
--				-- <= sr_cnt_latch (rising)
--				-- => sr_done
--            if phi2 = '1' then
--                sr_cnt <= sr_cnt_latch;
--                sr_done <= sr_cnt_latch(2) and not sr_cnt_latch(1);
--            end if;

--				-- falling
--				-- <= scli_cb1 (???)
--				-- <= sclk_reg (
--            if phi2 = '1' then
--                sclk_reg <= scli_cb1;
--            end if;
--				
--				-- rising
--				-- <= sclk_reg (falling)
--				-- => sclk_prev
--            if phi2 = '0' then
--                sclk_prev <= sclk_reg;
--            end if;
--        end if;
    end process;


--    shift_reg <= shift_reg_i;
--    serial_event <= serial_event_i;
--    serport_en <= serport_en_i;
--    ser_cb2_o <= ser_cb2_o_i;
--    cb1_t_int <= cb1_t_int_i;
--    cb1_o_int <= cb1_o_int_i;
--
--    sr_uses_t2 <= '1' when shift_mode_control = "100" or acr(3 downto 2) = "01" else '0';
--    sr_uses_phi2 <= not(acr(2)) and acr(3);
--    sr_uses_ext_clk <= acr(2) and acr(3);
--    sr_disabled <= not(acr(2)) and not(acr(3)) and not(acr(4));
--    sr_is_output <= acr(4);
--    sr_free_running <= acr(4) and not(acr(3)) and not(acr(2));
--
--    sr_wr <= '1' when wen='1' and addr=x"A" else '0';
--    sr_rd <= '1' when ren='1' and addr=x"A" else '0';
--
--    cb1_t_int_i <= '0' when sr_disabled = '1' or sr_uses_ext_clk = '1' else '1';
--    serport_en_i <= not(sr_disabled);
--    cb1_o_int_i <= sr_cb1_q;
--
--    sr_control: process(phi2)
--    begin
--			-- sr_disabled is falling (but acr)
--			-- sr_uses_t2 is falling (but acr)
--			-- irq_flag2 is ???
--			--> sr_toggle_clk_output is falling
--        if (falling_edge(phi2)) then
--            sr_toggle_clk_output <= '0';
--            if (sr_disabled = '0' and irq_flag2 = '0') then
--                if (sr_uses_phi2 = '1') then
--                    sr_toggle_clk_output <= '1';
--                elsif (sr_uses_t2 = '1') then
--                    sr_toggle_clk_output <= timer_b_sr_tick;
--                end if;
--            end if;
--        end if;
--
--			-- sr_toggle_clk_output is falling
--			--> sr_toggle_clk_output_d is rising
--        if (rising_edge(phi2)) then
--            sr_toggle_clk_output_d <= sr_toggle_clk_output;
--        end if;
--
--			-- sr_running is falling XXX!
--			-- sr_toggle_clk_output_d is rising
--			--> sr_cb1_q is falling
--        if (falling_edge(phi2)) then
--            if (sr_running = '0') then
--                sr_cb1_q <= '1';
--            elsif (sr_toggle_clk_output_d = '1') then
--                sr_cb1_q <= not(sr_cb1_q);
--            end if;
--        end if;
--
--			-- sr_disabled is falling but acr
--			-- sr_wr is valid at falling
--			-- sr_rd is valid at falling
--			-- irq_flag2 is ???
--			--> sr_running is falling
--        if (falling_edge(phi2)) then
--            if (sr_wr = '1' or sr_rd = '1') then
--                sr_running <= '1';
--            elsif (irq_flag2 = '1' or sr_disabled = '1') then
--                sr_running <= '0';
--            end if;
--        end if;
--
--			-- irq_flag2 is ???
--			-- sr_wr is valid at falling edge
--			--> sr_shift is falling
--        if (falling_edge(phi2)) then
--            if (irq_flag2 = '1') then
--                sr_shift <= '0';
--            elsif (sr_wr = '1') then
--                sr_shift <= '0';
--            else
--                if (sr_is_output = '1') then
--                    sr_shift <= cb1_neg;
--                else
--                    sr_shift <= cb1_pos;
--                end if;
--            end if;
--        end if;
--
--			-- sr_running is falling XXX
--			-- sr_shift is falling XXX
--			-- sr_free_running is falling but acr
--			-- sr_bit_cnt is ???
--			--> serial_event_i is falling
--			--> sr_bit_cnt is falling
--			--> sr_last_bit is falling
--        if (falling_edge(phi2)) then
--            if (sr_running = '0') then
--                sr_bit_cnt <= 8;
--            elsif (sr_shift = '1' and sr_bit_cnt /= 0) then
--                sr_bit_cnt <= sr_bit_cnt - 1;
--            end if;
--
--            serial_event_i <= '0';
--            if (sr_bit_cnt = 0 and serial_event_i = '0') then
--                sr_last_bit <= '1';
--                if (sr_free_running = '0') then
--                    if (sr_cb1_q = '1' or sr_uses_ext_clk = '1') then
--                        serial_event_i <= '1';
--                    end if;
--                end if;
--            else
--                sr_last_bit <= '0';
--            end if;
--        end if;
--    end process;
--
--    sr: process(phi2)
--    begin
--			-- data_in is valid at falling
--			-- wen,addr is valid at falling
--			-- sr_is_output is falling but acr
--			--> shift_reg_i is falling
--        if (falling_edge(phi2)) then
--            if reset = '1' then
--                shift_reg_i <= X"FF";
--            else
--                if wen = '1' and addr = X"A" then
--                    shift_reg_i <= data_in;
--                elsif sr_shift = '1' then
--                    if (sr_is_output = '1') then
--                        shift_reg_i <= shift_reg_i(6 downto 0) & shift_reg_i(7);
--                    else
--                        shift_reg_i <= shift_reg_i(6 downto 0) & cb2_d1;
--                    end if;
--                end if;
--            end if;
--
--            ser_cb2_o_i <= shift_reg_i(7);
--        end if;
--    end process;
end rtl;
