library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_top is
  Port (
    wb_clk_i : in std_logic;

    wb_rst_i : in std_logic;
    wb_adr_i : in std_logic_vector(2 downto 0);
    wb_dat_i : in std_logic_vector(7 downto 0);
    wb_dat_o : out std_logic_vector(7 downto 0);
    wb_we_i  : in std_logic;
    wb_stb_i : in std_logic;
    wb_cyc_i : in std_logic;

    int_o    : out std_logic;

    stx_pad_o : out std_logic;
    srx_pad_i : in std_logic;

    rts_pad_o : out std_logic;
    cts_pad_i : in std_logic;
    dtr_pad_o : out std_logic;
    dsr_pad_i : in std_logic;
    ri_pad_i  : in std_logic;
    dcd_pad_i : in std_logic
  );
end uart_top;

architecture sim of uart_top is
  type reg_array_t is array (0 to 7) of std_logic_vector(7 downto 0);
  signal regs : reg_array_t := (others => (others => '0'));
  signal addr_i : integer range 0 to 7;
begin
  addr_i <= to_integer(unsigned(wb_adr_i));

  process(wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
      if wb_rst_i = '1' then
        regs <= (others => (others => '0'));
        int_o <= '0';
      elsif wb_cyc_i = '1' and wb_stb_i = '1' and wb_we_i = '1' then
        regs(addr_i) <= wb_dat_i;
        int_o <= '1' when addr_i = 1 else '0';
      else
        int_o <= '0';
      end if;
    end if;
  end process;

  wb_dat_o <= regs(addr_i);

  stx_pad_o <= srx_pad_i;
  rts_pad_o <= not cts_pad_i;
  dtr_pad_o <= not (dsr_pad_i and ri_pad_i and dcd_pad_i);
end architecture;
