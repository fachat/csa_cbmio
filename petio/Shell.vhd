----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    22:18:53 01/30/2026 
-- Design Name: 
-- Module Name:    Shell - Behavioral 
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

entity Shell is
	Port (
		phi2: in std_logic;
		rwb: in std_logic;
		niosel: in std_logic;
		nres: in std_logic;
		A: in std_logic_vector(11 downto 0);
		D: inout std_logic_vector(7 downto 0);
				
		irq: out std_logic;
		nbe: out std_logic;
		
		-- SPI (5V)
		spiiosel: out std_logic;
		spimosi: out std_logic;
		spimiso: in std_logic;
		spiclk: out std_logic;
		
		-- "left" rs232
		lcts: in std_logic;
		lrts: out std_logic;
		lrx: in std_logic;
		ltx: out std_logic;
		ldsr: in std_logic;
		ldtr: out std_logic;
		ldcd: in std_logic;
		lri: in std_logic;
		
		-- "right" rs232
		rcts: in std_logic;
		rrts: out std_logic;
		rrx: in std_logic;
		rtx: out std_logic;
		rdsr: in std_logic;
		rdtr: out std_logic;
		--rdcd: in std_logic;
		--rri: in std_logic;
		
		-- cassette interface
		c1sw: in std_logic;
		cwr: out std_logic;
		c1rd: in std_logic;
		c1mtr: out std_logic;
		
		-- userport
		up: inout std_logic_vector(13 downto 0);
		
		-- serial IEC
		datain: in std_logic;
		clkin: in std_logic;
		atnin: in std_logic;
		srqin: in std_logic;
		dataout: out std_logic;
		clkout: out std_logic;
		atnout: out std_logic;
		srqout: out std_logic;
		
		-- keyboard
		ksel: out std_logic_vector(3 downto 0);
		kin: in std_logic_vector(7 downto 0);
		
		-- IEEE488
		dio: inout std_logic_vector(7 downto 0);
		ren: inout std_logic;
		ifc: inout std_logic;
		ndac: inout std_logic;
		nrfd: inout std_logic;
		dav: inout std_logic;
		eoi: inout std_logic;
		atn: inout std_logic;
		srq: inout std_logic;
		te: out std_logic;
		dc: out std_logic
	);
end Shell;

architecture Behavioral of Shell is

begin

	-- for now decouple bus
	nbe <= '1';
	irq <= '0';
	D(7 downto 0) <= (others => 'X');

	ksel(3 downto 0) <= (others => 'X');
	up(13 downto 0) <= (others => 'X');
	
	spimosi <= '1';
	spiclk <= '1';
	spiiosel <= '1';
	
	cwr <= 'X';
	c1mtr <= 'X';
	
	dataout <= 'X';
	clkout <= 'X';
	atnout <= 'X';
	srqout <= 'X';
	
	ltx <= 'X';
	lrts <= 'X';
	ldtr <= 'X';

	rtx <= 'X';
	rrts <= 'X';
	rdtr <= 'X';
	
	dc <= '1';
	te <= '1';
	dio(7 downto 0) <= (others => 'X');
	
end Behavioral;

