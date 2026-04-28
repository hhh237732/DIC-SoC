# ============================================================
# Vivado 综合+实现脚本 — DIC-SoC
# ============================================================

# 读取所有RTL文件
set RTL_DIR "../../rtl"
foreach f [glob $RTL_DIR/*.v] { read_verilog $f }
read_xdc constraints.xdc

# 综合
synth_design -top soc_top -part xc7a100tcsg324-1 -flatten_hierarchy rebuilt

# 实现
opt_design
place_design
phys_opt_design
route_design

# 输出报告到 syn/vivado/reports/
file mkdir reports
report_timing_summary -file reports/timing_summary.rpt
report_utilization    -file reports/utilization.rpt
report_power          -file reports/power.rpt
report_drc            -file reports/drc.rpt

# 输出比特流（可选）
# write_bitstream -force reports/soc_top.bit

puts "Vivado实现完成，结果见 syn/vivado/reports/"
