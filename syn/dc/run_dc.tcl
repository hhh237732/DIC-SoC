# ================================================================
# run_dc.tcl - Synopsys Design Compiler synthesis script
# Author: hhh237732
# Target: TSMC 28nm (or any stdcell library)
# Usage:  dc_shell -f run_dc.tcl
# ================================================================

source setup.tcl

# ---- Analyze & Elaborate ----
analyze -format verilog -library WORK [list \
    ${RTL_DIR}/axi4_defines.vh \
    ${RTL_DIR}/sync_fifo.v \
    ${RTL_DIR}/dma_intr.v \
    ${RTL_DIR}/dma_regfile.v \
    ${RTL_DIR}/dma_master.v \
    ${RTL_DIR}/dma_ctrl.v \
    ${RTL_DIR}/l1_icache.v \
    ${RTL_DIR}/l1_dcache.v \
    ${RTL_DIR}/l2_cache.v \
    ${RTL_DIR}/cache/l2_arbiter.v \
    ${RTL_DIR}/mmio/mmio_regfile.v \
    ${RTL_DIR}/intc/plic_lite.v \
    ${RTL_DIR}/axi4_interconnect.v \
    ${RTL_DIR}/main_mem.v \
    ${RTL_DIR}/soc_top.v \
]

elaborate soc_top

current_design soc_top
link

# ---- Apply Constraints ----
source constraints.sdc

# ---- Compile ----
compile_ultra -no_autoungroup

# ---- Reports ----
report_timing  -max_paths 10        > reports/timing.rpt
report_area                         > reports/area.rpt
report_power   -analysis_effort low > reports/power.rpt
report_qor                          > reports/qor.rpt
check_design                        > reports/check.rpt

# ---- Write Outputs ----
write -format verilog -hierarchy -output reports/soc_top_netlist.v
write_sdc reports/soc_top_out.sdc

echo "DC synthesis complete."
