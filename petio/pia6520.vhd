----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    18:13:26 01/31/2026 
-- Design Name: 
-- Module Name:    pia6520 - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity pia6520 is
    Port ( nres : in  STD_LOGIC;
           phi2 : in  STD_LOGIC;
           rwb : in  STD_LOGIC;
           sel : in  STD_LOGIC;
           irq : out  STD_LOGIC;
			  addr : in STD_LOGIC_VECTOR(1 downto 0);
           data_in : in  STD_LOGIC_VECTOR (7 downto 0);
           data_out : out  STD_LOGIC_VECTOR (7 downto 0);

           porta_in : in  STD_LOGIC_VECTOR (7 downto 0);
           porta_out : out  STD_LOGIC_VECTOR (7 downto 0);
           ca1_in : in  STD_LOGIC;
           ca2_in : in  STD_LOGIC;
           ca2_out : out  STD_LOGIC;
			  
           portb_in : in  STD_LOGIC_VECTOR (7 downto 0);
           portb_out : out  STD_LOGIC_VECTOR (7 downto 0);
           cb1_in : in  STD_LOGIC;
           cb2_in : in  STD_LOGIC;
           cb2_out : out  STD_LOGIC);
end pia6520;

architecture Behavioral of pia6520 is

	constant REG_PORTA: std_logic_vector(1 downto 0):= "00";
	constant REG_CRA 	: std_logic_vector(1 downto 0):= "01";
	constant REG_PORTB: std_logic_vector(1 downto 0):= "10";
	constant REG_CRB	: std_logic_vector(1 downto 0):= "11";

	signal porta_a: std_logic;
	signal portb_a: std_logic;
	signal ddra_a: std_logic;
	signal ddrb_a: std_logic;
	signal cra_a: std_logic;
	signal crb_a: std_logic;
	
	signal porta: std_logic_vector(7 downto 0);
	signal ddra: std_logic_vector(7 downto 0);
	signal cra: std_logic_vector(5 downto 0);
	signal irqa1: std_logic;
	signal irqa2: std_logic;
	signal ca1_in_d: std_logic;	-- for edge detection
	signal ca2_in_d: std_logic;	-- for edge detection
	signal ca1_act_trans: std_logic;
	signal ca2_act_trans: std_logic;
	signal ca2_pulse: std_logic;
	
	signal portb: std_logic_vector(7 downto 0);
	signal ddrb: std_logic_vector(7 downto 0);
	signal crb: std_logic_vector(5 downto 0);
	signal irqb1: std_logic;
	signal irqb2: std_logic;
	signal cb1_in_d: std_logic;	-- for edge detection
	signal cb2_in_d: std_logic;	-- for edge detection
	signal cb1_act_trans: std_logic;
	signal cb2_act_trans: std_logic;
	signal cb2_pulse: std_logic;
	
