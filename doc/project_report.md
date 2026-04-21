# 基于AXI4的SoC集成与高速DMA系统设计报告

> 本报告对应仓库 `DIC-SoC` 的RTL与测试实现，面向学习型SoC工程实践，强调“可读性、模块化与可验证性”。

---

## 1. 项目背景与意义

### 1.1 SoC设计的必要性
现代数字系统正在从“单核+外设拼接”转向“片上异构计算+统一互联”。SoC（System on Chip）将CPU、缓存、存储控制、DMA和外设统一在单颗芯片中，能显著降低延迟、提升带宽利用率和系统能效。在教学或科研阶段，完整搭建一个具备CPU访问、Cache层次与DMA搬运能力的SoC原型，有助于理解从微结构到系统架构的跨层协同。

### 1.2 AXI4协议选择原因
AXI4是工业界广泛采用的片上互联协议，核心优势是五通道解耦（AR/AW/W/R/B）和VALID/READY握手机制。它天然支持burst、乱序ID扩展以及高吞吐流水，适合Cache miss回填与DMA连续搬运。相较于简单总线，AXI4更强调并行和扩展性，适合作为课程项目的主干协议。

### 1.3 Cache层次结构的性能意义
处理器访问存储的瓶颈通常是主存访问延迟。L1提供低延迟命中，L2提供容量缓冲和共享能力，二者形成“快而小 + 慢而大”的分层结构。在本项目中，L1 I/D Cache与L2协同，既能体现命中路径的快速返回，也能展示miss后的AXI burst回填过程。

### 1.4 DMA在高速数据搬运中的作用
DMA将大块数据搬运从CPU中卸载，避免CPU陷入重复load/store循环。本项目DMA支持4KB边界拆分、读写并行调度和FIFO解耦，可以清晰展示“控制平面（寄存器）+数据平面（AXI主机）”的经典设计模式。

---

## 2. 系统架构设计

### 2.1 整体架构框图（ASCII）

```text
+-------------------------------+        +-------------------------+
|            CPU Core           |        |       DMA Subsystem     |
|  +-----------+  +-----------+ |        | +---------------------+ |
|  | L1 ICache |  | L1 DCache | |        | | DMA Regfile (AXI S) | |
|  +-----+-----+  +-----+-----+ |        | +----------+----------+ |
+--------|--------------|-------+        |            |            |
         |              |                |      +-----v------+     |
         +------->  +---v----------------v----> | DMA Master |     |
                    |        L2 Cache          | +-----+------+     |
                    +------------+-------------+       |            |
                                 |                     | FIFO       |
                           +-----v---------------------v----+       |
                           |     AXI4 Interconnect (2x3)    |       |
                           +----+----------------+----------+       |
                                |                |                  |
                          +-----v----+    +------v------+           |
                          | Main Mem |    | GPIO/Stub   |           |
                          +----------+    +-------------+           |
                                                                     
```

### 2.2 地址空间规划
- Slave0 Main Memory: `0x0000_0000 ~ 0x0FFF_FFFF`
- Slave1 DMA Registers: `0x1000_0000 ~ 0x1000_00FF`
- Slave2 GPIO/Peripheral: `0x2000_0000 ~ 0x2000_FFFF`

该映射在 `axi4_defines.vh` 固化，同时互联中可参数化重定义。

### 2.3 模块划分与职责
- `axi4_interconnect`：路由与仲裁核心
- `l1_icache` / `l1_dcache`：近核低延迟缓存
- `l2_cache`：共享缓存与主存缓冲
- `dma_regfile`：软件可编程控制接口
- `dma_master`：读写搬运引擎
- `sync_fifo`：流量平滑与背压隔离
- `dma_intr`：中断状态保持与门控
- `main_mem`：仿真内存模型
- `soc_top`：系统级连接

### 2.4 数据通路分析
CPU取指和数据访问优先命中L1，miss后进入L2；L2再次miss时通过AXI访问主存。DMA由寄存器触发后走独立AXI主端口，与L2共享互联；互联通过仲裁确保冲突场景可推进。

---

## 3. AXI4互联总线设计

### 3.1 AXI4协议五通道分析
- AW：写地址与控制
- W：写数据
- B：写响应
- AR：读地址与控制
- R：读数据与响应

通道分离后，读写可并行，吞吐显著高于单总线串行模型。

