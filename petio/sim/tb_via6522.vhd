library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.reg_script_pkg.all;

entity tb_via6522 is
  generic (
    script_file : string := "scripts/via_script.txt"
  );
end entity;

architecture tb of tb_via6522 is
  signal phi2     : std_logic := '0';
  signal reset    : std_logic := '1';
  signal addr     : std_logic_vector(3 downto 0) := (others => '0');
  signal wen      : std_logic := '0';
  signal ren      : std_logic := '0';
  signal data_in  : std_logic_vector(7 downto 0) := (others => '0');
  signal data_out : std_logic_vector(7 downto 0);

  signal port_a_o : std_logic_vector(7 downto 0);
  signal port_a_t : std_logic_vector(7 downto 0);
  signal port_a_i : std_logic_vector(7 downto 0) := x"00";
  signal port_b_o : std_logic_vector(7 downto 0);
  signal port_b_t : std_logic_vector(7 downto 0);
  signal port_b_i : std_logic_vector(7 downto 0) := x"00";

  signal ca1_i : std_logic := '1';
  signal ca2_o : std_logic;
  signal ca2_i : std_logic := '1';
  signal ca2_t : std_logic;
  signal cb1_o : std_logic;
  signal cb1_i : std_logic := '1';
  signal cb1_t : std_logic;
  signal cb2_o : std_logic;
  signal cb2_i : std_logic := '1';
  signal cb2_t : std_logic;
  signal irq   : std_logic;
begin
  dut: entity work.via6522
    port map (
      phi2 => phi2,
      reset => reset,
      addr => addr,
      wen => wen,
      ren => ren,
      data_in => data_in,
      data_out => data_out,
      port_a_o => port_a_o,
      port_a_t => port_a_t,
      port_a_i => port_a_i,
      port_b_o => port_b_o,
      port_b_t => port_b_t,
      port_b_i => port_b_i,
      ca1_i => ca1_i,
      ca2_o => ca2_o,
      ca2_i => ca2_i,
      ca2_t => ca2_t,
      cb1_o => cb1_o,
      cb1_i => cb1_i,
      cb1_t => cb1_t,
      cb2_o => cb2_o,
      cb2_i => cb2_i,
      cb2_t => cb2_t,
      irq => irq
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
    reset <= '0';
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

    wait until reset = '0';

    while cycle <= max_cycle + 4 loop
      wait until rising_edge(phi2);
      wen <= '0';
      ren <= '0';

      if (cmd_idx < cmd_count) and cmds(cmd_idx).valid and (cmds(cmd_idx).cycle = cycle) then
        cmd := cmds(cmd_idx);
        addr <= to_slv(cmd.addr, 4);
        data_in <= cmd.data;

        case cmd.op is
          when OP_WRITE =>
            wen <= '1';
            report "VIA cycle " & integer'image(integer(cycle)) & ": WRITE addr=" & integer'image(integer(cmd.addr)) &
                   " data=" & integer'image(to_integer(unsigned(cmd.data)));
          when OP_READ =>
            ren <= '1';
            report "VIA cycle " & integer'image(integer(cycle)) & ": READ addr=" & integer'image(integer(cmd.addr));
          when others =>
            report "VIA cycle " & integer'image(integer(cycle)) & ": PAUSE";
        end case;

        cmd_idx := cmd_idx + 1;
      end if;

      cycle := cycle + 1;
    end loop;

    report "VIA simulation complete";
    finish;
  end process;
end architecture;
