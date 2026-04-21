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
`define SLAVE1_BASE 32'h1000_0000
`define SLAVE1_HIGH 32'h1000_00FF
`define SLAVE2_BASE 32'h2000_0000
`define SLAVE2_HIGH 32'h2000_FFFF

// ---------------- L1 Cache参数（2KB, 2-way, 32B line） ----------------
`define L1_WAYS         2
`define L1_SETS         32
`define L1_LINE_WORDS   8
`define L1_TAG_WIDTH    22
`define L1_INDEX_WIDTH  5
`define L1_OFFSET_WIDTH 5

// ---------------- L2 Cache参数（16KB, 4-way, 64B line） ----------------
`define L2_WAYS         4
`define L2_SETS         64
`define L2_LINE_WORDS   16
`define L2_TAG_WIDTH    20
`define L2_INDEX_WIDTH  6
`define L2_OFFSET_WIDTH 6

// ---------------- DMA寄存器偏移 ----------------
`define DMA_REG_CTRL    6'h00
`define DMA_REG_STATUS  6'h04
`define DMA_REG_SRCADDR 6'h08
`define DMA_REG_DSTADDR 6'h0C
`define DMA_REG_LEN     6'h10
`define DMA_REG_INTEN   6'h14

`endif
