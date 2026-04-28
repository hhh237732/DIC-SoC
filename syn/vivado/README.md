# Xilinx Vivado Synthesis & Implementation

## Prerequisites
- Vivado 2021.1 or later
- Target: Nexys4 DDR (XC7A100T-1CSG324C)

## Usage
```
cd syn/vivado
make        # synthesis + implementation + bitstream
make clean  # remove outputs
```

## Output Files (in reports/)
| File | Description |
|------|-------------|
| `timing_synth.rpt` | Post-synthesis timing |
| `util_synth.rpt`   | Post-synthesis utilization |
| `timing_impl.rpt`  | Post-implementation timing |
| `util_impl.rpt`    | Post-implementation utilization |
| `power_impl.rpt`   | Power estimation |
| `drc.rpt`          | DRC checks |
| `soc_top.bit`      | FPGA bitstream |

## Timing Target
100 MHz on Artix-7 (10 ns period).
