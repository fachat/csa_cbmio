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
	
	-- select signals (temporary until all units are implemented)
	signal sel_via1: std_logic;
	signal sel_via2: std_logic;
	signal sel_uart1: std_logic;
	signal sel_uart2: std_logic;
	
	signal nbe_out: std_logic;
	signal res: std_logic;
	
	-- IEEE488 signals output from PET (depends on direction)
	signal ieee_is_out: std_logic;	-- 1 when sending from host (us) to device (on bus)
	signal ndac_out: std_logic;
	signal nrfd_out: std_logic;
	signal dav_out: std_logic;
	signal atn_out: std_logic;
	signal srq_out: std_logic;
	signal eoi_out: std_logic;
	signal dio_out: std_logic_vector(7 downto 0);
		
	-- components and related signals
	
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

	signal via1_sel: std_logic;
	signal via1_irq: std_logic;
	signal via1_wren: std_logic;
	signal via1_rden: std_logic;
	signal via1_din: std_logic_vector(7 downto 0);
	signal via1_dout: std_logic_vector(7 downto 0);
	signal via1_pa_in: std_logic_vector(7 downto 0);
	signal via1_pa_out: std_logic_vector(7 downto 0);
	signal via1_pa_dir: std_logic_vector(7 downto 0);
	signal via1_ca1_in: std_logic;
	signal via1_ca2_in: std_logic;
	signal via1_ca2_out: std_logic;
	signal via1_ca2_dir: std_logic;
	signal via1_pb_in: std_logic_vector(7 downto 0);
	signal via1_pb_out: std_logic_vector(7 downto 0);
	signal via1_pb_dir: std_logic_vector(7 downto 0);
	signal via1_cb1_in: std_logic;
	signal via1_cb1_out: std_logic;
	signal via1_cb1_dir: std_logic;
	signal via1_cb2_in: std_logic;
	signal via1_cb2_out: std_logic;
	signal via1_cb2_dir: std_logic;
	
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
			phi2        : in  std_logic;
			reset       : in  std_logic;
    
			addr        : in  std_logic_vector(3 downto 0);
			wen         : in  std_logic;
			ren         : in  std_logic;
			data_in     : in  std_logic_vector(7 downto 0);
			data_out    : out std_logic_vector(7 downto 0);

--			phi2_ref    : out std_logic;

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
	
	component ieeedir is
    Port ( 
           phi2 : in  STD_LOGIC;
           nres : in  STD_LOGIC;
			  dio_in : in  STD_LOGIC_VECTOR (7 downto 0);
           atn_in : in  STD_LOGIC;
           dav_in : in  STD_LOGIC;
           nrfd_in : in  STD_LOGIC;
			  is_out : out STD_LOGIC
	 );
	end component;

	-- test timer (50Hz)
	signal test_counter: std_logic_vector(15 downto 0);
	
