# SoC Synthesis Scripts

## Directory Structure

```
syn/
├── dc/       Synopsys Design Compiler (ASIC)
└── vivado/   Xilinx Vivado (FPGA - Artix-7)
```

## Quick Start

### FPGA (Vivado)
```bash
cd syn/vivado
make
```

### ASIC (Design Compiler)
```bash
cd syn/dc
# Edit setup.tcl to point to your PDK .db files
make syn
```

## Design Parameters

| Parameter | Value |
|-----------|-------|
| L1I Cache | 2 KB, 2-way, 32 B line |
| L1D Cache | 2 KB, 2-way, 32 B line, write-back |
| L2 Cache  | 16 KB, 4-way, 64 B line, write-back |
| AXI width | 32-bit addr, 32-bit data |
| DMA FIFO  | 256 × 32-bit |
| MMIO base | 0x2000_0000 |
| DMA base  | 0x1000_0000 |
| Mem base  | 0x0000_0000 (64 KB) |
