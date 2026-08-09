# PETIO IC simulation scripts (GHDL)

This folder provides cycle-driven GHDL testbenches for:

- `via6522`
- `pia6520`
- `uart_shell`
- `Shell` (with a cycle-exact 6502 CPU model)

## Script format

Each line defines one cycle action (used by the via/pia/uart testbenches):

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
- `make shell_cpu ROM=path/to/rom.bin`

Override script file:

- `make via SCRIPT=scripts/my_via.txt`

## Shell CPU testbench (`tb_shell_cpu`)

`tb_shell_cpu.vhd` instantiates the full `Shell.vhd` design and drives it with
the extracted `cpu6502.vhd` cycle-accurate behavioural 6502 CPU model.

### Memory map

| Address range | Description |
|---------------|-------------|
| `$0000–$03FF` | 1 kB RAM |
| `$E800–$E87F` | Shell I/O (`niosel` asserted) |
| `$E000–$FFFF` | 8 kB ROM loaded from `rom_file` (except `$E800–$E87F`, where Shell I/O has priority) |

### ROM loading

The ROM binary is specified via the `rom_file` generic (default: `rom.bin`).
If the binary is smaller than 8 kB it is placed at the **end** of the ROM
region so that the 6502 vector area (`$FFFA–$FFFF`) is always populated.

### Simulation flow

1. `nres` is held low for 8 clock cycles (reset).
2. `nres` is released; the CPU fetches the reset vector from `$FFFC/$FFFD`
   and begins executing ROM code.
3. Simulation ends when the CPU executes a `BRK` instruction (`$00`) or
   after 1 000 000 bus cycles (safety timeout).

### Running

```sh
make shell_cpu ROM=mytest.bin
```

The waveform is written to `shell_cpu.vcd`.

### Test fixture — exposed pin connections

To allow ROM test programs to exercise the I/O ports end-to-end, the
testbench cross-wires certain exposed pins so that writing to one pin and
reading back the opposite pin of the pair exercises the full output→wire→input
path. `std_logic` resolution is used throughout: whichever endpoint is
configured as an output drives the shared node with `'0'` or `'1'`; the
opposite end (configured as an input) drives the node with `'Z'`, which the
resolver ignores.

| Connection | Shell signal A | Shell signal B | Notes |
|---|---|---|---|
| VIA1 PA0 ↔ VIA1 PA1 | `up(0)` | `up(1)` | bidirectional |
| VIA1 PA2 ↔ VIA1 PA3 | `up(2)` | `up(3)` | bidirectional |
| VIA1 PA4 ↔ VIA1 PB3 | `up(7)` | `cwr` | bidirectional |
| VIA1 PA5 ↔ VIA1 PA6 | `up(6)` | `up(5)` | bidirectional |
| PIA1 PA7 ↔ VIA1 CB1 | `up(10)` | `up(12)` | bidirectional |
| PIA1 CA1 ↔ VIA1 CA2 | `c1rd` | `up(11)` | VIA1 CA2 → PIA1 CA1 only; PIA CA1 is always an input; `'1'` (idle) when CA2 is in input mode |

The pin mapping within `Shell.vhd` that translates internal VIA/PIA signals
to the Shell's external ports:

| VIA1/PIA1 pin | Shell external port bit |
|---|---|
| VIA1 PA0 | `up(0)` |
| VIA1 PA1 | `up(1)` |
| VIA1 PA2 | `up(2)` |
| VIA1 PA3 | `up(3)` |
| VIA1 PA4 | `up(7)` |
| VIA1 PA5 | `up(6)` |
| VIA1 PA6 | `up(5)` |
| VIA1 PB3 | `cwr` |
| VIA1 CA2 | `up(11)` |
| VIA1 CB1 | `up(12)` |
| PIA1 PA7 | `up(10)` |
| PIA1 CA1 | `c1rd` |
