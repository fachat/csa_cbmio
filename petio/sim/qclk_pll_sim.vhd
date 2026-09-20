library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

architecture sim of qclk_pll is
    signal phi2x8_i    : std_logic := '1';
    signal phi2_phase  : integer range 0 to 7 := 0;
begin

    qclk <= phi2;
    phi2x8 <= phi2x8_i;
    phi2falling_en <= '1' when phi2_phase = 7 else '0';
    phi2rising_en <= '1' when phi2_phase = 3 else '0';
    locked <= nres;

    phi2x8_p: process
    begin
        phi2x8_i <= phi2;
        wait until nres = '1';
        wait until falling_edge(phi2);
        loop
            phi2x8_i <= '0';
            wait for 62.5 ns;
            phi2x8_i <= '1';
            wait for 62.5 ns;
        end loop;
    end process;

    phase_p: process(phi2x8_i, nres)
    begin
        if (nres = '0') then
            phi2_phase <= 0;
        elsif (falling_edge(phi2x8_i)) then
            if (phi2_phase = 7) then
                phi2_phase <= 0;
            else
                phi2_phase <= phi2_phase + 1;
            end if;
        end if;
    end process;

end sim;
