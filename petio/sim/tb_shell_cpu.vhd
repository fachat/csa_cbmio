----------------------------------------------------------------------------------
-- Testbench: tb_shell_cpu
--
-- Instantiates the Shell (Shell.vhd) and drives it with a cycle-exact 6502 CPU
-- behavioural model.
--
-- Memory map seen by the CPU
--   $0000 – $03FF   1 kB RAM
--   $E800 – $E87F   Shell I/O window  (niosel asserted)
--   $E000 – $FFFF   8 kB ROM  (loaded from rom_file generic at start-up)
--
-- The ROM binary is supplied via the generic "rom_file".  If the file contains
-- fewer than 8192 bytes the data is placed at the *end* of the ROM region so
-- that the 6502 reset/irq/nmi vectors at $FFFA-$FFFF are always populated.
--
-- Simulation flow
--   1. nres held low for 8 phi2 cycles (external reset duration)
--   2. nres released; CPU performs its 7-cycle internal reset sequence,
--      fetches the reset vector from ROM, and begins execution
--   3. Simulation ends when the CPU executes a BRK (opcode $00) at any address
--      or after 1 000 000 clock cycles (safety timeout)
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use std.env.all;

entity tb_shell_cpu is
  generic (
    -- Path to the binary ROM image (up to 8 kB).  Supply on the command line
    -- with e.g.:  -grom_file=rom.bin
    rom_file : string := "rom.bin"
  );
end entity;

architecture tb of tb_shell_cpu is

  ---------------------------------------------------------------------------
  -- Clock / reset
  ---------------------------------------------------------------------------
  constant CLK_HALF : time := 500 ns;   -- 1 MHz phi2

  signal phi2 : std_logic := '0';
  signal nres : std_logic := '0';

  ---------------------------------------------------------------------------
  -- CPU bus signals
  ---------------------------------------------------------------------------
  signal cpu_addr : std_logic_vector(15 downto 0) := (others => '0');
  signal cpu_rwb  : std_logic := '1';          -- 1=read, 0=write
  signal cpu_dout : std_logic_vector(7 downto 0) := (others => '0');
  signal cpu_din  : std_logic_vector(7 downto 0);

  -- IRQ/NMI inputs to the CPU (active-low)
  signal cpu_nirq : std_logic := '1';
  signal cpu_nnmi : std_logic := '1';

  ---------------------------------------------------------------------------
  -- Shell port signals (tied-off where not under test)
  ---------------------------------------------------------------------------
  signal shell_D      : std_logic_vector(7 downto 0);
  signal shell_niosel : std_logic := '1';
  signal shell_irq    : std_logic;
  signal shell_nbe    : std_logic;

  -- SPI (outputs from Shell, unused in sim)
  signal shell_spiiosel : std_logic;
  signal shell_spimosi  : std_logic;
  signal shell_spimiso  : std_logic := '1';
  signal shell_spiclk   : std_logic;

  -- "left" RS-232
  signal shell_lcts : std_logic := '0';
  signal shell_lrts : std_logic;
  signal shell_lrx  : std_logic := '1';
  signal shell_ltx  : std_logic;
  signal shell_ldsr : std_logic := '0';
  signal shell_ldtr : std_logic;
  signal shell_ldcd : std_logic := '0';
  signal shell_lri  : std_logic := '0';

  -- "right" RS-232
  signal shell_rcts : std_logic := '0';   -- also used as iopage select
  signal shell_rrts : std_logic;
  signal shell_rrx  : std_logic := '1';
  signal shell_rtx  : std_logic;
  signal shell_rdsr : std_logic := '0';
  signal shell_rdtr : std_logic;

  -- Cassette
  signal shell_c1sw  : std_logic := 'Z';
  signal shell_cwr   : std_logic := 'Z';
  signal shell_c1rd  : std_logic := '1';
  signal shell_c1mtr : std_logic;

  -- Userport
  signal shell_up : std_logic_vector(13 downto 0) := (others => 'Z');

  -- Serial IEC
  signal shell_datain  : std_logic := '1';
  signal shell_clkin   : std_logic := '1';
  signal shell_satnin  : std_logic := '1';
  signal shell_srqin   : std_logic := '1';
  signal shell_dataout : std_logic;
  signal shell_clkout  : std_logic;
  signal shell_satnout : std_logic;
  signal shell_srqout  : std_logic;

  -- Keyboard
  signal shell_ksel : std_logic_vector(3 downto 0);
  signal shell_kin  : std_logic_vector(7 downto 0) := (others => '1');

  -- IEEE-488
  signal shell_dio  : std_logic_vector(7 downto 0) := (others => 'Z');
  signal shell_ren  : std_logic := 'Z';
  signal shell_ifc  : std_logic := 'Z';
  signal shell_ndac : std_logic := 'Z';
  signal shell_nrfd : std_logic := 'Z';
  signal shell_dav  : std_logic := 'Z';
  signal shell_eoi  : std_logic := 'Z';
  signal shell_atn  : std_logic := 'Z';
  signal shell_psrq : std_logic := 'Z';
  signal shell_te   : std_logic;
  signal shell_dc   : std_logic;

  ---------------------------------------------------------------------------
  -- Internal memories
  ---------------------------------------------------------------------------
  constant RAM_SIZE : natural := 1024;
  constant ROM_SIZE : natural := 8192;

  type ram_t is array (0 to RAM_SIZE - 1) of std_logic_vector(7 downto 0);
  type rom_t is array (0 to ROM_SIZE - 1) of std_logic_vector(7 downto 0);

  signal ram : ram_t := (others => (others => '0'));

  -- ROM is initialised in a procedure called at simulation start
  signal rom : rom_t := (others => x"EA");  -- NOP default

  ---------------------------------------------------------------------------
  -- CPU visible state
  ---------------------------------------------------------------------------
  signal cpu_pc  : unsigned(15 downto 0) := (others => '0');
  signal cpu_sp  : unsigned(7 downto 0)  := x"FD";
  signal cpu_a   : unsigned(7 downto 0)  := x"00";
  signal cpu_x   : unsigned(7 downto 0)  := x"00";
  signal cpu_y   : unsigned(7 downto 0)  := x"00";
  signal cpu_p   : unsigned(7 downto 0)  := x"24";   -- N V - B D I Z C
  signal opcode  : std_logic_vector(7 downto 0) := (others => '0');

  ---------------------------------------------------------------------------
  -- Helper: drive the Shell A input from the lower 12 bits of cpu_addr
  ---------------------------------------------------------------------------
  signal shell_A : std_logic_vector(11 downto 0);

