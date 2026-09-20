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
  constant PHI2X8_HALF : time := 62.5 ns;

  signal phi2     : std_logic := '0';
  signal phi2x8   : std_logic := '1';
  signal phi2falling_en : std_logic := '1';
  signal phi2rising_en  : std_logic := '0';
  signal phi2_phase     : integer range 0 to 7 := 0;
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
      phi2x8 => phi2x8,
      phi2falling_en => phi2falling_en,
      phi2rising_en => phi2rising_en,
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
      wait for 500 ns;
      phi2 <= '1';
      wait for 500 ns;
    end loop;
  end process;

  clk8_p: process
  begin
    wait until reset = '0';
    wait until falling_edge(phi2);
    loop
      phi2x8 <= '0';
      wait for PHI2X8_HALF;
      phi2x8 <= '1';
      wait for PHI2X8_HALF;
    end loop;
  end process;

  phase_p: process(phi2x8, reset)
  begin
    if (reset = '1') then
      phi2_phase <= 0;
    elsif (falling_edge(phi2x8)) then
      if (phi2_phase = 7) then
        phi2_phase <= 0;
      else
        phi2_phase <= phi2_phase + 1;
      end if;
    end if;
  end process;

  phi2falling_en <= '1' when phi2_phase = 0 else '0';
  phi2rising_en <= '1' when phi2_phase = 4 else '0';

  phase_check_p: process(phi2x8)
    variable fast_phase : integer range 0 to 7 := 0;
    variable cb1_prev   : std_logic := '1';
  begin
    if (falling_edge(phi2x8)) then
      if (reset = '1') then
        fast_phase := 0;
        cb1_prev := cb1_o;
      else
        assert not (phi2falling_en = '1' and phi2rising_en = '1')
          report "phi2falling_en and phi2rising_en overlap"
          severity failure;

        if (phi2falling_en = '1') then
          assert phi2 = '0'
            report "phi2falling_en is not aligned to phi2 low phase"
            severity failure;
          fast_phase := 0;
        else
          fast_phase := (fast_phase + 1) mod 8;
        end if;

        if (phi2rising_en = '1') then
          assert phi2 = '1'
            report "phi2rising_en is not aligned to phi2 high phase"
            severity failure;
          assert fast_phase = 4
            report "phi2rising_en is not centered between phi2falling_en pulses"
            severity failure;
        end if;

        if (cb1_o /= cb1_prev) then
          assert phi2falling_en = '1'
            report "CB1 changed outside the intended phi2 falling phase"
            severity failure;
        end if;

        cb1_prev := cb1_o;
      end if;
    end if;
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

    if cmd_count > 0 then
      for i in 0 to cmd_count - 1 loop
        if cmds(i).cycle > max_cycle then
          max_cycle := cmds(i).cycle;
        end if;
      end loop;
    end if;

    wait until reset = '0';

    while cycle <= max_cycle + 4 loop
      wait until falling_edge(phi2);
      wen <= '0';
      ren <= '0';

      wait for 100 ns;

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
