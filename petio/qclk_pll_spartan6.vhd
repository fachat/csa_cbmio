library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

architecture spartan6 of qclk_pll is

    signal clk16_raw    : std_logic;
    signal clk16        : std_logic;
    signal qclk_raw     : std_logic;
    signal dcm1_locked  : std_logic;
    signal dcm2_locked  : std_logic;
    signal dcm1_status  : std_logic_vector(1 downto 0);
    signal dcm2_status  : std_logic_vector(1 downto 0);

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
            CLKFXDV    => open,
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

    locked <= dcm1_locked and dcm2_locked;

end spartan6;
