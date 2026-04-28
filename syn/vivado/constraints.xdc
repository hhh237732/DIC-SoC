# ================================================================
# constraints.xdc - Xilinx Vivado XDC constraints
# Author: hhh237732
# Target: Nexys4 DDR (XC7A100T-1CSG324C), 100 MHz system clock
# ================================================================

# ---- System clock (100 MHz on E3) ----
create_clock -period 10.000 -name sys_clk [get_ports clk]
set_property PACKAGE_PIN E3      [get_ports clk]
set_property IOSTANDARD  LVCMOS33 [get_ports clk]

# ---- Active-low reset (CPU_RESETN on C12) ----
set_property PACKAGE_PIN C12     [get_ports rst_n]
set_property IOSTANDARD  LVCMOS33 [get_ports rst_n]
set_false_path -from [get_ports rst_n]

# ---- DMA IRQ output -> LED LD0 (H17) ----
set_property PACKAGE_PIN H17     [get_ports dma_irq]
set_property IOSTANDARD  LVCMOS33 [get_ports dma_irq]

# ---- CPU IRQ output -> LED LD1 (K15) ----
set_property PACKAGE_PIN K15     [get_ports cpu_irq]
set_property IOSTANDARD  LVCMOS33 [get_ports cpu_irq]

# ---- I/O timing constraints ----
set_input_delay  -clock sys_clk -max 2.0 [all_inputs]
set_input_delay  -clock sys_clk -min 0.5 [all_inputs]
set_output_delay -clock sys_clk -max 2.0 [all_outputs]
set_output_delay -clock sys_clk -min 0.5 [all_outputs]

# ---- Multicycle paths ----
set_multicycle_path -setup 2 -from [get_cells *inst_dma/u_regfile*] \
                              -to   [get_cells *inst_dma/u_master*]
