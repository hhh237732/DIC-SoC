# DC 综合说明

## 工艺库变量设置

编辑 `run_dc.tcl`，将 `your_tech.db` 替换为实际工艺库路径：
```tcl
set target_library "/path/to/your_tech.db"
set link_library   "* $target_library"
```

## 如何运行

```bash
cd syn/dc
make dc
# 或直接：
dc_shell -f run_dc.tcl
```

## 结果回填位置

综合完成后，将以下数据回填至 `doc/项目最终报告.md` 第14章：

| 指标 | 文件 | 回填位置 |
|------|------|---------|
| 时序（WNS/TNS） | reports/timing.rpt | 第14章时序表 |
| 面积（um²/门数） | reports/area.rpt | 第14章面积表 |
| 功耗（mW） | reports/power.rpt | 第14章功耗表 |