### 3.2 仲裁机制（优先级仲裁原理）
每个从机的AW/AR使用固定优先级：M0 > M1。策略简单、延迟低、可综合实现直接。为了防止W通道错配，在AW握手后锁定该从机写owner，直至该burst的WLAST完成。

### 3.3 地址解码逻辑
在AW/AR进入互联时比较地址区间，确定目标从机编号；若不命中任何窗口，触发内部DECERR路径，由互联产生B/R错误响应。

### 3.4 ID扩展与响应路由
上游ID宽4位，下游从机ID扩展为5位：`{master_sel, id[3:0]}`。B/R返回时由MSB识别源主机并回送，保证响应路由稳定可追踪。

### 3.5 多事务并行示意图（ASCII时序）

```text
Cycle:   t0   t1   t2   t3   t4   t5   t6
M0 AR:   V----H
M1 AW:        V----H
S0 R :             V----H----V----H(last)
S1 B :                  V----H

说明：读AR与写AW可交叠；R/B各自独立回传。
```

---

## 4. L1 Cache设计

### 4.1 Cache组织结构
L1规格：2KB，2-way，line=32B，32 sets。

```text
addr[31:10] TAG(22) | addr[9:5] INDEX(5) | addr[4:2] WORD(3) | addr[1:0] BYTE
```

### 4.2 命中判断逻辑
每路比较：`valid && (tag_match)`，任一路命中即hit。ICache命中直接返回；DCache命中时读返回或局部字节更新。

### 4.3 2-way LRU替换策略
每set维护1bit：记录“下一次替换哪一路”。命中后翻转到另一way，miss时用该bit选择victim。

### 4.4 写回/写分配策略（D-Cache）
- 写命中：更新cache line + 置dirty
- 写缺失：若victim脏则写回，随后读入新行，再执行写入

### 4.5 Miss处理流程图

```text
CPU Req -> Tag Check
   | hit -> return
   | miss
   +--> victim dirty? --yes--> writeback burst
                      --no ---> refill burst
            refill done -> apply pending op -> return
```

---

## 5. L2 Cache设计

### 5.1 结构规格与L1差异
L2容量16KB、4-way、64B line（16 words），相较L1容量更大、line更长，适合聚合L1 miss流量。

### 5.2 伪LRU（PLRU）4-way替换算法详解
每组3bit二叉树：

```text
       b2
      /  \
    b1    b0
   / \    / \
  W0 W1  W2 W3
```

替换时按树位走向选择“最不常用”候选；访问任意way后更新沿途指针指向反方向，实现低开销近似LRU。

### 5.3 L1→L2→MainMem三级层次图

```text
CPU -> L1 (fast, small) -> L2 (shared, mid) -> MainMem (slow, large)
```

### 5.4 Miss惩罚分析
L2 miss会触发16拍主存访问，惩罚远高于L1 miss命中L2场景。因此减少冲突miss和优化替换策略非常关键。

---

## 6. DMA控制器设计

### 6.1 DMA系统架构图

```text
AXI-S(CFG) -> dma_regfile -> dma_master -> AXI-M(DATA)
                                 |
                               sync_fifo
                                 |
                               dma_intr
```

### 6.2 寄存器映射表
| 偏移 | 寄存器 | 描述 |
|---|---|---|
| 0x00 | CTRL | start/abort |
| 0x04 | STATUS | busy/done/error |
| 0x08 | SRC_ADDR | 源地址 |
| 0x0C | DST_ADDR | 目的地址 |
| 0x10 | LENGTH | 字节数(4B对齐) |
| 0x14 | INT_EN | done_ie/err_ie |

### 6.3 4KB边界拆分算法
DMA内部以word计数：`words = length >> 2`。
每次burst最多256拍且不可跨4KB：

- `max_beats_4k = (4096 - (addr & 12'hFFF)) >> 2`
- `beats = min(remaining_words, max_beats_4k, 256)`
- `ARLEN/AWLEN = beats - 1`

示例：`addr=0x...0F00`，离4KB边界256B，仅能先发64拍，再继续下一段。

### 6.4 读写独立调度状态机图

```text
RD: IDLE -> ADDR -> DATA -> (ADDR/DONE)
WR: IDLE -> WAIT -> ADDR -> DATA -> RESP -> (WAIT/DONE)
```

### 6.5 FIFO解耦机制分析
读侧将R数据写FIFO，写侧从FIFO取数据发W。写状态机在`fifo_data_count`足够时才启动burst，避免写中途断流。

