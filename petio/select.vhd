----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:45:33 01/31/2026 
-- Design Name: 
-- Module Name:    select - Behavioral 
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

entity ioselect is
    Port ( A : in  STD_LOGIC_VECTOR (11 downto 0);
           niosel : in  STD_LOGIC;
			  iopage : in STD_LOGIC;
			  nres : in STD_LOGIC;
			  nbe : out std_logic;
           pia1 : out  STD_LOGIC;
           pia2 : out  STD_LOGIC;
           via1 : out  STD_LOGIC;
           via2 : out  STD_LOGIC;
           uart1 : out  STD_LOGIC;
           uart2 : out  STD_LOGIC);
end ioselect;

architecture Behavioral of ioselect is

	--signal is_io: std_logic;
	
begin

	is_io_p: process(A, niosel, iopage, nres)
	begin

		nbe <= '1';
		
		pia1 <= '0';
		pia2 <= '0';
		via1 <= '0';
		via2 <= '0';
		uart1	<= '0';
		uart2 <= '0';

		-- check reset, iosel
		if (nres = '1' and niosel = '0') then
			-- check IO page
			-- for testing use X900 for now
			-- will be replaced with X800
			if (A(11 downto 9) = "100"
					and A(8) = iopage) then
				-- select
				case A(7 downto 3) is
				when "00010" =>
					pia1 <= '1';
					nbe <= '0';
				when "00011" =>
					if (A(2) = '0') then
						uart1 <= '1';
						nbe <= '0';
					end if;
				when "00100" =>
					pia2 <= '1';
					nbe <= '0';
				when "00101" =>
					if (A(2) = '0') then
						uart2 <= '1';
						nbe <= '0';
					end if;
				when "01000" =>
					via1 <= '1';
					nbe <= '0';
				when "01001" =>
					via1 <= '1';
					nbe <= '0';
				when "01010" =>
					via2 <= '1';
					nbe <= '0';
				when "01011" =>
					via2 <= '1';
					nbe <= '0';
				when others =>
				end case;
			end if;
		end if;
	end process;
			
end Behavioral;

