# 主时钟 500MHz
create_clock -name clk -period 2.0 [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]
set_clock_transition 0.05 [get_clocks clk]

# 输入延迟
set_input_delay -clock clk -max 0.4 [all_inputs]
set_input_delay -clock clk -min 0.1 [all_inputs]

# 输出延迟
set_output_delay -clock clk -max 0.4 [all_outputs]
set_output_delay -clock clk -min 0.1 [all_outputs]

# 异步复位 false path
set_false_path -from [get_ports rst_n]
