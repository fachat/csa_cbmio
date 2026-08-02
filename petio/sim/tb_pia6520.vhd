library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.reg_script_pkg.all;

entity tb_pia6520 is
  generic (
    script_file : string := "scripts/pia_script.txt"
  );
end entity;

architecture tb of tb_pia6520 is
  signal nres      : std_logic := '0';
  signal phi2      : std_logic := '0';
  signal rwb       : std_logic := '1';
  signal sel       : std_logic := '0';
  signal irq       : std_logic;
  signal addr      : std_logic_vector(1 downto 0) := (others => '0');
  signal data_in   : std_logic_vector(7 downto 0) := (others => '0');
  signal data_out  : std_logic_vector(7 downto 0);

  signal porta_in  : std_logic_vector(7 downto 0) := x"3c";
  signal porta_dir : std_logic_vector(7 downto 0);
  signal porta_out : std_logic_vector(7 downto 0);
  signal ca1_in    : std_logic := '1';
  signal ca2_in    : std_logic := '1';
  signal ca2_out   : std_logic;

  signal portb_in  : std_logic_vector(7 downto 0) := x"a5";
  signal portb_out : std_logic_vector(7 downto 0);
  signal portb_dir : std_logic_vector(7 downto 0);
  signal cb1_in    : std_logic := '1';
  signal cb2_in    : std_logic := '1';
  signal cb2_out   : std_logic;
begin
  dut: entity work.pia6520
    port map (
      nres => nres,
      phi2 => phi2,
      rwb => rwb,
      sel => sel,
      irq => irq,
      addr => addr,
      data_in => data_in,
      data_out => data_out,
      porta_in => porta_in,
      porta_dir => porta_dir,
      porta_out => porta_out,
      ca1_in => ca1_in,
      ca2_in => ca2_in,
      ca2_out => ca2_out,
      portb_in => portb_in,
      portb_out => portb_out,
      portb_dir => portb_dir,
      cb1_in => cb1_in,
      cb2_in => cb2_in,
      cb2_out => cb2_out
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
        addr <= to_slv(cmd.addr, 2);
        data_in <= cmd.data;

        case cmd.op is
          when OP_WRITE =>
            sel <= '1';
            rwb <= '0';
            report "PIA cycle " & integer'image(integer(cycle)) & ": WRITE addr=" & integer'image(integer(cmd.addr)) &
                   " data=" & integer'image(to_integer(unsigned(cmd.data)));
          when OP_READ =>
            sel <= '1';
            rwb <= '1';
            report "PIA cycle " & integer'image(integer(cycle)) & ": READ addr=" & integer'image(integer(cmd.addr));
          when others =>
            report "PIA cycle " & integer'image(integer(cycle)) & ": PAUSE";
        end case;

        cmd_idx := cmd_idx + 1;
      end if;

      cycle := cycle + 1;
    end loop;

    report "PIA simulation complete";
    finish;
  end process;
end architecture;
