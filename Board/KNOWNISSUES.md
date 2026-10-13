
# Errata

## Rev 1.1A

- bus interface uses 74LVC245, which are not(!) noise tolerant as their LS/HCT/... siblings. Use 74HCS245 instead (available in same footprint)

## Rev 1.0B

- bus interface uses 74LVC245, which are not(!) noise tolerant as their LS/HCT/... siblings. Use 74HCS245 instead (available in same footprint)
- clock input for the RS232 is missing. Generation from the internal FPGA clockwork may or may not work.

## Rev 1.0A

- bus interface uses 74LVC245, which are not(!) noise tolerant as their LS/HCT/... siblings. Use 74HCS245 instead (available in same footprint)
- clock input for the RS232 is missing. Generation from the internal FPGA clockwork may or may not work.
- Phi2 is not on a global clock input for the FPGA