begin

	rtx <= pia1_sel;
	rrts <= nbe_out; --D_in(2);
	
	irq <= pia1_irq or pia2_irq or via1_irq;
	
	res <= not(nres);
	
	D_in <= D;
	D <= (others => 'Z') when rwb = '0'
			else D_out;	
	D_out <= pia1_dout when pia1_sel = '1'
			else pia2_dout when pia2_sel = '1'
			else via1_dout when via1_sel = '1'
			else "10101010";	-- test pattern
			--else (others => 'X');

	-- I/O
	
	-- userport
	up(8) <= 'Z';
	up(10) <= 'Z';
	up(12) <= 'Z';
	up(13) <= 'Z';

	-- SPI (5V)
	spimosi <= '1';
	spiclk <= '1';
	spiiosel <= '1';
	
	-- cassette
	cwr <= 'Z';
	c1mtr <= 'Z';

	-- serial IEC
	dataout <= 'Z';
	clkout <= 'Z';
	atnout <= 'Z';
	srqout <= 'Z';
	
	-- rs232
	ltx <= 'Z';
	lrts <= 'Z';
	ldtr <= 'Z';

	--rtx <= 'Z';
	--rrts <= 'Z';
	rdtr <= 'Z';

	-- IEEE488
	
	-- Using the 7516x interface chips
	-- https://www.ti.com/lit/ds/symlink/sn75161b.pdf?ts=1774340006842
	--
	-- 75161 direction control; 0 = controller
	-- ATN out, SRQ in, REN out, IFC out
	dc <= '0';
	-- 7516x talk enable; 0: DAV in, EOI in (ATN hi), NRFD out, NDAC out
	te <= ieee_is_out;
	
	atn <= atn_out;
	ren <= '1';
	ifc <= '1';
	srq <= 'Z';

	ndac <= ndac_out when ieee_is_out = '0' else 'Z';
	nrfd <= nrfd_out when ieee_is_out = '0' else 'Z';
	dav <= dav_out when ieee_is_out = '1' else 'Z';
	eoi <= eoi_out when ieee_is_out = '1' else 'Z';
	
	dio(7 downto 0) <= dio_out when ieee_is_out = '1' else (others => 'Z');

	
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
	eoi_out <= pia1_ca2_out;
	
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
	dio_out <= pia2_pb_out;

	pia2_ca1_in <= atn;
	pia2_ca2_in <= 'X';		-- ndac out
	ndac_out <= pia2_ca2_out;
	
	pia2_cb1_in <= srq;
	
	pia2_cb2_in <= 'X';		-- dav out
	dav_out <= pia2_cb2_out;
		
	----------------------------------------------------

	via1_c: via6522
	   Port map (
         phi2,
			res,
			A(3 downto 0),
			via1_wren,
			via1_rden,			
         via1_din,
			via1_dout,

			via1_pa_out,			
			via1_pa_dir,			
			via1_pa_in,

			via1_pb_out,			
			via1_pb_dir,
			via1_pb_in,
			
         via1_ca1_in,
			
         via1_ca2_out,
         via1_ca2_in,
         via1_ca2_dir,

         via1_cb1_out,
         via1_cb1_in,
         via1_cb1_dir,

         via1_cb2_out,
         via1_cb2_in,
         via1_cb2_dir,
			
			via1_irq
		);
		
	via1_wren <= '1' when via1_sel = '1' and rwb = '0' else '0';
	via1_rden <= '1' when via1_sel = '1' and rwb = '1' else '0';
	
	via1_din <= D_in;

	via1_pa_in(3 downto 0) <= up(3 downto 0);
	via1_pa_in(4) <= up(7);
	via1_pa_in(5) <= up(6);
	via1_pa_in(6) <= up(5);
	via1_pa_in(5) <= up(4);
	
	via1_pb_in(0) <= ndac;
	
	up(0) <= via1_pa_out(0) when via1_pa_dir(0) = '1' else 'Z';
	up(1) <= via1_pa_out(1) when via1_pa_dir(1) = '1' else 'Z';
	up(2) <= via1_pa_out(2) when via1_pa_dir(2) = '1' else 'Z';
	up(3) <= via1_pa_out(3) when via1_pa_dir(3) = '1' else 'Z';
	up(4) <= via1_pa_out(7) when via1_pa_dir(7) = '1' else 'Z';
	up(5) <= via1_pa_out(6) when via1_pa_dir(6) = '1' else 'Z';
	up(6) <= via1_pa_out(5) when via1_pa_dir(5) = '1' else 'Z';
	up(7) <= via1_pa_out(4) when via1_pa_dir(4) = '1' else 'Z';
	
	via1_pb_in(0) <= ndac;
	nrfd_out <= via1_pb_out(1);
	atn_out <= via1_pb_out(2);
	cwr <= via1_pb_out(3);
	-- c2mtr <= via_pb_out(4);
	via1_pb_in(5) <= up(13);	-- vdrive
	via1_pb_in(6) <= nrfd;
	via1_pb_in(7) <= dav;
	
	-- graphic
	up(11) <= via1_ca2_out when via1_ca2_dir = '1' else 'Z';
	-- Userport CA1
	via1_ca1_in <= up(8);
	-- Cass#2 read
	via1_cb1_in <= up(12);
	-- shift register in/out
	up(9) <= via1_cb2_out when via1_cb2_dir = '1' else 'Z';
	
--
--	pia2_din <= D;
	----------------------------------------------------

	ieeedir_c: ieeedir
	port map(
		phi2,
		nres,
		dio,
		atn,
		dav,
		nrfd,
		ieee_is_out
	);
	
	-- IO select
	select_c: ioselect
	port map(
		A,
		niosel,
		nres,
		nbe_out,
		pia1_sel,
		pia2_sel,
		via1_sel,
		sel_via2,
		sel_uart1,
		sel_uart2
	);
	
	nbe <= nbe_out;
	
end Behavioral;