### 6.6 中断与状态机制
`dma_done/dma_error`脉冲被`dma_intr`锁存为电平中断，软件通过W1C清除。中断输出经过使能位门控。

---

## 7. 同步FIFO设计

### 7.1 电路结构
- 存储体：`mem[0:255]`，32位
- 指针：`wr_ptr/rd_ptr`（9位）
- 计数：`data_count = wr_ptr - rd_ptr`

### 7.2 Full/Empty判断逻辑
- `full = (data_count == DEPTH)`
- `empty = (data_count == 0)`
- `almost_full >= 240`
- `almost_empty <= 16`

### 7.3 Back-pressure机制
写端在`full`时阻塞，读端在`empty`时阻塞。DMA通过`fifo_full/fifo_empty/data_count`自动调度，形成稳定背压链路。

---

## 8. 信号说明

### 8.1 AXI4通道信号完整列表（核心）
- 地址：`awaddr/araddr`
- 控制：`awlen/arlen, awsize/arsize, awburst/arburst, awid/arid`
- 数据：`wdata/wstrb/wlast, rdata/rlast`
- 响应：`bresp/bid, rresp/rid`
- 握手：`valid/ready`

### 8.2 各模块关键信号说明表
| 模块 | 关键信号 | 作用 |
|---|---|---|
| l1_icache | `cpu_hit/cpu_stall` | 命中与停顿控制 |
| l1_dcache | `dirty_arr` | 脏行写回判定 |
| l2_cache | `plru_arr` | 4-way替换近似LRU |
| dma_master | `rd_rem_words/wr_rem_words` | 搬运剩余计数 |
| dma_regfile | `dma_start` | 启动脉冲 |
| sync_fifo | `data_count` | 流控依据 |
| interconnect | `dec_slave` | 地址路由选择 |

---

## 9. 仿真验证

### 9.1 测试计划
- FIFO：满/空/随机混合/阈值标志
- DMA：寄存器配置、搬运正确性、4KB拆分
- L1 DCache：read miss/hit、write allocate、替换写回路径
- L2：miss回填、再访命中、替换路径
- SoC：端到端读写与DMA触发

### 9.2 关键波形说明
- DMA启动后先见`ARVALID`突发，再见`RVALID`流；FIFO积累后出现`AWVALID/WVALID`写流
- DCache脏行替换时，先`AW/W/B`写回，再`AR/R`回填
- 互联中可观察M0/M1在不同从机通道并行活动

### 9.3 覆盖率目标
本项目以教学验证为主，强调功能场景覆盖：
- 协议握手路径覆盖
- miss/hit切换覆盖
- 4KB边界覆盖
- 中断置位/清除覆盖

---

## 10. 综合与实现

### 10.1 目标FPGA资源估算
- LUT/FF：主要来自互联控制状态机与Cache标签逻辑
- BRAM：Cache/FIFO可映射为块RAM（当前RTL为寄存器数组，综合器可推断）
- IO：顶层接口较少，便于板级实验

### 10.2 时序约束策略
- 主时钟100MHz
- 统一输入输出延迟约束
- DMA寄存器文件至主控路径设置multicycle，降低不必要时序压力

### 10.3 关键路径分析
潜在关键路径集中在：
1) Cache命中比较+选择器组合链
2) 互联仲裁+路由组合判断
3) DMA burst长度计算与调度判定
后续可通过寄存器切分和流水化优化。

---

## 11. 总结与改进方向

### 11.1 项目总结
本项目完成了一个可运行的AXI4 SoC教学平台，实现了从CPU访问、缓存层次、片上互联、DMA搬运到仿真验证的完整闭环。工程结构清晰、模块边界明确，适合作为后续迭代和课程实验基线。

### 11.2 潜在改进
1. 加入ECC/parity提升可靠性
2. Interconnect支持QoS与公平仲裁
3. Cache支持非阻塞miss与MSHR
4. DMA支持scatter-gather描述符链
5. 增强乱序响应与多Outstanding事务
6. 增加性能计数器与覆盖率自动统计

---

## 附录A：完整信号列表
详见RTL端口定义（`rtl/*.v`），其中AXI信号按通道完整展开，命名采用前缀区分主从与模块来源。

## 附录B：参考文献
1. ARM AMBA AXI4 Protocol Specification
2. Hennessy & Patterson, *Computer Architecture: A Quantitative Approach*
3. Patterson & Hennessy, *Computer Organization and Design*
4. Xilinx Vivado Design Suite User Guide (Constraints / Timing)
