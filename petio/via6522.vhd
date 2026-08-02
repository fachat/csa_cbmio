-------------------------------------------------------------------------------
-- Title      : VIA 6522
-------------------------------------------------------------------------------
-- Author     : Gideon Zweijtzer  <gideon.zweijtzer@gmail.com>
-------------------------------------------------------------------------------
-- Description: This module implements the 6522 VIA chip.
--              A LOT OF REVERSE ENGINEERING has been done to make this module
--              as accurate as it is now. Thanks to gyurco for ironing out some
--              differences that were left unnoticed.
-------------------------------------------------------------------------------
-- License:     GPL 3.0 - Free to use, distribute and change to your own needs.
--              Leaving a reference to the author will be highly appreciated.
-------------------------------------------------------------------------------
-- taken from https://github.com/Rhialto/MegaPET/blob/rhialto/CORE/PET2001_MiSTer/rtl/via6522.vhd
-- on 20260318
--
-- Note: due to the different setup, no fast clock with clock-enable signals
-- are available, only phi2 directly. The design has been adapted accordingly
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity via6522 is
port (
--    clock       : in  std_logic;
--    rising      : in  std_logic;
--    falling     : in  std_logic;
	 phi2			 : in  std_logic;
    reset       : in  std_logic;
    
    addr        : in  std_logic_vector(3 downto 0);
    wen         : in  std_logic;
    ren         : in  std_logic;
    data_in     : in  std_logic_vector(7 downto 0);
    data_out    : out std_logic_vector(7 downto 0);

--    phi2_ref    : out std_logic;

    -- pio --
    port_a_o    : out std_logic_vector(7 downto 0);
    port_a_t    : out std_logic_vector(7 downto 0);
    port_a_i    : in  std_logic_vector(7 downto 0);
    
    port_b_o    : out std_logic_vector(7 downto 0);
    port_b_t    : out std_logic_vector(7 downto 0);
    port_b_i    : in  std_logic_vector(7 downto 0);

    -- handshake pins
    ca1_i       : in  std_logic;

    ca2_o       : out std_logic;
    ca2_i       : in  std_logic;
    ca2_t       : out std_logic;
    
    cb1_o       : out std_logic;
    cb1_i       : in  std_logic;
    cb1_t       : out std_logic;
    
    cb2_o       : out std_logic;
    cb2_i       : in  std_logic;
    cb2_t       : out std_logic;

    irq         : out std_logic );
    
end via6522;

