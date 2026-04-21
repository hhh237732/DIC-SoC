# DIC-SoC: 基于AXI4的SoC集成与DMA系统

## 项目简介
本项目实现了一个教学导向的AXI4 SoC原型，包含两级缓存（L1 I/D + L2）、2主3从AXI4互联、DMA控制子系统、主存模型与完整测试平台。全部RTL使用Verilog编写，并配套中文注释和项目报告，便于学习AXI握手、Cache替换、写回策略和DMA并行调度。

## 功能特性
- AXI4 Interconnect（2 Masters × 3 Slaves）
  - 地址解码、优先级仲裁（M0优先）
  - ID扩展与B/R响应回路
  - 非法地址DECERR响应
- L1 Cache
  - ICache：2KB，2-way，32B line，只读回填
  - DCache：2KB，2-way，写回+写分配
- L2 Cache
  - 16KB，4-way，64B line，PLRU替换
  - 写回+写分配
- DMA子系统
  - AXI Slave寄存器配置 + AXI Master搬运
  - 4KB边界拆分
  - FIFO解耦与中断管理
- 主存模型
  - AXI burst读写
  - 64KB仿真存储

## 目录结构
```text
rtl/
  axi4_defines.vh
  axi4_interconnect.v
  l1_icache.v
  l1_dcache.v
  l2_cache.v
  sync_fifo.v
  dma_regfile.v
  dma_master.v
  dma_intr.v
  dma_ctrl.v
  main_mem.v
  soc_top.v

 tb/
  tb_sync_fifo.v
  tb_dma.v
  tb_l1_dcache.v
  tb_l2_cache.v
  tb_soc_top.v

constraints/
  soc_top.xdc

doc/
  project_report.md
```

## 快速开始
> 以下命令基于 `iverilog + vvp`。

### 1) FIFO测试
```bash
iverilog -g2012 -o /tmp/tb_fifo tb/tb_sync_fifo.v rtl/sync_fifo.v
vvp /tmp/tb_fifo
```

### 2) DMA测试
```bash
iverilog -g2012 -o /tmp/tb_dma \
  tb/tb_dma.v rtl/dma_ctrl.v rtl/dma_regfile.v rtl/dma_master.v rtl/dma_intr.v rtl/sync_fifo.v
vvp /tmp/tb_dma
```

### 3) L1 DCache测试
```bash
iverilog -g2012 -o /tmp/tb_l1d tb/tb_l1_dcache.v rtl/l1_dcache.v
vvp /tmp/tb_l1d
```

### 4) L2 Cache测试
```bash
iverilog -g2012 -o /tmp/tb_l2 tb/tb_l2_cache.v rtl/l2_cache.v
vvp /tmp/tb_l2
```

### 5) SoC集成测试
```bash
iverilog -g2012 -o /tmp/tb_soc \
  tb/tb_soc_top.v rtl/*.v
vvp /tmp/tb_soc
```

## 模块层次结构（简图）
```text
CPU IF/LSU
   |      \
 L1I      L1D
    \    /
      L2
       |
 AXI Interconnect (2M x 3S)
   |        |         |
 MainMem   DMA CFG   GPIO
            |
         DMA Master -> Memory
```

## 作者信息
- Repository: `hhh237732/DIC-SoC`
- Maintainer: hhh237732
- Assistant Support: GitHub Copilot Coding Agent
