# Vivado 综合实现说明

## 器件选型

默认目标器件：**Artix-7 xc7a100tcsg324-1**  
如需更换，修改 `run_vivado.tcl` 中 `-part` 参数。

## 如何运行

```bash
cd syn/vivado
make vivado
# 或直接：
vivado -mode batch -source run_vivado.tcl
```

## 结果解读

| 报告文件 | 关键指标 | 回填位置 |
|---------|---------|---------|
| reports/timing_summary.rpt | WNS/WHS | 第15章时序表 |
| reports/utilization.rpt | LUT/FF/BRAM/DSP | 第15章资源表 |
| reports/power.rpt | 静态/动态功耗 | 第15章功耗表 |
| reports/drc.rpt | DRC违例数 | 第15章DRC栏 |

## 注意事项

- 若存在undriven信号请先检查RTL，参考 `doc/差距清单.md`
- BRAM推断：L2 Cache data_arr 预期映射到 BRAM36
