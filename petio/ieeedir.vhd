----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:47:22 03/23/2026 
-- Design Name: 
-- Module Name:    ieeedir - Behavioral 
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

-- This module listens on the IEEE488 bus and determines the general direction
-- of data transfer, to control the 7516x chips connected to the  bidirectional
-- IEEE488 signal lines.
entity ieeedir is
    Port ( 
           phi2 : in  STD_LOGIC;
           nres : in  STD_LOGIC;
			  dio_in : in  STD_LOGIC_VECTOR (7 downto 0);
           atn_in : in  STD_LOGIC;
           dav_in : in  STD_LOGIC;
           nrfd_in : in  STD_LOGIC;
			  is_out : out STD_LOGIC
	 );
end ieeedir;

architecture Behavioral of ieeedir is

	type t_state is (
		S_IDLE,		-- IEEE488 idle
		S_ATN,		-- ATN low detected
		S_ATN_WAIT,	-- received a low NRFD as indication of a connected drive, now waiting for DAV low
		S_ATN_HOLD,	-- DAV is low, data is clocked into hold, and evaluated when DAV goes high, waiting for DAV hi
		S_TALK,		-- talk mode, sending to bus
		S_LISTEN		-- listen mode, receiving from bus
		);
		
	signal hold: std_logic_vector(7 downto 0);
	signal state: t_state;
	signal target: t_state;
	
begin

	p: process(phi2, nres, state)
	begin
		if (nres = '0') then
			state <= S_IDLE;
			target <= S_IDLE;
		elsif (rising_edge(phi2)) then
			
			case (state) is
			when S_IDLE =>
				if (atn_in = '0') then
					state <= S_ATN;
				end if;
			when S_ATN =>
				if (atn_in = '1') then
					state <= target;
				elsif (nrfd_in = '0') then
					state <= S_ATN_WAIT;
				end if;
			when S_ATN_WAIT =>
				if (atn_in = '1') then
					state <= target;
				elsif (dav_in = '0') then
					state <= S_ATN_HOLD;
					hold <= dio_in;
				end if;
			when S_ATN_HOLD =>
				if (atn_in = '1') then
					state <= target;
				else
					if (hold(7 downto 5) = "001") then
						if (hold(4 downto 0) = "11111") then
							target <= S_IDLE;
						else
							target <= S_LISTEN;
						end if;
					elsif (hold(7 downto 5) = "010") then
						if (hold(4 downto 0) = "11111") then
							target <= S_IDLE;
						else
							target <= S_TALK;
						end if;
					end if;
					if (dav_in = '1') then
						state <= S_ATN_WAIT;
					end if;
				end if;
			when others =>
				if (atn_in = '0') then
					state <= S_ATN;
				end if;
			end case;
			
		end if;
		
		case (state) is
		when S_IDLE => is_out <= '0';
		when S_LISTEN => is_out <= '0';
		when others => is_out <= '1';
		end case;
		
	end process;	
	
	
end Behavioral;

