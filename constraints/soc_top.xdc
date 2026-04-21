# ================================================================
# soc_top.xdc - Xilinx Artix-7 (Basys3/Nexys4风格) 约束示例
# ================================================================

# 主时钟（100MHz）
create_clock -period 10.000 -name sys_clk [get_ports clk]

# 输入/输出延迟约束
set_input_delay  -clock sys_clk -max 2.0 [all_inputs]
set_input_delay  -clock sys_clk -min 0.5 [all_inputs]
set_output_delay -clock sys_clk -max 2.0 [all_outputs]
set_output_delay -clock sys_clk -min 0.5 [all_outputs]

# 时钟引脚（Basys3: W5）
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# 复位引脚（Basys3: U18）
set_property PACKAGE_PIN U18 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# 中断输出LED
set_property PACKAGE_PIN U16 [get_ports dma_irq]
set_property IOSTANDARD LVCMOS33 [get_ports dma_irq]

# 多周期路径约束（DMA寄存器文件到DMA主控）
set_multicycle_path -setup 2 -from [get_cells *dma_regfile*] -to [get_cells *dma_master*]
