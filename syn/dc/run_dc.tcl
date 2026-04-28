# ============================================================
# DC综合脚本 — DIC-SoC
# ============================================================

# 工艺库（请根据实际环境修改）
set target_library "your_tech.db"
set link_library   "* $target_library"

# 读RTL源文件
set RTL_DIR "../../rtl"
read_verilog [glob $RTL_DIR/*.v]

# 顶层模块展开
elaborate soc_top
link
check_design

# 应用SDC约束
read_sdc constraints.sdc

# compile_ultra 综合优化
compile_ultra -no_autoungroup

# 输出reports到syn/dc/reports/
file mkdir reports
report_timing  -max_paths 10        > reports/timing.rpt
report_area                         > reports/area.rpt
report_power                        > reports/power.rpt
report_qor                          > reports/qor.rpt
report_constraint -all_violators    > reports/violations.rpt

# 输出网表与SDF
write -format verilog -hierarchy -output reports/soc_top_netlist.v
write_sdf reports/soc_top.sdf

echo "DC综合完成，结果见 syn/dc/reports/"