begin

	porta_a <= '1' when sel = '1' and addr = REG_PORTA and cra(2) = '1';
	portb_a <= '1' when sel = '1' and addr = REG_PORTB and crb(2) = '1';
	ddra_a <= '1' when sel = '1' and addr = REG_PORTA and cra(2) = '0';
	ddrb_a <= '1' when sel = '1' and addr = REG_PORTB and crb(2) = '0';
	cra_a <= '1' when sel = '1' and addr = REG_CRA;
	crb_a <= '1' when sel = '1' and addr = REG_CRB;
	
	-- write CRA
	cra_p: process(nres, phi2, sel)
	begin	
		if (nres = '0') then
			cra <= "000000";
		elsif (falling_edge(phi2) and rwb = '0' and cra_a = '1') then
			cra <= data_in(5 downto 0);
		end if;
	end process;
	
	-- write Port A
	pa_p: process(nres, phi2, sel)
	begin
		if (nres = '0') then
			porta <= "00000000";
		elsif (falling_edge(phi2) and rwb = '0' and porta_a = '1') then
			porta <= data_in;
		end if;
	end process;

	-- write DDRA
	ddra_p: process(nres, phi2, sel)
	begin
		if (nres = '0') then
			ddra <= "00000000";
		elsif (falling_edge(phi2) and rwb = '0' and ddra_a = '1') then
			ddra <= data_in;
		end if;
	end process;

	-- write CRB
	crb_p: process(nres, phi2, sel)
	begin
		if (nres = '0') then
			crb <= "000000";
		elsif (falling_edge(phi2) and rwb = '0' and crb_a = '1') then
			crb <= data_in(5 downto 0);
		end if;
	end process;

	-- write Port B
	pb_p: process(nres, phi2, sel)
	begin
	
		if (nres = '0') then
			portb <= "00000000";
		elsif (falling_edge(phi2) and rwb = '0' and portb_a = '1') then
			portb <= data_in;
		end if;
	end process;

	-- write DDRB
	ddrb_p: process(nres, phi2, sel)
	begin
		if (nres = '0') then
			ddrb <= "00000000";
		elsif (falling_edge(phi2) and rwb = '0' and ddrb_a = '1') then
			ddrb <= data_in;
		end if;
	end process;

	-----------------------------------------------------
	-- IRQ A
	
	-- edge detection A
	edge_a_p: process(phi2, ca1_in, ca1_in)
	begin
		if (falling_edge(phi2)) then
			ca1_in_d <= ca1_in;
			ca2_in_d <= ca2_in;
		end if;
	end process;
	
	-- detect active transition
	edge2_a_p: process(phi2, cra, ca1_in, ca1_in_d, ca2_in, ca2_in_d)
	begin 
		if (rising_edge(phi2)) then
			ca1_act_trans <= '0';
			if (cra(1) = '0') then
				if (ca1_in = '0' and ca1_in_d = '1') then
					ca1_act_trans <= '1';
				end if;
			else
				if (ca1_in = '1' and ca1_in_d = '0') then
					ca1_act_trans <= '1';
				end if;
			end if;
			ca2_act_trans <= '0';
			if (cra(4) = '0') then
				if (ca2_in = '0' and ca2_in_d = '1') then
					ca2_act_trans <= '1';
				end if;
			else
				if (ca2_in = '1' and ca2_in_d = '0') then
					ca2_act_trans <= '1';
				end if;
			end if;
		end if;
	end process;
	
	irqa1_p: process(nres, phi2, ca1_act_trans, cb1_act_trans)
	begin
		if (nres = '0') then
			irqa1 <= '0';
			irqa2 <= '0';
		elsif (falling_edge(phi2)) then
			if (ca1_act_trans = '1' and cra(0) = '1') then
				-- set on active transition and enabled in cra(0)
				irqa1 <= '1';
			elsif(rwb = '1' and porta_a = '1') then
				-- clear on read Port A	
				irqa1 <= '0';
			end if;
			if (ca2_act_trans = '1' and cra(3) = '1' and cra(5) = '0') then
				-- set on active transition and enabled in cra(3) and CA2 is input (cra(5))
				irqa2 <= '1';
			elsif(rwb = '1' and porta_a = '1') then
				-- clear on read Port A
				irqa2 <= '0';
			end if;
		end if;
	end process;
	
	-----------------------------------------------------
	-- IRQ B
	
	-- edge detection A
	edge_b_p: process(phi2, cb1_in, cb2_in)
	begin
		if (falling_edge(phi2)) then
			cb1_in_d <= cb1_in;
			cb2_in_d <= cb2_in;
		end if;
	end process;
	
	-- detect active transition
	edge2_b_p: process(phi2, crb, cb1_in, cb1_in_d, cb2_in, cb2_in_d)
	begin 
		if (rising_edge(phi2)) then
			cb1_act_trans <= '0';
			if (crb(1) = '0') then
				if (cb1_in = '0' and cb1_in_d = '1') then
					cb1_act_trans <= '1';
				end if;
			else
				if (cb1_in = '1' and cb1_in_d = '0') then
					cb1_act_trans <= '1';
				end if;
			end if;
			cb2_act_trans <= '0';
			if (crb(4) = '0') then
				if (cb2_in = '0' and cb2_in_d = '1') then
					cb2_act_trans <= '1';
				end if;
			else
				if (cb2_in = '1' and cb2_in_d = '0') then
					cb2_act_trans <= '1';
				end if;
			end if;
		end if;
	end process;
	
	irqb1_p: process(nres, phi2, cb1_act_trans)
	begin
		if (nres = '0') then
			irqb1 <= '0';
			irqb2 <= '0';
		elsif (falling_edge(phi2)) then
			if (cb1_act_trans = '1') then
				-- set on active transition
				irqb1 <= '1';
			elsif(rwb = '1' and portb_a = '1') then
				-- clear on read Port B
				irqb1 <= '0';
			end if;
			if (cb2_act_trans = '1' and crb(5) = '0') then
				-- set on active transition and and CB2 is input (crb(5))
				irqb2 <= '1';
			elsif(rwb = '1' and portb_a = '1') then
				-- clear on read Port B
				irqb2 <= '0';
			end if;
		end if;
	end process;
	
	-----------------------------------------------------
	-- interrupt
	
	irq <= (irqa1 and cra(0)) 
			or (irqa2 and cra(3))
			or (irqb1 and crb(0))
			or (irqb2 and crb(3));

	-----------------------------------------------------
	-- ca2/cb2 output
	
	ca2_p: process(phi2, cra, ca1_act_trans)
	begin
		if (falling_edge(phi2)) then
			-- ca2 pulse/handshake mode
			if (cra(5) = '0' or cra(4) = '1') then
				ca2_pulse <= '1';
			elsif (rwb = '1' and porta_a = '1') then
				-- set to 0 when port A is being read
				ca2_pulse <= '0';
			else
				if (cra(3) = '1') then
					-- in pulse mode, immediately return to high
					ca2_pulse <= '1';
				else
					-- in handshake mode, only return high on active ca1 transition
					if (ca1_act_trans = '1') then
						ca2_pulse <= '1';
					end if;
				end if;
			end if;
		end if;

		-- actual output
		case (cra(5 downto 4)) is
		when "10" =>
			ca2_out <= ca2_pulse;
		when "11" =>
			ca2_out <= cra(3);
		when others =>
			ca2_out <= '1';
		end case;
	end process;

	cb2_p: process(phi2, crb, cb1_act_trans)
	begin
		if (falling_edge(phi2)) then
			-- cb2 pulse/handshake mode
			if (crb(5) = '0' or crb(4) = '1') then
				cb2_pulse <= '1';
			elsif (rwb = '0' and portb_a = '1') then
				-- set to 0 when port B is written to
				cb2_pulse <= '0';
			else
				if (crb(3) = '1') then
					-- in pulse mode, immediately return to high
					cb2_pulse <= '1';
				else
					-- in handshake mode, only return high on active ca1 transition
					if (cb1_act_trans = '1') then
						cb2_pulse <= '1';
					end if;
				end if;
			end if;
		end if;

		-- actual output
		case (crb(5 downto 4)) is
		when "10" =>
			cb2_out <= cb2_pulse;
		when "11" =>
			cb2_out <= crb(3);
		when others =>
			cb2_out <= '1';
		end case;
	end process;

	-----------------------------------------------------

	dout_p: process(addr)
	begin
		case (addr) is
		when REG_PORTA =>
			if (cra(2) = '1') then
				data_out <= (porta and ddra) or (porta_in and not(ddra));
			else
				data_out <= ddra;
			end if;
		when REG_CRA =>
			data_out(5 downto 0) <= cra;
			data_out(6) <= irqa2;
			data_out(7) <= irqa1;
		when REG_PORTB =>
			if (crb(2) = '1') then
				data_out <= (portb and ddrb) or (portb_in and not(ddrb));
			else
				data_out <= ddrb;
			end if;
		when REG_CRB =>
			data_out(5 downto 0) <= crb;
			data_out(6) <= irqb2;
			data_out(7) <= irqb1;
		when others =>
			data_out <= (others => '1');
		end case;
	end process;
	
end Behavioral;

