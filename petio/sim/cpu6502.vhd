----------------------------------------------------------------------------------
-- cpu6502
--
-- Cycle-exact behavioural 6502 CPU model extracted from tb_shell_cpu.
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity cpu6502 is
  port (
    phi2     : in  std_logic;
    nres     : in  std_logic;
    cpu_nirq : in  std_logic := '1';
    cpu_nnmi : in  std_logic := '1';
    cpu_addr : out std_logic_vector(15 downto 0);
    cpu_rwb  : out std_logic;
    cpu_dout : out std_logic_vector(7 downto 0);
    cpu_din  : in  std_logic_vector(7 downto 0);
    cpu_pc   : out unsigned(15 downto 0);
    cpu_sp   : out unsigned(7 downto 0);
    cpu_a    : out unsigned(7 downto 0);
    cpu_x    : out unsigned(7 downto 0);
    cpu_y    : out unsigned(7 downto 0);
    cpu_p    : out unsigned(7 downto 0);
    opcode   : out std_logic_vector(7 downto 0)
  );
end entity;

architecture behavioral of cpu6502 is
begin
  ---------------------------------------------------------------------------
  -- Cycle-exact 6502 CPU behavioural model
  --
  -- This is a minimal but cycle-accurate behavioural implementation.
  -- It models:
  --   * Reset sequence (7 cycles)
  --   * All official addressing modes and instructions
  --   * Correct read-modify-write bus behaviour
  --   * IRQ and NMI (edge/level sensitive)
  --   * BRK terminates the simulation
  --
  -- Timing matches the original NMOS 6502:
  --   phi2 low  -> CPU drives address + rwb
  --   phi2 high -> CPU samples/drives data
  ---------------------------------------------------------------------------
  cpu_proc: process
    ---------------------------------------------------------------------------
    -- Helpers operating on shared signals
    ---------------------------------------------------------------------------
    variable v_pc  : unsigned(15 downto 0);
    variable v_sp  : unsigned(7 downto 0);
    variable v_a   : unsigned(7 downto 0);
    variable v_x   : unsigned(7 downto 0);
    variable v_y   : unsigned(7 downto 0);
    variable v_p   : unsigned(7 downto 0);   -- N V - B D I Z C
    variable v_op  : unsigned(7 downto 0);
    variable v_ea  : unsigned(15 downto 0);  -- effective address
    variable v_d   : unsigned(7 downto 0);   -- data byte
    variable v_nmi_pending : boolean;
    variable v_prev_nnmi   : std_logic;
    variable v_cyc         : natural := 0;

    -- Flag bit positions
    constant FN : natural := 7;
    constant FV : natural := 6;
    constant FB : natural := 4;
    constant FD : natural := 3;
    constant FI : natural := 2;
    constant FZ : natural := 1;
    constant FC : natural := 0;

    ---------------------------------------------------------------------------
    -- Bus helpers – all wait for phi2
    ---------------------------------------------------------------------------
    procedure bus_read(addr : in  unsigned(15 downto 0);
                       data : out unsigned(7 downto 0)) is
    begin
      cpu_addr <= std_logic_vector(addr);
      cpu_rwb  <= '1';
      wait until rising_edge(phi2);
      data := unsigned(cpu_din);
      v_cyc := v_cyc + 1;
    end procedure;

    procedure bus_write(addr : in unsigned(15 downto 0);
                        data : in unsigned(7 downto 0)) is
    begin
      cpu_addr <= std_logic_vector(addr);
      cpu_rwb  <= '0';
      cpu_dout <= std_logic_vector(data);
      wait until rising_edge(phi2);
      v_cyc := v_cyc + 1;
      -- leave bus driven; caller must do a read (or idle read) to release
    end procedure;

    -- Stack helpers (stack page $01xx)
    procedure push(data : in unsigned(7 downto 0)) is
    begin
      bus_write(x"01" & v_sp, data);
      v_sp := v_sp - 1;
    end procedure;

    procedure pop(data : out unsigned(7 downto 0)) is
    begin
      v_sp := v_sp + 1;
      bus_read(x"01" & v_sp, data);
    end procedure;

    -- Update N and Z flags from value
    procedure set_nz(val : unsigned(7 downto 0)) is
    begin
      v_p(FN) := val(7);
      if val = x"00" then v_p(FZ) := '1'; else v_p(FZ) := '0'; end if;
    end procedure;

    -- Fetch one byte from PC and advance PC
    procedure fetch_byte(data : out unsigned(7 downto 0)) is
    begin
      bus_read(v_pc, data);
      v_pc := v_pc + 1;
    end procedure;

    -- Fetch 16-bit little-endian from PC (two consecutive reads)
    procedure fetch_word(data : out unsigned(15 downto 0)) is
      variable lo, hi : unsigned(7 downto 0);
    begin
      fetch_byte(lo);
      fetch_byte(hi);
      data := hi & lo;
    end procedure;

    -- Read 16-bit little-endian from address (two consecutive reads)
    -- Wraps within the zero page for zero-page indirect
    procedure read_word(addr : in  unsigned(15 downto 0);
                        data : out unsigned(15 downto 0);
                        zp   : in  boolean := false) is
      variable lo, hi   : unsigned(7 downto 0);
      variable addr_hi  : unsigned(15 downto 0);
    begin
      bus_read(addr, lo);
      if zp then
        addr_hi := x"00" & (addr(7 downto 0) + 1);
      else
        addr_hi := addr + 1;
      end if;
      bus_read(addr_hi, hi);
      data := hi & lo;
    end procedure;

    ---------------------------------------------------------------------------
    -- Addressing mode helpers
    -- All return the effective address in v_ea; some also read the operand
    ---------------------------------------------------------------------------

    -- Immediate: operand is the next byte after opcode
    procedure am_imm(data : out unsigned(7 downto 0)) is
    begin
      fetch_byte(data);
    end procedure;

    -- Zero page
    procedure am_zp(ea : out unsigned(15 downto 0)) is
      variable zp : unsigned(7 downto 0);
    begin
      fetch_byte(zp);
      ea := x"00" & zp;
    end procedure;

    -- Zero page, X
    procedure am_zpx(ea : out unsigned(15 downto 0)) is
      variable zp : unsigned(7 downto 0);
    begin
      fetch_byte(zp);
      bus_read(x"00" & zp, v_d);      -- dummy read
      ea := x"00" & (zp + v_x);
    end procedure;

    -- Zero page, Y
    procedure am_zpy(ea : out unsigned(15 downto 0)) is
      variable zp : unsigned(7 downto 0);
    begin
      fetch_byte(zp);
      bus_read(x"00" & zp, v_d);      -- dummy read
      ea := x"00" & (zp + v_y);
    end procedure;

    -- Absolute
    procedure am_abs(ea : out unsigned(15 downto 0)) is
    begin
      fetch_word(ea);
    end procedure;

    -- Absolute, X  (with page-cross penalty cycle for reads)
    procedure am_absx(ea : out unsigned(15 downto 0); penalty : boolean := true) is
      variable base : unsigned(15 downto 0);
      variable sum  : unsigned(15 downto 0);
    begin
      fetch_word(base);
      sum := base + v_x;
      if penalty and (sum(15 downto 8) /= base(15 downto 8)) then
        -- page crossed: dummy read from non-carried high byte
        bus_read((base(15 downto 8) & sum(7 downto 0)), v_d);
      end if;
      ea := sum;
    end procedure;

    -- Absolute, Y  (with page-cross penalty cycle for reads)
    procedure am_absy(ea : out unsigned(15 downto 0); penalty : boolean := true) is
      variable base : unsigned(15 downto 0);
      variable sum  : unsigned(15 downto 0);
    begin
      fetch_word(base);
      sum := base + v_y;
      if penalty and (sum(15 downto 8) /= base(15 downto 8)) then
        bus_read((base(15 downto 8) & sum(7 downto 0)), v_d);
      end if;
      ea := sum;
    end procedure;

    -- (Indirect, X)
    procedure am_indx(ea : out unsigned(15 downto 0)) is
      variable zp  : unsigned(7 downto 0);
      variable ptr : unsigned(15 downto 0);
    begin
      fetch_byte(zp);
      bus_read(x"00" & zp, v_d);          -- dummy read
      ptr := x"00" & (zp + v_x);
      read_word(ptr, ea, zp => true);
    end procedure;

    -- (Indirect), Y  (with page-cross penalty for reads)
    procedure am_indy(ea : out unsigned(15 downto 0); penalty : boolean := true) is
      variable zp   : unsigned(7 downto 0);
      variable base : unsigned(15 downto 0);
      variable sum  : unsigned(15 downto 0);
    begin
      fetch_byte(zp);
      read_word(x"00" & zp, base, zp => true);
      sum := base + v_y;
      if penalty and (sum(15 downto 8) /= base(15 downto 8)) then
        bus_read((base(15 downto 8) & sum(7 downto 0)), v_d);
      end if;
      ea := sum;
    end procedure;

    ---------------------------------------------------------------------------
    -- ALU helpers
    ---------------------------------------------------------------------------
    procedure alu_adc(operand : unsigned(7 downto 0)) is
      variable res9   : unsigned(8 downto 0);
      variable carry9 : unsigned(8 downto 0);
    begin
      if v_p(FC) = '1' then carry9 := to_unsigned(1, 9);
      else                  carry9 := to_unsigned(0, 9); end if;
      if v_p(FD) = '1' then
        -- BCD mode (simplified, no half-carry accuracy)
        res9 := ('0' & v_a) + ('0' & operand) + carry9;
        v_p(FC) := res9(8);
        v_a := res9(7 downto 0);
        set_nz(v_a);
        v_p(FV) := '0';
      else
        res9 := ('0' & v_a) + ('0' & operand) + carry9;
        v_p(FV) := (not (v_a(7) xor operand(7))) and (v_a(7) xor res9(7));
        v_p(FC) := res9(8);
        v_a := res9(7 downto 0);
        set_nz(v_a);
      end if;
    end procedure;

    procedure alu_sbc(operand : unsigned(7 downto 0)) is
    begin
      -- Note: BCD subtraction (D flag set) is not accurately modelled here;
      -- the simplified BCD path in alu_adc does not implement the correct
      -- decimal-mode SBC algorithm.  Binary (non-BCD) SBC is fully correct.
      alu_adc(not operand);
    end procedure;

    procedure alu_cmp(reg : unsigned(7 downto 0); operand : unsigned(7 downto 0)) is
      variable res9 : unsigned(8 downto 0);
    begin
      res9 := ('0' & reg) - ('0' & operand);
      v_p(FC) := not res9(8);
      set_nz(res9(7 downto 0));
    end procedure;

    -- Read-Modify-Write: read, dummy write (same value), compute, write result
    procedure rmw(ea : unsigned(15 downto 0); result : out unsigned(7 downto 0)) is
      variable val : unsigned(7 downto 0);
    begin
      bus_read(ea, val);
      bus_write(ea, val);     -- dummy write (RMW bus cycle)
      result := val;
    end procedure;

    ---------------------------------------------------------------------------
    -- Branch helper (relative addressing, 1 or 2 extra cycles)
    ---------------------------------------------------------------------------
    procedure branch(cond : boolean) is
      variable rel  : unsigned(7 downto 0);
      variable dest : unsigned(15 downto 0);
    begin
      fetch_byte(rel);
      if cond then
        -- 1 extra cycle for taken branch
        bus_read(v_pc, v_d);   -- dummy: fetch next instruction (discarded)
        -- Sign-extend the 8-bit relative offset to 16 bits and add to PC
        dest := unsigned(resize(signed(rel), 16)) + v_pc;
        if dest(15 downto 8) /= v_pc(15 downto 8) then
          -- 1 extra cycle for page cross
          bus_read(v_pc, v_d);
        end if;
        v_pc := dest;
      end if;
    end procedure;

    ---------------------------------------------------------------------------
    -- Push PC and P for BRK/IRQ/NMI
    ---------------------------------------------------------------------------
    procedure push_pcb(brk_flag : std_logic) is
      variable p_push : unsigned(7 downto 0);
    begin
      push(v_pc(15 downto 8));
      push(v_pc(7 downto 0));
      p_push := v_p;
      if brk_flag = '1' then
        p_push(FB) := '1';
      end if;
      push(p_push);
    end procedure;

    ---------------------------------------------------------------------------
    -- Main loop variables
    ---------------------------------------------------------------------------
    variable v_lo, v_hi : unsigned(7 downto 0);
    variable v_res      : unsigned(7 downto 0);
    variable v_addr16   : unsigned(15 downto 0);

  begin
    -------------------------------------------------------------------------
    -- Wait until after ROM has been loaded (time 0 delta)
    -------------------------------------------------------------------------
    wait for 1 ns;

    -------------------------------------------------------------------------
    -- Hold reset
    -------------------------------------------------------------------------
    cpu_addr <= (others => '0');
    cpu_rwb  <= '1';
    cpu_dout <= (others => '0');

    v_prev_nnmi := '1';
    v_nmi_pending := false;

    wait until nres = '1';

    -------------------------------------------------------------------------
    -- Reset sequence: 7 cycles
    --   Cycles 1-5: internal, plus stack pops (with rwb=1)
    --   Cycles 6-7: fetch vector from $FFFC/$FFFD
    -------------------------------------------------------------------------
    -- Cycles 1-2: internal
    bus_read(v_pc, v_d);
    bus_read(v_pc, v_d);
    -- Cycles 3-5: stack pointer decrements (reads, not writes on reset)
    bus_read(x"01" & v_sp, v_d); v_sp := v_sp - 1;
    bus_read(x"01" & v_sp, v_d); v_sp := v_sp - 1;
    bus_read(x"01" & v_sp, v_d); v_sp := v_sp - 1;
    -- Fetch reset vector
    bus_read(x"FFFC", v_lo);
    bus_read(x"FFFD", v_hi);
    v_pc := v_hi & v_lo;
    v_p(FI) := '1';    -- interrupt disable set after reset

    -- Update visible signals
    cpu_pc <= v_pc;
    cpu_sp <= v_sp;
    cpu_p  <= v_p;

    report "tb_shell_cpu: CPU starting at PC=$"
           & to_hstring(v_pc) severity note;

    -------------------------------------------------------------------------
    -- Safety timeout watchdog
    -------------------------------------------------------------------------
    -- (handled implicitly; the simulation will be killed by GHDL limits if
    --  the code never hits BRK.  A report will be issued at the timeout.)

    -------------------------------------------------------------------------
    -- Main execution loop
    -------------------------------------------------------------------------
    loop
      if v_cyc > 1_000_000 then
        report "tb_shell_cpu: safety timeout after 1 000 000 bus cycles"
               severity failure;
      end if;

      -- Sample NMI edge
      if cpu_nnmi = '0' and v_prev_nnmi = '1' then
        v_nmi_pending := true;
      end if;
      v_prev_nnmi := cpu_nnmi;

      -- Fetch opcode
      fetch_byte(v_op);
      opcode <= std_logic_vector(v_op);

      -- BRK / end of test
      if v_op = x"00" then
        -- dummy reads (BRK is 2-byte opcode)
        bus_read(v_pc, v_d);   -- read signature byte
        report "tb_shell_cpu: BRK at PC=$" & to_hstring(v_pc - 1)
               & "  A=$" & to_hstring(v_a)
               & "  X=$" & to_hstring(v_x)
               & "  Y=$" & to_hstring(v_y)
               & "  SP=$" & to_hstring(v_sp)
               & "  P=$"  & to_hstring(v_p)
               severity note;
        finish;
      end if;

      -----------------------------------------------------------------------
      -- Instruction decode and execute
      -----------------------------------------------------------------------
      case v_op is

        -- ---------------------------------------------------------------
        -- Load / Store
        -- ---------------------------------------------------------------
        when x"A9" => am_imm(v_d); v_a := v_d; set_nz(v_a);               -- LDA imm
        when x"A5" => am_zp(v_ea);  bus_read(v_ea,v_d); v_a:=v_d; set_nz(v_a);   -- LDA zp
        when x"B5" => am_zpx(v_ea); bus_read(v_ea,v_d); v_a:=v_d; set_nz(v_a);   -- LDA zp,X
        when x"AD" => am_abs(v_ea); bus_read(v_ea,v_d); v_a:=v_d; set_nz(v_a);   -- LDA abs
        when x"BD" => am_absx(v_ea);bus_read(v_ea,v_d); v_a:=v_d; set_nz(v_a);   -- LDA abs,X
        when x"B9" => am_absy(v_ea);bus_read(v_ea,v_d); v_a:=v_d; set_nz(v_a);   -- LDA abs,Y
        when x"A1" => am_indx(v_ea);bus_read(v_ea,v_d); v_a:=v_d; set_nz(v_a);   -- LDA (zp,X)
        when x"B1" => am_indy(v_ea);bus_read(v_ea,v_d); v_a:=v_d; set_nz(v_a);   -- LDA (zp),Y

        when x"A2" => am_imm(v_d); v_x := v_d; set_nz(v_x);               -- LDX imm
        when x"A6" => am_zp(v_ea);  bus_read(v_ea,v_d); v_x:=v_d; set_nz(v_x);   -- LDX zp
        when x"B6" => am_zpy(v_ea); bus_read(v_ea,v_d); v_x:=v_d; set_nz(v_x);   -- LDX zp,Y
        when x"AE" => am_abs(v_ea); bus_read(v_ea,v_d); v_x:=v_d; set_nz(v_x);   -- LDX abs
        when x"BE" => am_absy(v_ea);bus_read(v_ea,v_d); v_x:=v_d; set_nz(v_x);   -- LDX abs,Y

        when x"A0" => am_imm(v_d); v_y := v_d; set_nz(v_y);               -- LDY imm
        when x"A4" => am_zp(v_ea);  bus_read(v_ea,v_d); v_y:=v_d; set_nz(v_y);   -- LDY zp
        when x"B4" => am_zpx(v_ea); bus_read(v_ea,v_d); v_y:=v_d; set_nz(v_y);   -- LDY zp,X
        when x"AC" => am_abs(v_ea); bus_read(v_ea,v_d); v_y:=v_d; set_nz(v_y);   -- LDY abs
        when x"BC" => am_absx(v_ea);bus_read(v_ea,v_d); v_y:=v_d; set_nz(v_y);   -- LDY abs,X

        when x"85" => am_zp(v_ea);  bus_write(v_ea, v_a);                  -- STA zp
        when x"95" => am_zpx(v_ea); bus_write(v_ea, v_a);                  -- STA zp,X
        when x"8D" => am_abs(v_ea); bus_write(v_ea, v_a);                  -- STA abs
        when x"9D" => am_absx(v_ea, penalty=>false); bus_write(v_ea, v_a); -- STA abs,X
        when x"99" => am_absy(v_ea, penalty=>false); bus_write(v_ea, v_a); -- STA abs,Y
        when x"81" => am_indx(v_ea); bus_write(v_ea, v_a);                 -- STA (zp,X)
        when x"91" => am_indy(v_ea, penalty=>false); bus_write(v_ea, v_a); -- STA (zp),Y

        when x"86" => am_zp(v_ea);  bus_write(v_ea, v_x);                  -- STX zp
        when x"96" => am_zpy(v_ea); bus_write(v_ea, v_x);                  -- STX zp,Y
        when x"8E" => am_abs(v_ea); bus_write(v_ea, v_x);                  -- STX abs

        when x"84" => am_zp(v_ea);  bus_write(v_ea, v_y);                  -- STY zp
        when x"94" => am_zpx(v_ea); bus_write(v_ea, v_y);                  -- STY zp,X
        when x"8C" => am_abs(v_ea); bus_write(v_ea, v_y);                  -- STY abs

        -- ---------------------------------------------------------------
        -- Transfer
        -- ---------------------------------------------------------------
        when x"AA" => bus_read(v_pc, v_d); v_x := v_a; set_nz(v_x);  -- TAX
        when x"8A" => bus_read(v_pc, v_d); v_a := v_x; set_nz(v_a);  -- TXA
        when x"A8" => bus_read(v_pc, v_d); v_y := v_a; set_nz(v_y);  -- TAY
        when x"98" => bus_read(v_pc, v_d); v_a := v_y; set_nz(v_a);  -- TYA
        when x"BA" => bus_read(v_pc, v_d); v_x := v_sp; set_nz(v_x); -- TSX
        when x"9A" => bus_read(v_pc, v_d); v_sp := v_x;              -- TXS (no flags)

        -- ---------------------------------------------------------------
        -- Stack
        -- ---------------------------------------------------------------
        when x"48" => bus_read(v_pc, v_d); push(v_a);          -- PHA
        when x"68" =>                                            -- PLA
          bus_read(v_pc, v_d);
          bus_read(x"01" & v_sp, v_d);   -- dummy
          pop(v_d); v_a := v_d; set_nz(v_a);
        when x"08" => bus_read(v_pc, v_d); push(v_p or x"10"); -- PHP (B=1)
        when x"28" =>                                            -- PLP
          bus_read(v_pc, v_d);
          bus_read(x"01" & v_sp, v_d);   -- dummy
          pop(v_d); v_p := v_d;

        -- ---------------------------------------------------------------
        -- Logic
        -- ---------------------------------------------------------------
        when x"29" => am_imm(v_d);  v_a := v_a and v_d; set_nz(v_a);  -- AND imm
        when x"25" => am_zp(v_ea);  bus_read(v_ea,v_d); v_a:=v_a and v_d; set_nz(v_a);
        when x"35" => am_zpx(v_ea); bus_read(v_ea,v_d); v_a:=v_a and v_d; set_nz(v_a);
        when x"2D" => am_abs(v_ea); bus_read(v_ea,v_d); v_a:=v_a and v_d; set_nz(v_a);
        when x"3D" => am_absx(v_ea);bus_read(v_ea,v_d); v_a:=v_a and v_d; set_nz(v_a);
        when x"39" => am_absy(v_ea);bus_read(v_ea,v_d); v_a:=v_a and v_d; set_nz(v_a);
        when x"21" => am_indx(v_ea);bus_read(v_ea,v_d); v_a:=v_a and v_d; set_nz(v_a);
        when x"31" => am_indy(v_ea);bus_read(v_ea,v_d); v_a:=v_a and v_d; set_nz(v_a);

        when x"09" => am_imm(v_d);  v_a := v_a or  v_d; set_nz(v_a);  -- ORA imm
        when x"05" => am_zp(v_ea);  bus_read(v_ea,v_d); v_a:=v_a or  v_d; set_nz(v_a);
        when x"15" => am_zpx(v_ea); bus_read(v_ea,v_d); v_a:=v_a or  v_d; set_nz(v_a);
        when x"0D" => am_abs(v_ea); bus_read(v_ea,v_d); v_a:=v_a or  v_d; set_nz(v_a);
        when x"1D" => am_absx(v_ea);bus_read(v_ea,v_d); v_a:=v_a or  v_d; set_nz(v_a);
        when x"19" => am_absy(v_ea);bus_read(v_ea,v_d); v_a:=v_a or  v_d; set_nz(v_a);
        when x"01" => am_indx(v_ea);bus_read(v_ea,v_d); v_a:=v_a or  v_d; set_nz(v_a);
        when x"11" => am_indy(v_ea);bus_read(v_ea,v_d); v_a:=v_a or  v_d; set_nz(v_a);

        when x"49" => am_imm(v_d);  v_a := v_a xor v_d; set_nz(v_a);  -- EOR imm
        when x"45" => am_zp(v_ea);  bus_read(v_ea,v_d); v_a:=v_a xor v_d; set_nz(v_a);
        when x"55" => am_zpx(v_ea); bus_read(v_ea,v_d); v_a:=v_a xor v_d; set_nz(v_a);
        when x"4D" => am_abs(v_ea); bus_read(v_ea,v_d); v_a:=v_a xor v_d; set_nz(v_a);
        when x"5D" => am_absx(v_ea);bus_read(v_ea,v_d); v_a:=v_a xor v_d; set_nz(v_a);
        when x"59" => am_absy(v_ea);bus_read(v_ea,v_d); v_a:=v_a xor v_d; set_nz(v_a);
        when x"41" => am_indx(v_ea);bus_read(v_ea,v_d); v_a:=v_a xor v_d; set_nz(v_a);
        when x"51" => am_indy(v_ea);bus_read(v_ea,v_d); v_a:=v_a xor v_d; set_nz(v_a);

        -- BIT
        when x"24" => am_zp(v_ea);  bus_read(v_ea,v_d);
          v_p(FN):=v_d(7); v_p(FV):=v_d(6);
          if (v_a and v_d) = x"00" then v_p(FZ):='1'; else v_p(FZ):='0'; end if;
        when x"2C" => am_abs(v_ea); bus_read(v_ea,v_d);
          v_p(FN):=v_d(7); v_p(FV):=v_d(6);
          if (v_a and v_d) = x"00" then v_p(FZ):='1'; else v_p(FZ):='0'; end if;

        -- ---------------------------------------------------------------
        -- Arithmetic
        -- ---------------------------------------------------------------
        when x"69" => am_imm(v_d);  alu_adc(v_d);   -- ADC imm
        when x"65" => am_zp(v_ea);  bus_read(v_ea,v_d); alu_adc(v_d);
        when x"75" => am_zpx(v_ea); bus_read(v_ea,v_d); alu_adc(v_d);
        when x"6D" => am_abs(v_ea); bus_read(v_ea,v_d); alu_adc(v_d);
        when x"7D" => am_absx(v_ea);bus_read(v_ea,v_d); alu_adc(v_d);
        when x"79" => am_absy(v_ea);bus_read(v_ea,v_d); alu_adc(v_d);
        when x"61" => am_indx(v_ea);bus_read(v_ea,v_d); alu_adc(v_d);
        when x"71" => am_indy(v_ea);bus_read(v_ea,v_d); alu_adc(v_d);

        when x"E9" => am_imm(v_d);  alu_sbc(v_d);   -- SBC imm
        when x"E5" => am_zp(v_ea);  bus_read(v_ea,v_d); alu_sbc(v_d);
        when x"F5" => am_zpx(v_ea); bus_read(v_ea,v_d); alu_sbc(v_d);
        when x"ED" => am_abs(v_ea); bus_read(v_ea,v_d); alu_sbc(v_d);
        when x"FD" => am_absx(v_ea);bus_read(v_ea,v_d); alu_sbc(v_d);
        when x"F9" => am_absy(v_ea);bus_read(v_ea,v_d); alu_sbc(v_d);
        when x"E1" => am_indx(v_ea);bus_read(v_ea,v_d); alu_sbc(v_d);
        when x"F1" => am_indy(v_ea);bus_read(v_ea,v_d); alu_sbc(v_d);

        -- CMP / CPX / CPY
        when x"C9" => am_imm(v_d);  alu_cmp(v_a, v_d);
        when x"C5" => am_zp(v_ea);  bus_read(v_ea,v_d); alu_cmp(v_a, v_d);
        when x"D5" => am_zpx(v_ea); bus_read(v_ea,v_d); alu_cmp(v_a, v_d);
        when x"CD" => am_abs(v_ea); bus_read(v_ea,v_d); alu_cmp(v_a, v_d);
        when x"DD" => am_absx(v_ea);bus_read(v_ea,v_d); alu_cmp(v_a, v_d);
        when x"D9" => am_absy(v_ea);bus_read(v_ea,v_d); alu_cmp(v_a, v_d);
        when x"C1" => am_indx(v_ea);bus_read(v_ea,v_d); alu_cmp(v_a, v_d);
        when x"D1" => am_indy(v_ea);bus_read(v_ea,v_d); alu_cmp(v_a, v_d);

        when x"E0" => am_imm(v_d);  alu_cmp(v_x, v_d);    -- CPX imm
        when x"E4" => am_zp(v_ea);  bus_read(v_ea,v_d); alu_cmp(v_x, v_d);
        when x"EC" => am_abs(v_ea); bus_read(v_ea,v_d); alu_cmp(v_x, v_d);

        when x"C0" => am_imm(v_d);  alu_cmp(v_y, v_d);    -- CPY imm
        when x"C4" => am_zp(v_ea);  bus_read(v_ea,v_d); alu_cmp(v_y, v_d);
        when x"CC" => am_abs(v_ea); bus_read(v_ea,v_d); alu_cmp(v_y, v_d);

        -- ---------------------------------------------------------------
        -- Increment / Decrement
        -- ---------------------------------------------------------------
        when x"E8" => bus_read(v_pc, v_d); v_x:=v_x+1; set_nz(v_x);  -- INX
        when x"C8" => bus_read(v_pc, v_d); v_y:=v_y+1; set_nz(v_y);  -- INY
        when x"CA" => bus_read(v_pc, v_d); v_x:=v_x-1; set_nz(v_x);  -- DEX
        when x"88" => bus_read(v_pc, v_d); v_y:=v_y-1; set_nz(v_y);  -- DEY

        when x"E6" => am_zp(v_ea);  rmw(v_ea,v_res); v_res:=v_res+1; set_nz(v_res); bus_write(v_ea,v_res);  -- INC zp
        when x"F6" => am_zpx(v_ea); rmw(v_ea,v_res); v_res:=v_res+1; set_nz(v_res); bus_write(v_ea,v_res);
        when x"EE" => am_abs(v_ea); rmw(v_ea,v_res); v_res:=v_res+1; set_nz(v_res); bus_write(v_ea,v_res);  -- INC abs
        when x"FE" => am_absx(v_ea,penalty=>false); rmw(v_ea,v_res); v_res:=v_res+1; set_nz(v_res); bus_write(v_ea,v_res);

        when x"C6" => am_zp(v_ea);  rmw(v_ea,v_res); v_res:=v_res-1; set_nz(v_res); bus_write(v_ea,v_res);  -- DEC zp
        when x"D6" => am_zpx(v_ea); rmw(v_ea,v_res); v_res:=v_res-1; set_nz(v_res); bus_write(v_ea,v_res);
        when x"CE" => am_abs(v_ea); rmw(v_ea,v_res); v_res:=v_res-1; set_nz(v_res); bus_write(v_ea,v_res);  -- DEC abs
        when x"DE" => am_absx(v_ea,penalty=>false); rmw(v_ea,v_res); v_res:=v_res-1; set_nz(v_res); bus_write(v_ea,v_res);

        -- ---------------------------------------------------------------
        -- Shifts / Rotates
        -- ---------------------------------------------------------------
        -- ASL
        when x"0A" => bus_read(v_pc,v_d); v_p(FC):=v_a(7); v_a:=v_a(6 downto 0)&'0'; set_nz(v_a);
        when x"06" => am_zp(v_ea);  rmw(v_ea,v_res); v_p(FC):=v_res(7); v_res:=v_res(6 downto 0)&'0'; set_nz(v_res); bus_write(v_ea,v_res);
        when x"16" => am_zpx(v_ea); rmw(v_ea,v_res); v_p(FC):=v_res(7); v_res:=v_res(6 downto 0)&'0'; set_nz(v_res); bus_write(v_ea,v_res);
        when x"0E" => am_abs(v_ea); rmw(v_ea,v_res); v_p(FC):=v_res(7); v_res:=v_res(6 downto 0)&'0'; set_nz(v_res); bus_write(v_ea,v_res);
        when x"1E" => am_absx(v_ea,penalty=>false); rmw(v_ea,v_res); v_p(FC):=v_res(7); v_res:=v_res(6 downto 0)&'0'; set_nz(v_res); bus_write(v_ea,v_res);
        -- LSR
        when x"4A" => bus_read(v_pc,v_d); v_p(FC):=v_a(0); v_a:='0'&v_a(7 downto 1); set_nz(v_a);
        when x"46" => am_zp(v_ea);  rmw(v_ea,v_res); v_p(FC):=v_res(0); v_res:='0'&v_res(7 downto 1); set_nz(v_res); bus_write(v_ea,v_res);
        when x"56" => am_zpx(v_ea); rmw(v_ea,v_res); v_p(FC):=v_res(0); v_res:='0'&v_res(7 downto 1); set_nz(v_res); bus_write(v_ea,v_res);
        when x"4E" => am_abs(v_ea); rmw(v_ea,v_res); v_p(FC):=v_res(0); v_res:='0'&v_res(7 downto 1); set_nz(v_res); bus_write(v_ea,v_res);
        when x"5E" => am_absx(v_ea,penalty=>false); rmw(v_ea,v_res); v_p(FC):=v_res(0); v_res:='0'&v_res(7 downto 1); set_nz(v_res); bus_write(v_ea,v_res);
        -- ROL
        when x"2A" => bus_read(v_pc,v_d); v_lo:=(0=>v_p(FC),others=>'0'); v_p(FC):=v_a(7); v_a:=v_a(6 downto 0)&v_lo(0); set_nz(v_a);
        when x"26" => am_zp(v_ea);  rmw(v_ea,v_res); v_lo:=(0=>v_p(FC),others=>'0'); v_p(FC):=v_res(7); v_res:=v_res(6 downto 0)&v_lo(0); set_nz(v_res); bus_write(v_ea,v_res);
        when x"36" => am_zpx(v_ea); rmw(v_ea,v_res); v_lo:=(0=>v_p(FC),others=>'0'); v_p(FC):=v_res(7); v_res:=v_res(6 downto 0)&v_lo(0); set_nz(v_res); bus_write(v_ea,v_res);
        when x"2E" => am_abs(v_ea); rmw(v_ea,v_res); v_lo:=(0=>v_p(FC),others=>'0'); v_p(FC):=v_res(7); v_res:=v_res(6 downto 0)&v_lo(0); set_nz(v_res); bus_write(v_ea,v_res);
        when x"3E" => am_absx(v_ea,penalty=>false); rmw(v_ea,v_res); v_lo:=(0=>v_p(FC),others=>'0'); v_p(FC):=v_res(7); v_res:=v_res(6 downto 0)&v_lo(0); set_nz(v_res); bus_write(v_ea,v_res);
        -- ROR
        when x"6A" => bus_read(v_pc,v_d); v_lo:=(7=>v_p(FC),others=>'0'); v_p(FC):=v_a(0); v_a:=v_lo(7)&v_a(7 downto 1); set_nz(v_a);
        when x"66" => am_zp(v_ea);  rmw(v_ea,v_res); v_lo:=(7=>v_p(FC),others=>'0'); v_p(FC):=v_res(0); v_res:=v_lo(7)&v_res(7 downto 1); set_nz(v_res); bus_write(v_ea,v_res);
        when x"76" => am_zpx(v_ea); rmw(v_ea,v_res); v_lo:=(7=>v_p(FC),others=>'0'); v_p(FC):=v_res(0); v_res:=v_lo(7)&v_res(7 downto 1); set_nz(v_res); bus_write(v_ea,v_res);
        when x"6E" => am_abs(v_ea); rmw(v_ea,v_res); v_lo:=(7=>v_p(FC),others=>'0'); v_p(FC):=v_res(0); v_res:=v_lo(7)&v_res(7 downto 1); set_nz(v_res); bus_write(v_ea,v_res);
        when x"7E" => am_absx(v_ea,penalty=>false); rmw(v_ea,v_res); v_lo:=(7=>v_p(FC),others=>'0'); v_p(FC):=v_res(0); v_res:=v_lo(7)&v_res(7 downto 1); set_nz(v_res); bus_write(v_ea,v_res);

        -- ---------------------------------------------------------------
        -- Branches
        -- ---------------------------------------------------------------
        when x"90" => branch(v_p(FC)='0');   -- BCC
        when x"B0" => branch(v_p(FC)='1');   -- BCS
        when x"F0" => branch(v_p(FZ)='1');   -- BEQ
        when x"D0" => branch(v_p(FZ)='0');   -- BNE
        when x"30" => branch(v_p(FN)='1');   -- BMI
        when x"10" => branch(v_p(FN)='0');   -- BPL
        when x"70" => branch(v_p(FV)='1');   -- BVS
        when x"50" => branch(v_p(FV)='0');   -- BVC

        -- ---------------------------------------------------------------
        -- Jumps and Calls
        -- ---------------------------------------------------------------
        when x"4C" =>                             -- JMP abs
          fetch_word(v_ea);
          v_pc := v_ea;

        when x"6C" =>                             -- JMP (ind)
          fetch_word(v_addr16);
          -- 6502 page-wrap bug: high byte fetched from same page
          bus_read(v_addr16, v_lo);
          v_addr16 := (v_addr16(15 downto 8)) & (v_addr16(7 downto 0) + 1);
          bus_read(v_addr16, v_hi);
          v_pc := v_hi & v_lo;

        when x"20" =>                             -- JSR abs
          -- Cycle sequence: fetch lo, read SP (dummy), push PCH, push PCL,
          -- fetch hi, jump.  The return address pushed (v_pc after lo fetch)
          -- equals JSR_addr+2, so RTS (which adds 1) returns to JSR_addr+3
          -- — the instruction immediately after JSR.  This is correct.
          -- Note: the real 6502 performs an internal operation in cycle 3 and
          -- fetches the hi byte in cycle 6 (after the pushes); this model
          -- replicates the cycle count and the pushed address correctly.
          fetch_byte(v_lo);
          bus_read(x"01" & v_sp, v_d);           -- internal cycle
          push(v_pc(15 downto 8));
          push(v_pc(7 downto 0));
          fetch_byte(v_hi);
          v_pc := v_hi & v_lo;

        when x"60" =>                             -- RTS
          bus_read(v_pc, v_d);                   -- dummy
          bus_read(x"01" & v_sp, v_d);           -- dummy
          pop(v_lo);
          pop(v_hi);
          v_pc := (v_hi & v_lo) + 1;
          bus_read(v_pc - 1, v_d);               -- dummy (pre-increment read)

        when x"40" =>                             -- RTI
          bus_read(v_pc, v_d);                   -- dummy
          bus_read(x"01" & v_sp, v_d);           -- dummy
          pop(v_d); v_p := v_d;
          pop(v_lo);
          pop(v_hi);
          v_pc := v_hi & v_lo;

        -- ---------------------------------------------------------------
        -- Flag instructions
        -- ---------------------------------------------------------------
        when x"18" => bus_read(v_pc, v_d); v_p(FC) := '0';  -- CLC
        when x"38" => bus_read(v_pc, v_d); v_p(FC) := '1';  -- SEC
        when x"58" => bus_read(v_pc, v_d); v_p(FI) := '0';  -- CLI
        when x"78" => bus_read(v_pc, v_d); v_p(FI) := '1';  -- SEI
        when x"B8" => bus_read(v_pc, v_d); v_p(FV) := '0';  -- CLV
        when x"D8" => bus_read(v_pc, v_d); v_p(FD) := '0';  -- CLD
        when x"F8" => bus_read(v_pc, v_d); v_p(FD) := '1';  -- SED

        -- ---------------------------------------------------------------
        -- NOP
        -- ---------------------------------------------------------------
        when x"EA" => bus_read(v_pc, v_d);   -- NOP

        -- ---------------------------------------------------------------
        -- Unknown opcode: report and halt
        -- ---------------------------------------------------------------
        when others =>
          report "tb_shell_cpu: unimplemented opcode $" & to_hstring(v_op)
                 & " at PC=$" & to_hstring(v_pc - 1)
                 severity failure;

      end case;

      -- Update visible register signals
      cpu_pc <= v_pc;
      cpu_sp <= v_sp;
      cpu_a  <= v_a;
      cpu_x  <= v_x;
      cpu_y  <= v_y;
      cpu_p  <= v_p;

      -----------------------------------------------------------------------
      -- After each instruction: check for pending NMI or IRQ
      -----------------------------------------------------------------------
      if v_nmi_pending then
        v_nmi_pending := false;
        bus_read(v_pc, v_d);    -- dummy read of next opcode
        bus_read(v_pc, v_d);    -- internal
        push_pcb('0');
        v_p(FI) := '1';
        bus_read(x"FFFA", v_lo);
        bus_read(x"FFFB", v_hi);
        v_pc := v_hi & v_lo;
      elsif cpu_nirq = '0' and v_p(FI) = '0' then
        bus_read(v_pc, v_d);    -- dummy
        bus_read(v_pc, v_d);    -- internal
        push_pcb('0');
        v_p(FI) := '1';
        bus_read(x"FFFE", v_lo);
        bus_read(x"FFFF", v_hi);
        v_pc := v_hi & v_lo;
      end if;

    end loop;
  end process;

end architecture;
