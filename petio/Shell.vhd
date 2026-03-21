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
use IEEE.STD_LOGIC_unsigned.ALL;
use ieee.numeric_std.all;

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

	signal D_in: std_logic_vector(7 downto 0);
	signal D_out: std_logic_vector(7 downto 0);
	
	signal sel_via1: std_logic;
	signal sel_via2: std_logic;
	signal sel_uart1: std_logic;
	signal sel_uart2: std_logic;
	
	component ioselect is
    Port ( A : in  STD_LOGIC_VECTOR (11 downto 0);
           niosel : in  STD_LOGIC;
			  nres : in STD_LOGIC;
			  nbe : out std_logic;
           pia1 : out  STD_LOGIC;
           pia2 : out  STD_LOGIC;
           via1 : out  STD_LOGIC;
           via2 : out  STD_LOGIC;
           uart1 : out  STD_LOGIC;
           uart2 : out  STD_LOGIC);	
	end component;

	signal pia1_sel: std_logic;
	signal pia1_irq: std_logic;
	signal pia1_din: std_logic_vector(7 downto 0);
	signal pia1_dout: std_logic_vector(7 downto 0);
	signal pia1_pa_in: std_logic_vector(7 downto 0);
	signal pia1_pa_out: std_logic_vector(7 downto 0);
	signal pia1_ca1_in: std_logic;
	signal pia1_ca2_in: std_logic;
	signal pia1_ca2_out: std_logic;
	signal pia1_pb_in: std_logic_vector(7 downto 0);
	signal pia1_pb_out: std_logic_vector(7 downto 0);
	signal pia1_cb1_in: std_logic;
	signal pia1_cb2_in: std_logic;
	signal pia1_cb2_out: std_logic;

	signal pia2_sel: std_logic;
	signal pia2_irq: std_logic;
	signal pia2_din: std_logic_vector(7 downto 0);
	signal pia2_dout: std_logic_vector(7 downto 0);
	signal pia2_pa_in: std_logic_vector(7 downto 0);
	signal pia2_pa_out: std_logic_vector(7 downto 0);
	signal pia2_ca1_in: std_logic;
	signal pia2_ca2_in: std_logic;
	signal pia2_ca2_out: std_logic;
	signal pia2_pb_in: std_logic_vector(7 downto 0);
	signal pia2_pb_out: std_logic_vector(7 downto 0);
	signal pia2_cb1_in: std_logic;
	signal pia2_cb2_in: std_logic;
	signal pia2_cb2_out: std_logic;
	
	component pia6520 is
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
	end component;

	component via6522 is
		port (
			clock       : in  std_logic;
			rising      : in  std_logic;
			falling     : in  std_logic;
			reset       : in  std_logic;
    
			addr        : in  std_logic_vector(3 downto 0);
			wen         : in  std_logic;
			ren         : in  std_logic;
			data_in     : in  std_logic_vector(7 downto 0);
			data_out    : out std_logic_vector(7 downto 0);

			phi2_ref    : out std_logic;

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
	end component;
	
	-- test timer (50Hz)
	signal test_counter: std_logic_vector(15 downto 0);
	
begin

	test_p: process(phi2, test_counter) 
	begin
		if (falling_edge(phi2)) then
			test_counter <= test_counter + 1;
		end if;
	end process;
	rtx <= test_counter(11);
	
	-- for now decouple bus
	irq <= '0'; --pia1_irq;
	
	D_in <= D;
	D <= (others => 'X') when rwb = '0'
			else D_out;
	
	D_out(7 downto 0) <= 
				pia1_dout when pia1_sel = '1'
			else pia2_dout when pia2_sel = '1'
	--		else via1_dout when via1_sel = '1'
			else "XXXXXXXX";	-- test pattern, will be open

	-- I/O
	
	-- userport
	up(13 downto 0) <= (others => 'X');

	-- SPI (5V)
	spimosi <= '1';
	spiclk <= '1';
	spiiosel <= '1';
	
	-- cassette
	cwr <= 'X';
	c1mtr <= 'X';

	-- serial IEC
	dataout <= 'X';
	clkout <= 'X';
	atnout <= 'X';
	srqout <= 'X';
	
	-- rs232
	ltx <= 'X';
	lrts <= 'X';
	ldtr <= 'X';

	--rtx <= '1'; --pia2_sel; --'X';
	rrts <= 'X';
	rdtr <= 'X';

	-- IEEE488
	dc <= '1';
	te <= '1';
	dio(7 downto 0) <= (others => 'X');

	ren <= 'X';
	ifc <= 'X';
	ndac <= 'X';
	nrfd <= 'X';
	dav <= 'X';
	eoi <= 'X';
	atn <= 'X';
	srq <= 'X';

	----------------------------------------------------
	
	pia1_c: pia6520
	   Port map (
			nres,
         phi2,
         rwb,
         pia1_sel,
         pia1_irq,
			A(1 downto 0),
         pia1_din,
			pia1_dout,

			pia1_pa_in,
			pia1_pa_out,			
         pia1_ca1_in,
         pia1_ca2_in,
         pia1_ca2_out,

			pia1_pb_in,
			pia1_pb_out,			
         pia1_cb1_in,
         pia1_cb2_in,
         pia1_cb2_out
		);

	pia1_din <= D_in;
	
	ksel <= pia1_pa_out(3 downto 0);
	pia1_pb_in <= kin;
	
	pia1_pa_in(7) <= up(10);
	pia1_pa_in(6) <= eoi;
	pia1_pa_in(5) <= '1';	-- cass#2 switch
	pia1_pa_in(4) <= c1sw;	-- cass#1 switch
	pia1_pa_in(3 downto 0) <= pia1_pa_out(3 downto 0);
	
	pia1_ca1_in <= c1rd;		-- cass#1 read
	pia1_ca2_in <= 'X';		-- eoi out

	pia1_cb1_in <= up(13);	-- vdrive
	pia1_cb2_in <= 'X';		-- cwr out
	
	----------------------------------------------------

	pia2_c: pia6520
	   Port map (
			nres,
         phi2,
         rwb,
         pia2_sel,
         pia2_irq,
			A(1 downto 0),
         pia2_din,
			pia2_dout,

			pia2_pa_in,
			pia2_pa_out,			
         pia2_ca1_in,
         pia2_ca2_in,
         pia2_ca2_out,

			pia2_pb_in,
			pia2_pb_out,			
         pia2_cb1_in,
         pia2_cb2_in,
         pia2_cb2_out
		);

	pia2_din <= D_in;
	
	pia2_pa_in <= dio;		-- dio out
	pia2_pb_in <= dio;

	pia2_ca1_in <= atn;
	pia2_ca2_in <= 'X';		-- ndac out
	
	pia2_cb1_in <= srq;
	pia2_cb2_in <= 'X';		-- dav out
	
	----------------------------------------------------

--	via1_c: pia6520
--	   Port map (
--			nres,
--         phi2,
--         rwb,
--         pia2_sel,
--         pia2_irq,
--			A(1 downto 0),
--         pia2_din,
--			pia2_dout,
--
--			pia2_pa_in,
--			pia2_pa_out,			
--         pia2_ca1_in,
--         pia2_ca2_in,
--         pia2_ca2_out,
--
--			pia2_pb_in,
--			pia2_pb_out,			
--         pia2_cb1_in,
--         pia2_cb2_in,
--         pia2_cb2_out
--		);
--
--	pia2_din <= D;
	----------------------------------------------------

	
	-- IO select
	select_c: ioselect
	port map(
		A,
		niosel,
		nres,
		nbe,
		pia1_sel,
		pia2_sel,
		sel_via1,
		sel_via2,
		sel_uart1,
		sel_uart2
	);
	
end Behavioral;

