library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity qclk_pll is
    Port (
        phi2            : in  STD_LOGIC;
        nres            : in  STD_LOGIC;
        qclk            : out STD_LOGIC;
        phi2x8          : out STD_LOGIC;
        phi2falling_en  : out STD_LOGIC;
        phi2rising_en   : out STD_LOGIC;
        locked          : out STD_LOGIC
    );
end qclk_pll;
