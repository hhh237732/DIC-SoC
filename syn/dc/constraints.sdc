# ================================================================
# constraints.sdc - Synopsys Design Constraints
# Author: hhh237732
# Target: 200 MHz (5 ns period)
# ================================================================

# ---- Clock ----
create_clock -period 5.0 -name clk [get_ports clk]
set_clock_uncertainty -setup 0.15 [get_clocks clk]
set_clock_uncertainty -hold  0.05 [get_clocks clk]
set_clock_transition  0.1         [get_clocks clk]

# ---- I/O delays (20% of period) ----
set_input_delay  -clock clk -max 1.0 [all_inputs]
set_input_delay  -clock clk -min 0.1 [all_inputs]
set_output_delay -clock clk -max 1.0 [all_outputs]
set_output_delay -clock clk -min 0.1 [all_outputs]

# Remove clk from I/O delay list
set_false_path -from [get_ports rst_n]

# ---- Drive/load ----
# NOTE: Replace BUFX4 with an actual buffer cell from your target PDK library
#       (e.g. sky130_fd_sc_hd__buf_4 for SkyWater 130nm).
#       The cell name must match an entry in the .db files listed in setup.tcl.
set_driving_cell -lib_cell BUFX4 -pin Z [all_inputs]
set_load 0.05 [all_outputs]

# ---- Multicycle paths ----
# DMA register file to master: 2-cycle path
set_multicycle_path -setup 2 \
    -from [get_cells inst_dma/u_regfile/*] \
    -to   [get_cells inst_dma/u_master/*]

# Cache arrays are registered; relax timing on SRAM-like paths
set_multicycle_path -setup 2 \
    -through [get_nets *data_arr*]

# ---- Area ----
set_max_area 0
