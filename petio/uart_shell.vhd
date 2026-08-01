----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:45:16 04/10/2026 
-- Design Name: 
-- Module Name:    uart_shell - Behavioral 
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

entity uart_shell is
    Port ( phi2 : in  STD_LOGIC;
           rwb : in  STD_LOGIC;
           nres : in  STD_LOGIC;
			  sel : in STD_LOGIC;
           addr : in  STD_LOGIC_VECTOR (2 downto 0);
           din : in  STD_LOGIC_VECTOR (7 downto 0);
           dout : out  STD_LOGIC_VECTOR (7 downto 0);
           irq : out  STD_LOGIC;
           rx : in  STD_LOGIC;
           tx : out  STD_LOGIC;
           cts : in  STD_LOGIC;
           rts : out  STD_LOGIC;
           dsr : in  STD_LOGIC;
           dtr : out  STD_LOGIC;
           ri : in  STD_LOGIC;
           dcd : in  STD_LOGIC);
end uart_shell;

architecture Behavioral of uart_shell is

	component uart_top is 
		Port (
			wb_clk_i : in std_logic;
	
			-- Wishbone signals
			wb_rst_i : in std_logic;
			wb_adr_i : in std_logic_vector(2 downto 0);
			wb_dat_i : in std_logic_vector(7 downto 0);
			wb_dat_o : out std_logic_vector(7 downto 0); 
			wb_we_i  : in std_logic;
			wb_stb_i : in std_logic; 
			wb_cyc_i : in std_logic; 
			
			-- interrupt request
			int_o		: out std_logic; 

			-- UART	signals
			-- serial input/output
			stx_pad_o : out std_logic; 
			srx_pad_i : in std_logic;
			
			-- modem signals
			rts_pad_o : out std_logic; 
			cts_pad_i : in std_logic;
			dtr_pad_o : out std_logic; 
			dsr_pad_i : in std_logic;
			ri_pad_i	 : in std_logic; 
			dcd_pad_i : in std_logic
		);
	end component;

		signal we: std_logic;
		signal stb: std_logic;
		signal cyc: std_logic;
		
begin

	uart_c: uart_top
		port map (
			phi2,			-- TODO 1.8432 MHz
			not(nres),
			addr,
			din,
			dout,
			we,
			stb,
			cyc,
			irq,
			tx,
			rx,
			rts,
			cts,
			dtr,
			dsr,
			ri,
			dcd
		);

	cyc <= phi2;
	we <= not(rwb);
	stb <= sel;
	
end Behavioral;