architecture Gideon of via6522 is

    type pio_t is
    record
        pra     : std_logic_vector(7 downto 0);
        ddra    : std_logic_vector(7 downto 0);
        prb     : std_logic_vector(7 downto 0);
        ddrb    : std_logic_vector(7 downto 0);
    end record;
    
    constant pio_default : pio_t := (others => (others => '0'));
    constant latch_reset_pattern : std_logic_vector(15 downto 0) := X"5550";

    signal last_data     : std_logic_vector(7 downto 0) := X"55";
    
    signal pio_i         : pio_t;
    signal port_a_c      : std_logic_vector(7 downto 0) := (others => '0');
    signal port_b_c      : std_logic_vector(7 downto 0) := (others => '0');
    
    signal irq_mask      : std_logic_vector(6 downto 0) := (others => '0');
    signal irq_flags      : std_logic_vector(6 downto 0) := (others => '0');
	 signal irq_clr_strobe: std_logic_vector(6 downto 0) := (others => '0');
    signal irq_events    : std_logic_vector(6 downto 0) := (others => '0');
    signal irq_events_d  : std_logic_vector(6 downto 0) := (others => '0');
    signal irq_out       : std_logic;
    
    signal timer_a_latch : std_logic_vector(15 downto 0) := latch_reset_pattern;
    signal timer_b_latch : std_logic_vector(15 downto 0) := latch_reset_pattern;
    signal timer_a_count : std_logic_vector(15 downto 0) := latch_reset_pattern;
    signal timer_b_count : std_logic_vector(15 downto 0) := latch_reset_pattern;
    signal timer_a_out   : std_logic;
    signal timer_b_tick  : std_logic;
                         
    signal acr, pcr      : std_logic_vector(7 downto 0) := X"00";
    signal shift_reg     : std_logic_vector(7 downto 0) := X"00";
    signal serport_en    : std_logic;
    signal ser_cb2_o     : std_logic;
    signal hs_cb2_o      : std_logic;
    signal cb1_t_int     : std_logic;
    signal cb1_o_int     : std_logic;
    signal cb2_t_int     : std_logic;
    signal cb2_o_int     : std_logic;

    alias  ca2_event     : std_logic is irq_events(0);
    alias  ca1_event     : std_logic is irq_events(1);
    alias  serial_event  : std_logic is irq_events(2);
    alias  cb2_event     : std_logic is irq_events(3);
    alias  cb1_event     : std_logic is irq_events(4);
    alias  timer_b_event : std_logic is irq_events(5);
    alias  timer_a_event : std_logic is irq_events(6);

    alias  ca1_event_d   : std_logic is irq_events_d(1);
    alias  cb1_event_d   : std_logic is irq_events_d(4);

    alias  ca2_clr_strobe      : std_logic is irq_clr_strobe(0);
    alias  ca1_clr_strobe      : std_logic is irq_clr_strobe(1);
    alias  serial_clr_strobe   : std_logic is irq_clr_strobe(2);
    alias  cb2_clr_strobe      : std_logic is irq_clr_strobe(3);
    alias  cb1_clr_strobe      : std_logic is irq_clr_strobe(4);
    alias  timer_b_clr_strobe  : std_logic is irq_clr_strobe(5);
    alias  timer_a_clr_strobe  : std_logic is irq_clr_strobe(6);

    alias  ca1_irq_flag      : std_logic is irq_flags(1);
    alias  cb1_irq_flag      : std_logic is irq_flags(5);

    alias tmr_a_output_en   : std_logic is acr(7);
    alias tmr_a_freerun     : std_logic is acr(6);
    alias tmr_b_count_mode  : std_logic is acr(5);
    alias shift_dir         : std_logic is acr(4);
    alias shift_clk_sel     : std_logic_vector(1 downto 0)  is acr(3 downto 2);
    alias shift_mode_control     : std_logic_vector(2 downto 0)  is acr(4 downto 2);
    alias pb_latch_en       : std_logic is acr(1);
    alias pa_latch_en       : std_logic is acr(0);
    
    alias cb2_is_output     : std_logic is pcr(7);
    alias cb2_edge_select   : std_logic is pcr(6); -- for when CB2 is input
    alias cb2_no_irq_clr    : std_logic is pcr(5); -- for when CB2 is input
    alias cb2_out_mode      : std_logic_vector(1 downto 0) is pcr(6 downto 5);
    alias cb1_edge_select   : std_logic is pcr(4);
    
    alias ca2_is_output     : std_logic is pcr(3);
    alias ca2_edge_select   : std_logic is pcr(2); -- for when CA2 is input
    alias ca2_no_irq_clr    : std_logic is pcr(1); -- for when CA2 is input
    alias ca2_out_mode      : std_logic_vector(1 downto 0) is pcr(2 downto 1);
    alias ca1_edge_select   : std_logic is pcr(0);
    
    signal ira, irb         : std_logic_vector(7 downto 0) := (others => '0');

    signal write_t1c_l      : std_logic;
    signal write_t1c_h      : std_logic;
    signal write_t2c_h      : std_logic;

    signal ca1_c, ca2_c     : std_logic;
    signal cb1_c, cb2_c     : std_logic;
    signal ca1_d1, ca2_d1   : std_logic;
    signal cb1_d1, cb2_d1   : std_logic;
    signal ca1_d2, ca2_d2   : std_logic;
    signal cb1_d2, cb2_d2   : std_logic;
    
    signal ca2_handshake_o  : std_logic;
    signal ca2_pulse_o      : std_logic;
    signal cb2_handshake_o  : std_logic;
    signal cb2_pulse_o      : std_logic;
    signal shift_active     : std_logic;
