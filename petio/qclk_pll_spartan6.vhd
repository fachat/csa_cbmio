library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

architecture spartan6 of qclk_pll is

    signal clk16_raw    : std_logic;
    signal clk16        : std_logic;
    signal phi2x8_raw   : std_logic;
    signal phi2x8_int   : std_logic;
    signal qclk_raw     : std_logic;
    signal dcm1_locked  : std_logic;
    signal dcm2_locked  : std_logic;
    signal dcm1_status  : std_logic_vector(1 downto 0);
    signal dcm2_status  : std_logic_vector(1 downto 0);
    signal phi2_phase      : integer range 0 to 7 := 0;
    signal phi2_sync       : std_logic := '1';
    signal phi2_sync_prev  : std_logic := '1';
    signal phase_valid     : std_logic := '0';

begin

    dcm_16x: DCM_CLKGEN
        generic map (
            CLKFXDV_DIVIDE => 2,
            CLKFX_DIVIDE   => 1,
            CLKFX_MD_MAX   => 0.0,
            CLKFX_MULTIPLY => 16,
            CLKIN_PERIOD   => 1000.0,
            SPREAD_SPECTRUM => "NONE",
            STARTUP_WAIT   => FALSE
        )
        port map (
            CLKFX      => clk16_raw,
            CLKFX180   => open,
            CLKFXDV    => phi2x8_raw,
            LOCKED     => dcm1_locked,
            PROGDONE   => open,
            STATUS     => dcm1_status,
            CLKIN      => phi2,
            FREEZEDCM  => '0',
            PROGCLK    => '0',
            PROGDATA   => '0',
            PROGEN     => '0',
            RST        => not nres
        );

    clk16_bufg: BUFG
        port map (
            I => clk16_raw,
            O => clk16
        );

    phi2x8_bufg: BUFG
        port map (
            I => phi2x8_raw,
            O => phi2x8_int
        );

    dcm_qclk: DCM_CLKGEN
        generic map (
            CLKFXDV_DIVIDE => 2,
            CLKFX_DIVIDE   => 125,
            CLKFX_MD_MAX   => 0.0,
            CLKFX_MULTIPLY => 144,
            CLKIN_PERIOD   => 62.5,
            SPREAD_SPECTRUM => "NONE",
            STARTUP_WAIT   => FALSE
        )
        port map (
            CLKFX      => qclk_raw,
            CLKFX180   => open,
            CLKFXDV    => open,
            LOCKED     => dcm2_locked,
            PROGDONE   => open,
            STATUS     => dcm2_status,
            CLKIN      => clk16,
            FREEZEDCM  => '0',
            PROGCLK    => '0',
            PROGDATA   => '0',
            PROGEN     => '0',
            RST        => (not nres) or (not dcm1_locked)
        );

    qclk_bufg: BUFG
        port map (
            I => qclk_raw,
            O => qclk
        );

    phi2x8 <= phi2x8_int;
    phi2falling_en <= '1' when phase_valid = '1' and phi2_phase = 0 else '0';
    phi2rising_en <= '1' when phase_valid = '1' and phi2_phase = 4 else '0';

    phase_p: process(phi2x8_int, nres)
        variable next_phase : integer range 0 to 7;
    begin
        if (nres = '0' or dcm1_locked = '0') then
            phi2_phase <= 0;
            phi2_sync <= '1';
            phi2_sync_prev <= '1';
            phase_valid <= '0';
        elsif (falling_edge(phi2x8_int)) then
            next_phase := phi2_phase;
            phi2_sync <= phi2;
            phi2_sync_prev <= phi2_sync;

            if (phase_valid = '1') then
                if (phi2_phase = 7) then
                    next_phase := 0;
                else
                    next_phase := phi2_phase + 1;
                end if;
            end if;

            if (phi2_sync_prev = '1' and phi2_sync = '0') then
                next_phase := 0;
                phase_valid <= '1';
            end if;

            phi2_phase <= next_phase;
        end if;
    end process;

    locked <= dcm1_locked and dcm2_locked;

end spartan6;
