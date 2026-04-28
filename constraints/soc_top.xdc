# ================================================================
# soc_top.xdc - Xilinx Artix-7 (Nexys4 DDR) constraints
# Target: xc7a100tcsg324-1  Clock: 100 MHz
# Architecture: L1I/L1D -> L2 arbiter -> L2 -> SRAM
#               DMA engine + MMIO regfile + PLIC-lite
# ================================================================

# Primary clock (100 MHz, Nexys4 DDR pin E3)
create_clock -period 10.000 -name sys_clk [get_ports clk]
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# Active-low reset (CPU RESET button, Nexys4 DDR: C12)
set_property PACKAGE_PIN C12 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# DMA-done interrupt LED (LD0, Nexys4 DDR: H17)
set_property PACKAGE_PIN H17 [get_ports dma_irq]
set_property IOSTANDARD LVCMOS33 [get_ports dma_irq]

# CPU interrupt aggregated output LED (LD1, Nexys4 DDR: K15)
set_property PACKAGE_PIN K15 [get_ports cpu_irq]
set_property IOSTANDARD LVCMOS33 [get_ports cpu_irq]

# Input / output delay budgets
set_input_delay  -clock sys_clk -max 2.0 [all_inputs]
set_input_delay  -clock sys_clk -min 0.5 [all_inputs]
set_output_delay -clock sys_clk -max 2.0 [all_outputs]
set_output_delay -clock sys_clk -min 0.5 [all_outputs]

# Multicycle paths
# DMA regfile -> DMA master (address decode latency)
set_multicycle_path -setup 2 -from [get_cells *dma_regfile*] -to [get_cells *dma_master*]
# L2 arbiter round-robin token update
set_multicycle_path -setup 2 -from [get_cells *l2_arbiter*rr_token*] -to [get_cells *l2_arbiter*]
# MMIO perf counter shadow registers (updated every cycle, read async)
set_multicycle_path -setup 2 -from [get_cells *l1_icache*perf*]  -to [get_cells *mmio_regfile*]
set_multicycle_path -setup 2 -from [get_cells *l1_dcache*perf*]  -to [get_cells *mmio_regfile*]
set_multicycle_path -setup 2 -from [get_cells *l2_cache*perf*]   -to [get_cells *mmio_regfile*]

# False paths on async reset tree
set_false_path -from [get_ports rst_n]
