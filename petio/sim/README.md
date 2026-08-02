# PETIO IC simulation scripts (GHDL)

This folder provides cycle-driven GHDL testbenches for:

- `via6522`
- `pia6520`
- `uart_shell`

## Script format

Each line defines one cycle action:

```text
<cycle> <op> [addr] [data]
```

- `cycle`: non-negative integer, strictly increasing
- `op`:
  - `W` write register (`addr` + `data` required)
  - `R` read register (`addr` required)
  - `N` no bus operation (pause)
- `addr`: register index in decimal
- `data`: byte value (0..255) in decimal

Blank lines and lines starting with `#` are ignored.

Pauses can be modeled in two ways:
- by using explicit `N` lines
- by leaving gaps between cycle numbers

## Run

From `/home/runner/work/csa_cbmio/csa_cbmio/petio/sim`:

- `make via`
- `make pia`
- `make uart`

Override script file:

- `make via SCRIPT=scripts/my_via.txt`