begin
    irq <= irq_out;
    
	 -- TODO verify
    write_t1c_l <= '1' when (addr = X"4" or addr = x"6") and wen='1' else '0'; --and falling = '1' else '0';
    write_t1c_h <= '1' when addr = X"5" and wen='1' else '0'; --and falling = '1' else '0';
    write_t2c_h <= '1' when addr = X"9" and wen='1' else '0'; --and falling = '1' else '0';

    ca1_event <= (ca1_d1 xor ca1_d2) and (ca1_d2 xor ca1_edge_select);
    ca2_event <= (ca2_d1 xor ca2_d2) and (ca2_d2 xor ca2_edge_select);
    cb1_event <= (cb1_d1 xor cb1_d2) and (cb1_d2 xor cb1_edge_select);
    cb2_event <= (cb2_d1 xor cb2_d2) and (cb2_d2 xor cb2_edge_select);

    ca2_t <= ca2_is_output;
    cb2_t_int <= cb2_is_output when serport_en='0' else shift_dir;
    cb2_o_int <= hs_cb2_o      when serport_en='0' else ser_cb2_o;

    cb1_t <= cb1_t_int;
    cb1_o <= cb1_o_int;
    cb2_t <= cb2_t_int;
    cb2_o <= cb2_o_int;

    with ca2_out_mode select ca2_o <= 
        ca2_handshake_o when "00",
        ca2_pulse_o     when "01",
        '0'             when "10",
        '1'             when others;
        
    with cb2_out_mode select hs_cb2_o <= 
        cb2_handshake_o when "00",
        cb2_pulse_o     when "01",
        '0'             when "10",
        '1'             when others;

    process(irq_flags, irq_mask)
    begin
        if (irq_flags and irq_mask) = "0000000" then
            irq_out <= '0';
        else
            irq_out <= '1';
        end if;
    end process;


    process(phi2, ren, wen, irq_events, addr, pio_i, acr, irb, ira, 
				timer_a_out, timer_a_count, timer_a_latch, timer_b_count, 
				shift_reg, pcr, irq_out, irq_mask, irq_flags, irq_clr_strobe, reset)
    begin
			if (falling_edge(phi2)) then 
            if reset='1' then
                -- Reset avoids packing into shift register
                ca1_c  <= '1';
                ca2_c  <= '1';
                cb1_c  <= '1';
                cb2_c  <= '1';
                ca1_d1 <= '1';
                ca2_d1 <= '1';
                cb1_d1 <= '1';
                cb2_d1 <= '1';
                ca1_d2 <= '1';
                ca2_d2 <= '1';
                cb1_d2 <= '1';
                cb2_d2 <= '1';
				else
					-- CA1/CA2/CB1/CB2 edge detect flipflops
					ca1_c <= To_X01(ca1_i);
					ca2_c <= To_X01(ca2_i);
					cb1_c <= To_X01(cb1_i);
					cb2_c <= To_X01(cb2_i);

					ca1_d1 <= ca1_c;
					ca2_d1 <= ca2_c;
					cb1_d1 <= cb1_c;
					cb2_d1 <= cb2_c;

					ca1_d2 <= ca1_d1;
					ca2_d2 <= ca2_d1;
					cb1_d2 <= cb1_d1;
					cb2_d2 <= cb2_d1;

					-- input registers
					port_a_c <= port_a_i;
					port_b_c <= port_b_i;
				end if;
			end if;
			
			if (rising_edge(phi2)) then 
            -- input latch emulation
            if pa_latch_en = '0' or ca1_irq_flag = '0' then
                ira <= port_a_c;
            end if;
            
            if pb_latch_en = '0' or cb1_irq_flag = '0' then
                irb <= port_b_c;
            end if;            
			end if;

			if (rising_edge(phi2)) then 
				irq_events_d <= irq_events;
			end if;
			
          -- CA2 logic
			if (falling_edge(phi2)) then
            if ca1_i = ca1_edge_select then
                ca2_handshake_o <= '1';
            elsif (ren = '1' or wen = '1') and addr = X"1" then
                ca2_handshake_o <= '0';
            end if;
			end if;
			
			if (falling_edge(phi2)) then
            if (ren = '1' or wen = '1') and addr = X"1" then
                ca2_pulse_o <= '0';
            else            
                ca2_pulse_o <= '1';
            end if;
         end if;

            -- CB2 logic
			if (falling_edge(phi2)) then
            if cb1_i = cb1_edge_select then
                cb2_handshake_o <= '1';
            elsif (ren = '1' or wen = '1') and addr = X"0" then
                cb2_handshake_o <= '0';
            end if;
			end if;

			if (falling_edge(phi2)) then
            if (ren = '1' or wen = '1') and addr = X"0" then
                cb2_pulse_o <= '0';
            else            
                cb2_pulse_o <= '1';
            end if;
         end if;

			if (rising_edge(phi2)) then 
				if (reset = '1') then
					irq_flags <= (others => '0');
				else
					-- Interrupt logic
					irq_flags <= (irq_flags and not irq_clr_strobe) or irq_events;
				end if;
			end if;
			
			if (falling_edge(phi2)) then
            if reset='1' then
                pio_i         <= pio_default;
                irq_mask      <= (others => '0');
                acr           <= (others => '0');
                pcr           <= (others => '0');
                ca2_handshake_o <= '1';
                ca2_pulse_o     <= '1';
                cb2_handshake_o <= '1';
                cb2_pulse_o     <= '1';
                timer_a_latch  <= latch_reset_pattern;
                timer_b_latch  <= latch_reset_pattern;
					 
				elsif wen='1' then
            -- Writes --
                last_data <= data_in;
                case addr is
                when X"0" => -- ORB
                    pio_i.prb <= data_in;
                
                when X"1" => -- ORA
                    pio_i.pra <= data_in;
                    
                when X"2" => -- DDRB
                    pio_i.ddrb <= data_in;
                
                when X"3" => -- DDRA
                    pio_i.ddra <= data_in;
                    
                when X"4" => -- TA LO counter (write=latch)
                    timer_a_latch(7 downto 0) <= data_in;
                    
                when X"5" => -- TA HI counter
                    timer_a_latch(15 downto 8) <= data_in;
                    
                when X"6" => -- TA LO latch
                    timer_a_latch(7 downto 0) <= data_in;
                    
                when X"7" => -- TA HI latch
                    timer_a_latch(15 downto 8) <= data_in;
                    
                when X"8" => -- TB LO latch
                    timer_b_latch(7 downto 0) <= data_in;
                    
                when X"9" => -- TB HI counter
