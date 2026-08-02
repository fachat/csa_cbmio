library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.reg_script_pkg.all;

entity tb_uart_shell is
  generic (
    script_file : string := "scripts/uart_script.txt"
  );
end entity;

architecture tb of tb_uart_shell is
  signal phi2 : std_logic := '0';
  signal rwb  : std_logic := '1';
  signal nres : std_logic := '0';
  signal sel  : std_logic := '0';
  signal addr : std_logic_vector(2 downto 0) := (others => '0');
  signal din  : std_logic_vector(7 downto 0) := (others => '0');
  signal dout : std_logic_vector(7 downto 0);
  signal irq  : std_logic;

  signal rx  : std_logic := '1';
  signal tx  : std_logic;
  signal cts : std_logic := '0';
  signal rts : std_logic;
  signal dsr : std_logic := '0';
  signal dtr : std_logic;
  signal ri  : std_logic := '0';
  signal dcd : std_logic := '0';
begin
  dut: entity work.uart_shell
    port map (
      phi2 => phi2,
      rwb => rwb,
      nres => nres,
      sel => sel,
      addr => addr,
      din => din,
      dout => dout,
      irq => irq,
      rx => rx,
      tx => tx,
      cts => cts,
      rts => rts,
      dsr => dsr,
      dtr => dtr,
      ri => ri,
      dcd => dcd
    );

  clk_p: process
  begin
    loop
      phi2 <= '0';
      wait for 5 ns;
      phi2 <= '1';
      wait for 5 ns;
    end loop;
  end process;

  rst_p: process
  begin
    wait for 35 ns;
    nres <= '1';
    wait;
  end process;

  stim_p: process
    variable cmds      : cmd_array_t;
    variable cmd_count : natural := 0;
    variable cmd_idx   : natural := 0;
    variable cycle     : natural := 0;
    variable max_cycle : natural := 0;
    variable cmd       : cmd_t;
  begin
    init_cmds(cmds);
    load_script(script_file, cmds, cmd_count);

    for i in 0 to cmd_count - 1 loop
      if cmds(i).cycle > max_cycle then
        max_cycle := cmds(i).cycle;
      end if;
    end loop;

    wait until nres = '1';

    while cycle <= max_cycle + 4 loop
      wait until rising_edge(phi2);
      sel <= '0';
      rwb <= '1';

      if (cmd_idx < cmd_count) and cmds(cmd_idx).valid and (cmds(cmd_idx).cycle = cycle) then
        cmd := cmds(cmd_idx);
        addr <= to_slv(cmd.addr, 3);
        din <= cmd.data;

        case cmd.op is
          when OP_WRITE =>
            sel <= '1';
            rwb <= '0';
            report "UART cycle " & integer'image(integer(cycle)) & ": WRITE addr=" & integer'image(integer(cmd.addr)) &
                   " data=" & integer'image(to_integer(unsigned(cmd.data)));
          when OP_READ =>
            sel <= '1';
            rwb <= '1';
            report "UART cycle " & integer'image(integer(cycle)) & ": READ addr=" & integer'image(integer(cmd.addr));
          when others =>
            report "UART cycle " & integer'image(integer(cycle)) & ": PAUSE";
        end case;

        cmd_idx := cmd_idx + 1;
      end if;

      cycle := cycle + 1;
    end loop;

    report "UART simulation complete";
    finish;
  end process;
end architecture;
