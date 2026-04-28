# ================================================================
# run_vivado.tcl - Xilinx Vivado synthesis + implementation script
# Author: hhh237732
# Target: Xilinx Artix-7 XC7A100T-1CSG324C (Nexys4 DDR)
# Usage:  vivado -mode batch -source run_vivado.tcl
# ================================================================

set PART       xc7a100tcsg324-1
set RTL_DIR    ../../rtl
set OUT_DIR    reports
set TOP        soc_top

# ---- Create project in memory ----
create_project -in_memory -part ${PART}

# ---- Add RTL sources ----
read_verilog -sv [list \
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

read_xdc constraints.xdc
set_property INCLUDE_DIRS [list ${RTL_DIR} ${RTL_DIR}/cache ${RTL_DIR}/mmio ${RTL_DIR}/intc] [current_fileset]

# ---- Synthesize ----
synth_design -top ${TOP} -part ${PART} -include_dirs [list ${RTL_DIR}]

# ---- Reports (post-synth) ----
file mkdir ${OUT_DIR}
report_timing_summary -max_paths 10    -file ${OUT_DIR}/timing_synth.rpt
report_utilization                     -file ${OUT_DIR}/util_synth.rpt
report_power                           -file ${OUT_DIR}/power_synth.rpt

# ---- Implement ----
opt_design
place_design
phys_opt_design
route_design

# ---- Reports (post-impl) ----
report_timing_summary -max_paths 10    -file ${OUT_DIR}/timing_impl.rpt
report_utilization                     -file ${OUT_DIR}/util_impl.rpt
report_power                           -file ${OUT_DIR}/power_impl.rpt
report_drc                             -file ${OUT_DIR}/drc.rpt

# ---- Bitstream ----
write_bitstream -force ${OUT_DIR}/${TOP}.bit

puts "Vivado flow complete."