--                    timer_b_clr_strobe <= '1';
                
                when X"A" => -- Serial port
                    --serial_flag <= '0';
                    
                when X"B" => -- ACR (Auxiliary Control Register)
                    acr <= data_in;
                    
                when X"C" => -- PCR (Peripheral Control Register)
                    pcr <= data_in;
                                    
                when X"D" => -- IFR
--                    irq_clr_strobe <= data_in(6 downto 0);
                    
                when X"E" => -- IER
                    if data_in(7)='1' then -- set
                        irq_mask <= irq_mask or data_in(6 downto 0);
                    else -- clear
                        irq_mask <= irq_mask and not data_in(6 downto 0);
                    end if;
                
                when X"F" => -- ORA no handshake
                    pio_i.pra <= data_in;
                
                when others =>
                    null;
                end case;
            end if;
			end if;     
		 
            -- Reads - Output only --
				-- we do it async here
            data_out <= X"00";
            case addr is
            when X"0" => -- ORB
                --Port B reads its own output register for pins set to output.
                data_out <= (pio_i.prb and pio_i.ddrb) or (irb and not pio_i.ddrb);
                if tmr_a_output_en='1' then
                    data_out(7) <= timer_a_out;
                end if;
            when X"1" => -- ORA
                data_out <= ira;
            when X"2" => -- DDRB
                data_out <= pio_i.ddrb;
            when X"3" => -- DDRA
                data_out <= pio_i.ddra;
            when X"4" => -- TA LO counter
                data_out <= timer_a_count(7 downto 0);
            when X"5" => -- TA HI counter
                data_out <= timer_a_count(15 downto 8);
            when X"6" => -- TA LO latch
                data_out <= timer_a_latch(7 downto 0);
            when X"7" => -- TA HI latch
                data_out <= timer_a_latch(15 downto 8);
            when X"8" => -- TA LO counter
                data_out <= timer_b_count(7 downto 0);
            when X"9" => -- TA HI counter
                data_out <= timer_b_count(15 downto 8);
            when X"A" => -- SR
                data_out  <= shift_reg;
            when X"B" => -- ACR
                data_out  <= acr;
            when X"C" => -- PCR
                data_out  <= pcr;
            when X"D" => -- IFR
                data_out  <= irq_out & irq_flags;
            when X"E" => -- IER
                data_out  <= '0' & irq_mask;
            when X"F" => -- ORA
                data_out  <= ira;
            when others =>
                null;
            end case;
            
			if (falling_edge(phi2)) then
				ca1_clr_strobe <= '0';
				ca2_clr_strobe <= '0';
				cb1_clr_strobe <= '0';
				cb2_clr_strobe <= '0';
				timer_a_clr_strobe <= '0';
				timer_b_clr_strobe <= '0';
				serial_clr_strobe <= '0';
            -- Read/Write actions --
				if (ren = '1' or wen = '1') then
					case addr is
                when X"0" => -- ORB
                    if cb2_no_irq_clr='0' then
                        cb2_clr_strobe <= '1';
                    end if;
                    cb1_clr_strobe <= '1';
                                                
                when X"1" => -- ORA
                    if ca2_no_irq_clr='0' then
                        ca2_clr_strobe <= '1';
                    end if;
                    ca1_clr_strobe <= '1';
                    
                when X"4" => -- TA LO counter
                    if (ren = '1') then 
								timer_a_clr_strobe <= '1';
						  end if;

                when X"5" => -- TA HI counter
                    if (wen = '1') then 
								timer_a_clr_strobe <= '1';
						  end if;

                when X"7" => -- TA HI latch
						  if (wen = '1') then
								timer_a_clr_strobe <= '1';
						  end if;
                    
                when X"8" => -- TB LO counter
                    if (ren = '1') then 
								timer_b_clr_strobe <= '1';
						  end if;
                    
                when X"9" => -- TB HI counter
						  if (wen = '1') then
								timer_b_clr_strobe <= '1';
						  end if;
						  
                when X"A" => -- SR
                    serial_clr_strobe <= '1';
    
                when X"D" => -- IFR
						  if (wen = '1') then
								irq_clr_strobe <= data_in(6 downto 0);
						  end if;

                when others =>
                    null;
					end case;
				end if;
			end if;
    end process;

    -- PIO Out select --
    port_a_o             <= pio_i.pra;
    port_b_o(6 downto 0) <= pio_i.prb(6 downto 0);    
    port_b_o(7) <= pio_i.prb(7) when tmr_a_output_en='0' else timer_a_out;
    
    port_a_t             <= pio_i.ddra;
    port_b_t(6 downto 0) <= pio_i.ddrb(6 downto 0);
    port_b_t(7)          <= pio_i.ddrb(7) or tmr_a_output_en;
    

    -- Timer A
    tmr_a: block
        signal timer_a_reload        : std_logic;
        signal timer_a_toggle        : std_logic;
        signal timer_a_may_interrupt : std_logic;
    begin
        process(phi2, reset)
        begin
				-- note must be at falling edge, as write_t1c_l & data_in are directly coming from the CPU
				if (falling_edge(phi2)) then
                if reset='1' then
                    timer_a_toggle <= '1';
					 elsif write_t1c_h = '1' then
                    timer_a_toggle <= not tmr_a_output_en;
                elsif timer_a_event = '1' and tmr_a_output_en = '1' then
                    timer_a_toggle <= not timer_a_toggle;
                end if;

                -- always count, or load
                if reset='1' then
                    timer_a_may_interrupt <= '0';
                    timer_a_count  <= latch_reset_pattern;
                elsif write_t1c_h = '1' then
						  -- write t1 counter high
                    timer_a_may_interrupt <= '1';
                    timer_a_count  <= data_in & timer_a_latch(7 downto 0);
                elsif timer_a_reload = '1' then
                    timer_a_count  <= timer_a_latch;
						  -- are we writing to T1 counter low in exactly this moment?
                    if write_t1c_l = '1' then
                            timer_a_count(7 downto 0) <= data_in;
                    end if;
                    timer_a_may_interrupt <= timer_a_may_interrupt and tmr_a_freerun;
                else
                    --Timer coutinues to count in both free run and one shot.                        
                    timer_a_count <= timer_a_count - X"0001";
                end if;                    
            end if;
                
            if rising_edge(phi2) then
                if reset='1' then
                    timer_a_reload <= '0';
					 else
                    timer_a_reload <= '0';
						  timer_a_event <= '0';
                    if timer_a_count = X"0000" then
                        -- generate an event if we were triggered
                        timer_a_reload <= '1';
								
								if (timer_a_may_interrupt = '1') then 
									timer_a_event <= '1';
								end if;
                    end if;
					 end if;
            end if;
				
        end process;

        timer_a_out   <= timer_a_toggle;
		  
    end block tmr_a;
    
    -- Timer B
    tmr_b: block
        signal timer_b_oneshot_trig  : std_logic;
        signal timer_b_timeout       : std_logic;
        signal pb6_c, pb6_d          : std_logic;
		  signal timer_b_decrement		 : std_logic;
    begin
        process(phi2, write_t2c_h, timer_b_latch, data_in, reset)
        begin

            if (falling_edge(phi2)) then
                pb6_c <= To_X01(port_b_i(6));
                pb6_d <= pb6_c;
            end if;
                                
            if (rising_edge(phi2)) then
					 timer_b_decrement <= '0';
                timer_b_tick  <= '0';

                if tmr_b_count_mode = '1' then
                    if (pb6_d='1' and pb6_c='0') then
                         timer_b_decrement <= '1';
                    end if;
                else -- one shot or used for shift register
                    timer_b_decrement <= '1';
                end if;    
            end if;        
				
            if (falling_edge(phi2)) then
                timer_b_timeout <= '0';
                if timer_b_decrement = '1' then
                    if timer_b_count = X"0000" then
                         if timer_b_oneshot_trig = '1' then
                            timer_b_oneshot_trig <= '0';
                            timer_b_timeout <= '1';
                        end if;
                    end if;
						  if ((shift_mode_control = "001" 
								or shift_mode_control = "101"
								or shift_mode_control = "100")
								and (timer_b_count(7 downto 0) = X"00")) then
									timer_b_tick <= '1';
									timer_b_count(7 downto 0) <= timer_b_latch(7 downto 0);
							else
								timer_b_count <= timer_b_count - X"0001";
							end if;
                end if;

					-- write to T2 counter is on falling phi2
                if write_t2c_h = '1' then
                    timer_b_count <= data_in & timer_b_latch(7 downto 0);
                    timer_b_oneshot_trig <= '1';
                end if;

                if reset='1' then
                    timer_b_count  <= latch_reset_pattern;
                    timer_b_oneshot_trig <= '0';                    
                end if;
            end if;
        end process;

 		  timer_b_event <= timer_b_timeout;

    end block tmr_b;
    
    ser: block
        signal trigger_serial: std_logic;
        signal shift_clock_d : std_logic;
        signal shift_clock   : std_logic;
        signal shift_tick_r  : std_logic;
        signal shift_tick_f  : std_logic;
        signal shift_timer_tick : std_logic;
        signal bit_cnt       : integer range 0 to 7;
        signal shift_pulse   : std_logic;
    begin
        process(shift_active, timer_b_tick, shift_clk_sel, shift_clock, shift_clock_d, shift_timer_tick)
        begin
            case shift_clk_sel is
            when "10" =>
                shift_pulse <= '1';
                
            when "00"|"01" =>
                shift_pulse <= shift_timer_tick;
            
            when others =>
                shift_pulse <= shift_clock and not shift_clock_d;
            end case;

            if shift_active = '0' then
                -- Mode 0 still loads the shift register to external pulse (MMBEEB SD-Card interface uses this)
                if shift_mode_control = "000" then
                    shift_pulse <= shift_clock and not shift_clock_d;
                else
                    shift_pulse <= '0';
                end if;
            end if;

        end process;


        process(phi2, reset)
        begin
					 if (rising_edge(phi2)) then
					  
                    if shift_active='0' then
                        if shift_mode_control = "000" then
                            shift_clock <= cb1_d1;
                        else
                            shift_clock <= '1';
                        end if;
                    elsif shift_clk_sel = "11" then
                        shift_clock <= cb1_d1;
                    elsif shift_pulse = '1' then
                        shift_clock <= not shift_clock;
                    end if;

                    shift_clock_d <= shift_clock;

                end if;

                if (falling_edge(phi2)) then
                    shift_timer_tick <= timer_b_tick;
                end if;

                if reset = '1' then
                    shift_clock <= '1';
                    shift_clock_d <= '1';
                end if;
        end process;

        cb1_t_int <= '0' when shift_clk_sel="11" else serport_en;
        cb1_o_int <= shift_clock_d;
        ser_cb2_o <= shift_reg(7);

        serport_en <= shift_dir or shift_clk_sel(1) or shift_clk_sel(0);
        trigger_serial <= '1' when (ren='1' or wen='1') and addr=x"A" else '0';
        shift_tick_r <= not shift_clock_d and shift_clock;
        shift_tick_f <= shift_clock_d and not shift_clock;

		  -- writing to the shift register (Reg 10)
        process(phi2, reset)
        begin
            if (falling_edge(phi2)) then
                if reset = '1' then
                    shift_reg <= X"FF";
                else
                    if wen = '1' and addr = X"A" then
                        shift_reg <= data_in;
                    elsif shift_dir='1' and shift_tick_f = '1' then -- output
                        shift_reg <= shift_reg(6 downto 0) & shift_reg(7);
                    elsif shift_dir='0' and shift_tick_r = '1' then -- input
                        shift_reg <= shift_reg(6 downto 0) & cb2_d1;
                    end if;
                end if;
            end if;
        end process;        

		  s_ev: process(phi2)
		  begin
				if (rising_edge(phi2)) then
					serial_event <= '0';
					if (shift_tick_r = '1' and shift_active = '0' and serport_en = '1') then
						serial_event <= '1';
					end if;
				end if;
        end process;

        process(phi2, reset)
        begin
            if (falling_edge(phi2)) then
                if reset='1' then
                    shift_active <= '0';
                    bit_cnt      <= 0;
                else
                    if shift_active = '0' and shift_mode_control /= "000" then
								-- accessing shift register
                        if trigger_serial = '1' then
                            bit_cnt      <= 7;
                            shift_active <= '1';
                        end if;
                    else -- we're active
                        if shift_clk_sel = "00" then
                            shift_active <= shift_dir; -- when '1' we're active, but for mode 000 we go inactive.
                        elsif shift_pulse = '1' and shift_clock = '1' then
                            if bit_cnt = 0 then
                                shift_active <= '0';
                            else
                                bit_cnt <= bit_cnt - 1;
                            end if;
                        end if;                            
                    end if;
                end if;
            end if;
        end process;                
    end block ser;
end Gideon;

