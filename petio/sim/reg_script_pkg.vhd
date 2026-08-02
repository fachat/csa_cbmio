library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

package reg_script_pkg is
  constant MAX_CMDS : natural := 4096;

  type op_t is (OP_NONE, OP_READ, OP_WRITE);

  type cmd_t is record
    cycle : natural;
    op    : op_t;
    addr  : natural;
    data  : std_logic_vector(7 downto 0);
    valid : boolean;
  end record;

  type cmd_array_t is array (0 to MAX_CMDS - 1) of cmd_t;

  procedure init_cmds(variable cmds : out cmd_array_t);
  procedure load_script(
    constant filename : in string;
    variable cmds     : out cmd_array_t;
    variable count    : out natural
  );

  function to_slv(value : natural; width : positive) return std_logic_vector;
end package;

package body reg_script_pkg is
  function to_slv(value : natural; width : positive) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(value, width));
  end function;

  procedure init_cmds(variable cmds : out cmd_array_t) is
  begin
    for i in cmds'range loop
      cmds(i).cycle := 0;
      cmds(i).op := OP_NONE;
      cmds(i).addr := 0;
      cmds(i).data := (others => '0');
      cmds(i).valid := false;
    end loop;
  end procedure;

  procedure load_script(
    constant filename : in string;
    variable cmds     : out cmd_array_t;
    variable count    : out natural
  ) is
    file f       : text open read_mode is filename;
    variable l   : line;
    variable raw : line;
    variable ok  : boolean;
    variable cyc : integer;
    variable adr : integer;
    variable dat : integer;
    variable opc : character;
    variable opstr : string(1 to 1);
    variable idx : natural := 0;
    variable last_cycle : integer := -1;
    variable hash_pos : integer;
  begin
    count := 0;

    while not endfile(f) loop
      readline(f, raw);
      hash_pos := 0;
      for i in raw.all'range loop
        if raw.all(i) = '#' then
          hash_pos := i;
          exit;
        end if;
      end loop;

      if hash_pos /= 0 then
        if hash_pos = raw.all'low then
          next;
        end if;
        l := new string'(raw.all(raw.all'low to hash_pos - 1));
      else
        l := new string'(raw.all);
      end if;

      if l'length = 0 then
        next;
      end if;

      read(l, cyc, ok);
      if not ok then
        next;
      end if;

      read(l, opstr, ok);
      if not ok then
        assert false report "Invalid script line (missing operation)" severity failure;
      end if;
      opc := opstr(1);

      if cyc < 0 then
        assert false report "Negative cycle in script" severity failure;
      end if;

      if cyc <= last_cycle then
        assert false report "Script cycles must be strictly increasing" severity failure;
      end if;
      last_cycle := cyc;

      if idx > cmds'high then
        assert false report "Script too large" severity failure;
      end if;

      cmds(idx).cycle := natural(cyc);
      cmds(idx).valid := true;

      case opc is
        when 'N' | 'n' =>
          cmds(idx).op := OP_NONE;
          cmds(idx).addr := 0;
          cmds(idx).data := (others => '0');

        when 'R' | 'r' =>
          read(l, adr, ok);
          if (not ok) or adr < 0 then
            assert false report "Invalid read address in script" severity failure;
          end if;
          cmds(idx).op := OP_READ;
          cmds(idx).addr := natural(adr);
          cmds(idx).data := (others => '0');

        when 'W' | 'w' =>
          read(l, adr, ok);
          if (not ok) or adr < 0 then
            assert false report "Invalid write address in script" severity failure;
          end if;
          read(l, dat, ok);
          if (not ok) or dat < 0 or dat > 255 then
            assert false report "Invalid write data in script (expected 0..255)" severity failure;
          end if;
          cmds(idx).op := OP_WRITE;
          cmds(idx).addr := natural(adr);
          cmds(idx).data := std_logic_vector(to_unsigned(dat, 8));

        when others =>
          assert false report "Invalid operation in script (opc='" & opc & "', use R/W/N)" severity failure;
      end case;

      idx := idx + 1;
    end loop;

    count := idx;
  end procedure;
end package body;
