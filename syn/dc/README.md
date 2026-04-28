# Synopsys Design Compiler Synthesis

## Prerequisites
- Synopsys DC 2019.12 or later
- Target standard-cell library (update `setup.tcl` with your PDK `.db` files)

## Usage
```
cd syn/dc
make syn        # run synthesis
make clean      # remove outputs
```

## Output Files (in reports/)
| File | Description |
|------|-------------|
| `timing.rpt`  | Timing report (max 10 paths) |
| `area.rpt`    | Area report |
| `power.rpt`   | Power estimation |
| `qor.rpt`     | Quality of results |
| `check.rpt`   | Design rule checks |
| `soc_top_netlist.v` | Gate-level netlist |
| `soc_top_out.sdc`   | Output SDC |

## Timing Target
200 MHz (5 ns period) on TSMC 28nm typical corner.