begin

  ---------------------------------------------------------------------------
  -- Clock generation
  ---------------------------------------------------------------------------
  clk_p: process
  begin
    loop
      phi2 <= '0';
      wait for CLK_HALF;
      phi2 <= '1';
      wait for CLK_HALF;
    end loop;
  end process;

  ---------------------------------------------------------------------------
  -- Reset generation: 8 cycles low, then release
  ---------------------------------------------------------------------------
  rst_p: process
  begin
    nres <= '0';
    wait for CLK_HALF * 16;   -- 8 full cycles
    nres <= '1';
    wait;
  end process;

  ---------------------------------------------------------------------------
  -- ROM load at time 0
  ---------------------------------------------------------------------------
  rom_load_p: process
    type byte_file_t is file of character;
    file     rom_f    : byte_file_t;
    variable ch       : character;
    variable buf      : rom_t := (others => x"EA");
    variable idx      : natural := 0;
    variable byte_cnt : natural := 0;
    variable fstatus  : file_open_status;
  begin
    file_open(fstatus, rom_f, rom_file, read_mode);
    if fstatus /= open_ok then
      report "tb_shell_cpu: cannot open ROM file: " & rom_file severity failure;
    end if;

    -- Read all bytes into a temporary buffer
    while not endfile(rom_f) loop
      read(rom_f, ch);
      if byte_cnt < ROM_SIZE then
        buf(byte_cnt) := std_logic_vector(to_unsigned(character'pos(ch), 8));
      end if;
      byte_cnt := byte_cnt + 1;
    end loop;
    file_close(rom_f);

    if byte_cnt > ROM_SIZE then
      report "tb_shell_cpu: ROM file larger than 8 kB, truncating to 8 kB"
        severity warning;
      byte_cnt := ROM_SIZE;
    end if;

    -- Place the data at the END of the ROM array so the 6502 vector area
    -- ($FFFA-$FFFF, i.e. ROM offsets $1FFA-$1FFF) is always populated.
    if byte_cnt < ROM_SIZE then
      for i in 0 to byte_cnt - 1 loop
        rom(ROM_SIZE - byte_cnt + i) <= buf(i);
      end loop;
    else
      for i in 0 to ROM_SIZE - 1 loop
        rom(i) <= buf(i);
      end loop;
    end if;

    report "tb_shell_cpu: loaded " & integer'image(byte_cnt)
           & " bytes from " & rom_file;
    wait;
  end process;

  ---------------------------------------------------------------------------
  -- Memory-mapped bus read
  -- ROM:  $E000 – $FFFF (except the Shell I/O window at $E800-$E87F)
  -- RAM:  $0000 – $03FF
  -- Shell is on the bidirectional D bus; reads from it are handled by Shell DUT
  ---------------------------------------------------------------------------
  bus_read_p: process(cpu_addr, ram, rom, shell_D, cpu_rwb)
    variable addr_i : unsigned(15 downto 0);
  begin
    addr_i := unsigned(cpu_addr);
    cpu_din <= x"FF";   -- open bus default

    if cpu_rwb = '1' then
      if addr_i >= x"E800" and addr_i <= x"E87F" then
        -- Shell drives the bus; read back what Shell put on D
        if shell_D = (shell_D'range => 'Z') then
          cpu_din <= x"FF";
        else
          cpu_din <= shell_D;
        end if;
      elsif addr_i >= x"E000" and addr_i <= x"FFFF" then
        cpu_din <= rom(to_integer(addr_i - x"E000"));
      elsif addr_i >= x"0000" and addr_i <= x"03FF" then
        cpu_din <= ram(to_integer(addr_i(9 downto 0)));
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Shell data bus connection
  --   CPU reads  -> Shell drives D (Shell.rwb=1)
  --   CPU writes -> CPU drives D via shell_D  (Shell.rwb=0)
  ---------------------------------------------------------------------------
  shell_D <= cpu_dout when (cpu_rwb = '0'
                            and unsigned(cpu_addr) >= x"E800"
                            and unsigned(cpu_addr) <= x"E87F")
             else (others => 'Z');

  -- Shell address: lower 12 bits of CPU address
  shell_A <= cpu_addr(11 downto 0);

  -- niosel: asserted (low) when CPU accesses $E800-$E87F ($E800 = 1110_1000_0xxx_xxxx)
  -- The Shell only uses A(11:0); niosel covers the upper decode.
  shell_niosel <= '0' when (unsigned(cpu_addr) >= x"E800"
                            and unsigned(cpu_addr) <= x"E87F")
                  else '1';

  ---------------------------------------------------------------------------
  -- Shell DUT instantiation
  ---------------------------------------------------------------------------
  shell_dut: entity work.Shell
    port map (
      phi2     => phi2,
      rwb      => cpu_rwb,
      niosel   => shell_niosel,
      nres     => nres,
      A        => shell_A,
      D        => shell_D,

      irq      => shell_irq,
      nbe      => shell_nbe,

      spiiosel => shell_spiiosel,
      spimosi  => shell_spimosi,
      spimiso  => shell_spimiso,
      spiclk   => shell_spiclk,

      lcts => shell_lcts,
      lrts => shell_lrts,
      lrx  => shell_lrx,
      ltx  => shell_ltx,
      ldsr => shell_ldsr,
      ldtr => shell_ldtr,
      ldcd => shell_ldcd,
      lri  => shell_lri,

      rcts => shell_rcts,
      rrts => shell_rrts,
      rrx  => shell_rrx,
      rtx  => shell_rtx,
      rdsr => shell_rdsr,
      rdtr => shell_rdtr,

      c1sw  => shell_c1sw,
      cwr   => shell_cwr,
      c1rd  => shell_c1rd,
      c1mtr => shell_c1mtr,

      up => shell_up,

      datain  => shell_datain,
      clkin   => shell_clkin,
      satnin  => shell_satnin,
      srqin   => shell_srqin,
      dataout => shell_dataout,
      clkout  => shell_clkout,
      satnout => shell_satnout,
      srqout  => shell_srqout,

      ksel => shell_ksel,
      kin  => shell_kin,

      dio  => shell_dio,
      ren  => shell_ren,
      ifc  => shell_ifc,
      ndac => shell_ndac,
      nrfd => shell_nrfd,
      dav  => shell_dav,
      eoi  => shell_eoi,
      atn  => shell_atn,
      psrq => shell_psrq,
      te   => shell_te,
      dc   => shell_dc
    );

  ---------------------------------------------------------------------------
  -- IRQ from Shell feeds into the CPU
  ---------------------------------------------------------------------------
  cpu_nirq <= not shell_irq;

  ---------------------------------------------------------------------------
  -- RAM write
  ---------------------------------------------------------------------------
  ram_write_p: process(phi2)
    variable addr_i : unsigned(9 downto 0);
  begin
    if falling_edge(phi2) then
      if cpu_rwb = '0'
         and unsigned(cpu_addr) >= x"0000"
         and unsigned(cpu_addr) <= x"03FF" then
        addr_i := unsigned(cpu_addr(9 downto 0));
        ram(to_integer(addr_i)) <= cpu_dout;
      end if;
    end if;
  end process;

  -- 6502 CPU behavioural model
  ---------------------------------------------------------------------------
  cpu_dut: entity work.cpu6502
    port map (
      phi2     => phi2,
      nres     => nres,
      cpu_nirq => cpu_nirq,
      cpu_nnmi => cpu_nnmi,
      cpu_addr => cpu_addr,
      cpu_rwb  => cpu_rwb,
      cpu_dout => cpu_dout,
      cpu_din  => cpu_din,
      cpu_pc   => cpu_pc,
      cpu_sp   => cpu_sp,
      cpu_a    => cpu_a,
      cpu_x    => cpu_x,
      cpu_y    => cpu_y,
      cpu_p    => cpu_p,
      opcode   => opcode
    );

end architecture;
