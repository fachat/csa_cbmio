-------------------------------------------------------------------------------
-- Title      : VIA 6522 Serial block
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity via6522_ser is
port (
    phi2            : in  std_logic;
    phi2x8          : in  std_logic;
    phi2falling_en  : in  std_logic;
    phi2rising_en   : in  std_logic;
    reset           : in  std_logic;
    acr             : in  std_logic_vector(7 downto 0);
    irq_flag2       : in  std_logic;
    addr            : in  std_logic_vector(3 downto 0);
    wen             : in  std_logic;
    ren             : in  std_logic;
    data_in         : in  std_logic_vector(7 downto 0);
    cb1_pos         : in  std_logic;
    cb1_neg         : in  std_logic;
    cb2_d1          : in  std_logic;
    timer_b_sr_tick : in  std_logic;
    shift_reg       : out std_logic_vector(7 downto 0);
    serial_event    : out std_logic;
    serport_en      : out std_logic;
    ser_cb2_o       : out std_logic;
    cb1_t_int       : out std_logic;
    cb1_o_int       : out std_logic);
end via6522_ser;

architecture rtl of via6522_ser is
    alias shift_dir          : std_logic is acr(4);
    alias shift_mode_control : std_logic_vector(2 downto 0) is acr(4 downto 2);

    signal shift_reg_i              : std_logic_vector(7 downto 0) := X"00";
    signal serial_event_i           : std_logic := '0';
    signal serport_en_i             : std_logic := '0';
    signal ser_cb2_o_i              : std_logic := '0';
    signal cb1_t_int_i              : std_logic := '0';
    signal cb1_o_int_i              : std_logic := '0';
    signal sr_running               : std_logic;
    signal sr_shift                 : std_logic;
    signal sr_uses_t2               : std_logic;
    signal sr_uses_phi2             : std_logic;
    signal sr_uses_ext_clk          : std_logic;
    signal sr_disabled              : std_logic;
    signal sr_is_output             : std_logic;
    signal sr_free_running          : std_logic;
    signal sr_toggle_clk_output     : std_logic;
    signal sr_toggle_clk_output_d   : std_logic;
    signal sr_cb1_q                 : std_logic;
    signal sr_wr                    : std_logic;
    signal sr_rd                    : std_logic;
    signal sr_bit_cnt               : integer range 0 to 8;
    signal sr_last_bit              : std_logic;
begin
    shift_reg <= shift_reg_i;
    serial_event <= serial_event_i;
    serport_en <= serport_en_i;
    ser_cb2_o <= ser_cb2_o_i;
    cb1_t_int <= cb1_t_int_i;
    cb1_o_int <= cb1_o_int_i;

    sr_uses_t2 <= '1' when shift_mode_control = "100" or acr(3 downto 2) = "01" else '0';
    sr_uses_phi2 <= not(acr(2)) and acr(3);
    sr_uses_ext_clk <= acr(2) and acr(3);
    sr_disabled <= not(acr(2)) and not(acr(3)) and not(acr(4));
    sr_is_output <= acr(4);
    sr_free_running <= acr(4) and not(acr(3)) and not(acr(2));

    sr_wr <= '1' when wen='1' and addr=x"A" else '0';
    sr_rd <= '1' when ren='1' and addr=x"A" else '0';

    cb1_t_int_i <= '0' when sr_disabled = '1' or sr_uses_ext_clk = '1' else '1';
    serport_en_i <= not(sr_disabled);
    cb1_o_int_i <= sr_cb1_q;

    sr_control: process(phi2)
    begin
			-- sr_disabled is falling (but acr)
			-- sr_uses_t2 is falling (but acr)
			-- irq_flag2 is ???
			--> sr_toggle_clk_output is falling
        if (falling_edge(phi2)) then
            sr_toggle_clk_output <= '0';
            if (sr_disabled = '0' and irq_flag2 = '0') then
                if (sr_uses_phi2 = '1') then
                    sr_toggle_clk_output <= '1';
                elsif (sr_uses_t2 = '1') then
                    sr_toggle_clk_output <= timer_b_sr_tick;
                end if;
            end if;
        end if;

			-- sr_toggle_clk_output is falling
			--> sr_toggle_clk_output_d is rising
        if (rising_edge(phi2)) then
            sr_toggle_clk_output_d <= sr_toggle_clk_output;
        end if;

			-- sr_running is falling XXX!
			-- sr_toggle_clk_output_d is rising
			--> sr_cb1_q is falling
        if (falling_edge(phi2)) then
            if (sr_running = '0') then
                sr_cb1_q <= '1';
            elsif (sr_toggle_clk_output_d = '1') then
                sr_cb1_q <= not(sr_cb1_q);
            end if;
        end if;

			-- sr_disabled is falling but acr
			-- sr_wr is valid at falling
			-- sr_rd is valid at falling
			-- irq_flag2 is ???
			--> sr_running is falling
        if (falling_edge(phi2)) then
            if (sr_wr = '1' or sr_rd = '1') then
                sr_running <= '1';
            elsif (irq_flag2 = '1' or sr_disabled = '1') then
                sr_running <= '0';
            end if;
        end if;

			-- irq_flag2 is ???
			-- sr_wr is valid at falling edge
			--> sr_shift is falling
        if (falling_edge(phi2)) then
            if (irq_flag2 = '1') then
                sr_shift <= '0';
            elsif (sr_wr = '1') then
                sr_shift <= '0';
            else
                if (sr_is_output = '1') then
                    sr_shift <= cb1_neg;
                else
                    sr_shift <= cb1_pos;
                end if;
            end if;
        end if;

			-- sr_running is falling XXX
			-- sr_shift is falling XXX
			-- sr_free_running is falling but acr
			-- sr_bit_cnt is ???
			--> serial_event_i is falling
			--> sr_bit_cnt is falling
			--> sr_last_bit is falling
        if (falling_edge(phi2)) then
            if (sr_running = '0') then
                sr_bit_cnt <= 8;
            elsif (sr_shift = '1' and sr_bit_cnt /= 0) then
                sr_bit_cnt <= sr_bit_cnt - 1;
            end if;

            serial_event_i <= '0';
            if (sr_bit_cnt = 0 and serial_event_i = '0') then
                sr_last_bit <= '1';
                if (sr_free_running = '0') then
                    if (sr_cb1_q = '1' or sr_uses_ext_clk = '1') then
                        serial_event_i <= '1';
                    end if;
                end if;
            else
                sr_last_bit <= '0';
            end if;
        end if;
    end process;

    sr: process(phi2)
    begin
			-- data_in is valid at falling
			-- wen,addr is valid at falling
			-- sr_is_output is falling but acr
			--> shift_reg_i is falling
        if (falling_edge(phi2)) then
            if reset = '1' then
                shift_reg_i <= X"FF";
            else
                if wen = '1' and addr = X"A" then
                    shift_reg_i <= data_in;
                elsif sr_shift = '1' then
                    if (sr_is_output = '1') then
                        shift_reg_i <= shift_reg_i(6 downto 0) & shift_reg_i(7);
                    else
                        shift_reg_i <= shift_reg_i(6 downto 0) & cb2_d1;
                    end if;
                end if;
            end if;

            ser_cb2_o_i <= shift_reg_i(7);
        end if;
    end process;
end rtl;
