
# CBM-IO

Note: this is a part of a larger set of repositories, with [upet_family](https://github.com/fachat/upet_family) as the main repository.

This is the IO board for a re-incarnation of the Commodore PET and B-Series to be used together with the Ultra-CPU board.

It is build on a Eurocard board and has only parts that can still be obtained new in 2025. In fact it uses an FPGA to emulate all the I/O chips of the PET or the B-Series.
It uses the [CS/A bus interface](http://www.6502.org/users/andre/csa/index.html) to connect with the CPU board.

The board at this time can only be programmed as I/O board for the PET, where it includes the original PET I/O (except the 2nd Tape), 
plus the extensions added in the [Ulti-PET](https://github.com/fachat/cbm_ultipet), namely the UART RS232 interfaces and the 2nd
VIA with the IEC bus interface. The VHDL code for this is found in the petio/ folder.

In the future there will be a second option to program the FPGA on the board for the I/O of the B-series.

Note: this is a work in progress!

![The board](images/newboard.jpg)

## Features


## Contributions

### VIA 6522

The VIA6522 is coming from Rhialto's Mega65 code at https://github.com/Rhialto/MegaPET/blob/rhialto/CORE/PET2001_MiSTer/rtl/via6522.vhd
which in turns originates from Gideon Zweijtzer.

I had to adapt it to the single Phi2 clock input though.

In the meantime it has been mostly rewritten esp. in the timer and shift register parts, along the lines
of the chip dissection from http://forum.6502.org .

### UART 16550

The UART seems to be a common 16550 core, made for the Wishbone bus.
it is taken from the Microwatt project https://github.com/antonblanchard/microwatt
and seems to originate from http://www.opencores.org/cores/uart16550/ but that page is not found anymore.

I again had to adapt it to the 6502 bus interface.


## Thanks

Many thanks go to Frank "androSID" Wolf and Dieter "ttlworks" Müller from the
[6502.org forum](https://forum.6502.org), who dissected the PIA and VIA chips (and many more).
This is an outstanding work and absolutely helpful in understanding how the chips work internally.

The relevant chip dissections are

- [VIA dissection](https://6502.org/forum/viewtopic.php?f=4&t=7241)
- [PIA dissection](https://6502.org/forum/viewtopic.php?f=4&t=7425)

For your interest, the full list of chip dissection is here [here on the forum](https://6502.org/forum/viewtopic.php?t=7427)

