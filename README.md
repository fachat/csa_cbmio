
# CBM-IO

Note: this is a part of a larger set of repositories, with [upet_family](https://github.com/fachat/upet_family) as the main repository.

This is the IO board for a re-incarnation of the Commodore B-Series to be used together with the Ultra-CPU board.

It is build on a Eurocard board and has only parts that can still be obtained new in 2025. In fact it uses an FPGA to emulate all the I/O chips of the B-Series.
It uses the [CS/A bus interface](http://www.6502.org/users/andre/csa/index.html) to connect with the CPU board.

Note: this is a work in progress!

![The board](images/newboard.jpg)

## Features


## Contributions

### VIA 6522

The VIA6522 is coming from Rhialto's Mega65 code at https://github.com/Rhialto/MegaPET/blob/rhialto/CORE/PET2001_MiSTer/rtl/via6522.vhd
which in turns originates from Gideon Zweijtzer.

I had to adapt it to the single Phi2 clock input though.

### UART 16550

The UART seems to be a common 16550 core, made for the Wishbone bus.
it is taken from the Microwatt project https://github.com/antonblanchard/microwatt
and seems to originate from http://www.opencores.org/cores/uart16550/ but that page is not found anymore.

I again had to adapt it to the 6502 bus interface.

