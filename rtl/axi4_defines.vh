`ifndef AXI4_DEFINES_VH
`define AXI4_DEFINES_VH

// ================================================================
// AXI4与SoC全局参数定义头文件
// ================================================================

// ---------------- AXI4总线位宽 ----------------
`define AXI_ADDR_WIDTH  32
`define AXI_DATA_WIDTH  32
`define AXI_STRB_WIDTH  4
`define AXI_ID_WIDTH    4
`define AXI_LEN_WIDTH   8
`define AXI_SIZE_WIDTH  3
`define AXI_BURST_WIDTH 2

// ---------------- BURST类型 ----------------
`define AXI_BURST_FIXED 2'b00
`define AXI_BURST_INCR  2'b01
`define AXI_BURST_WRAP  2'b10

// ---------------- RESP编码 ----------------
`define AXI_RESP_OKAY   2'b00
`define AXI_RESP_EXOKAY 2'b01
`define AXI_RESP_SLVERR 2'b10
`define AXI_RESP_DECERR 2'b11

// ---------------- 地址映射 ----------------
`define SLAVE0_BASE 32'h0000_0000
`define SLAVE0_HIGH 32'h0FFF_FFFF
`define SLAVE1_BASE 32'h4000_0000
`define SLAVE1_HIGH 32'h4000_00FF
`define SLAVE2_BASE 32'h4000_1000
`define SLAVE2_HIGH 32'h4000_10FF

// ---------------- L1 Cache参数（8KB, 2-way, 32B line） ----------------
`define L1_WAYS         2
`define L1_SETS         128
`define L1_LINE_WORDS   8
`define L1_TAG_WIDTH    20
`define L1_INDEX_WIDTH  7
`define L1_OFFSET_WIDTH 5

// ---------------- L2 Cache参数（64KB, 4-way, 32B line） ----------------
`define L2_WAYS         4
`define L2_SETS         512
`define L2_LINE_WORDS   8
`define L2_TAG_WIDTH    18
`define L2_INDEX_WIDTH  9
`define L2_OFFSET_WIDTH 5

// ---------------- DMA寄存器偏移 ----------------
`define DMA_REG_CTRL       6'h00
`define DMA_REG_STATUS     6'h04
`define DMA_REG_SRCADDR    6'h08
`define DMA_REG_DSTADDR    6'h0C
`define DMA_REG_LEN        6'h10
`define DMA_REG_BURST_MAX  6'h14
`define DMA_REG_IRQ_MASK   8'h18
`define DMA_REG_IRQ_STATUS 8'h1C

`endif
