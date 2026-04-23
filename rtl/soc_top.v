`include "axi4_defines.vh"

// ================================================================
// 模块名称：soc_top
// 功能说明：
//   SoC顶层集成：L1 I/D Cache + L2 + AXI互联 + DMA + 主存 + GPIO Stub
// ================================================================
module soc_top (
    input         clk,
    input         rst_n,
    input         cpu_instr_req,
    input  [31:0] cpu_instr_addr,
    output [31:0] cpu_instr_data,
    output        cpu_instr_stall,
    input         cpu_data_req,
    input         cpu_data_we,
    input  [3:0]  cpu_data_wstrb,
    input  [31:0] cpu_data_addr,
    input  [31:0] cpu_data_wdata,
    output [31:0] cpu_data_rdata,
    output        cpu_data_stall,
    output        dma_irq
);

    // -------------- L1 ICache <-> L2 (作为AXI slave) --------------
    wire ic_arvalid, ic_arready;
    wire [31:0] ic_araddr;
    wire [3:0]  ic_arid;
    wire [7:0]  ic_arlen;
    wire [2:0]  ic_arsize;
    wire [1:0]  ic_arburst;
    wire ic_rvalid, ic_rready;
    wire [31:0] ic_rdata;
    wire [3:0]  ic_rid;
    wire [1:0]  ic_rresp;
    wire ic_rlast;

    // -------------- L1 DCache <-> L2 --------------
    wire dc_arvalid, dc_arready, dc_rvalid, dc_rready, dc_rlast;
    wire [31:0] dc_araddr, dc_rdata;
    wire [3:0]  dc_arid, dc_rid;
    wire [7:0]  dc_arlen;
    wire [2:0]  dc_arsize;
    wire [1:0]  dc_arburst;
    wire [1:0]  dc_rresp;

    wire dc_awvalid, dc_awready, dc_wvalid, dc_wready, dc_wlast, dc_bvalid, dc_bready;
    wire [31:0] dc_awaddr, dc_wdata;
    wire [3:0]  dc_awid, dc_wstrb, dc_bid;
    wire [7:0]  dc_awlen;
    wire [2:0]  dc_awsize;
    wire [1:0]  dc_awburst, dc_bresp;

    // -------------- L2作为Master0到Interconnect --------------
    wire m0_awvalid,m0_awready,m0_wvalid,m0_wready,m0_wlast,m0_bvalid,m0_bready,m0_arvalid,m0_arready,m0_rvalid,m0_rready,m0_rlast;
    wire [31:0] m0_awaddr,m0_wdata,m0_araddr,m0_rdata;
    wire [3:0]  m0_awid,m0_bid,m0_arid,m0_rid;
    wire [7:0]  m0_awlen,m0_arlen;
    wire [2:0]  m0_awsize,m0_arsize;
    wire [1:0]  m0_awburst,m0_bresp,m0_arburst,m0_rresp;
    wire [3:0]  m0_wstrb;

    // -------------- DMA作为Master1到Interconnect --------------
    wire m1_awvalid,m1_awready,m1_wvalid,m1_wready,m1_wlast,m1_bvalid,m1_bready,m1_arvalid,m1_arready,m1_rvalid,m1_rready,m1_rlast;
    wire [31:0] m1_awaddr,m1_wdata,m1_araddr,m1_rdata;
    wire [3:0]  m1_awid,m1_bid,m1_arid,m1_rid;
    wire [7:0]  m1_awlen,m1_arlen;
    wire [2:0]  m1_awsize,m1_arsize;
    wire [1:0]  m1_awburst,m1_bresp,m1_arburst,m1_rresp;
    wire [3:0]  m1_wstrb;

    // -------------- 互联到3个从机（ID扩展后5位） --------------
    wire s0_awvalid,s0_awready,s0_wvalid,s0_wready,s0_wlast,s0_bvalid,s0_bready,s0_arvalid,s0_arready,s0_rvalid,s0_rready,s0_rlast;
    wire [31:0] s0_awaddr,s0_wdata,s0_araddr,s0_rdata;
    wire [4:0]  s0_awid,s0_bid,s0_arid,s0_rid;
    wire [7:0]  s0_awlen,s0_arlen;
    wire [2:0]  s0_awsize,s0_arsize;
    wire [1:0]  s0_awburst,s0_bresp,s0_arburst,s0_rresp;
    wire [3:0]  s0_wstrb;

    wire s1_awvalid,s1_awready,s1_wvalid,s1_wready,s1_wlast,s1_bvalid,s1_bready,s1_arvalid,s1_arready,s1_rvalid,s1_rready,s1_rlast;
    wire [31:0] s1_awaddr,s1_wdata,s1_araddr,s1_rdata;
    wire [4:0]  s1_awid,s1_bid,s1_arid,s1_rid;
    wire [7:0]  s1_awlen,s1_arlen;
    wire [2:0]  s1_awsize,s1_arsize;
    wire [1:0]  s1_awburst,s1_bresp,s1_arburst,s1_rresp;
    wire [3:0]  s1_wstrb;

    wire s2_awvalid,s2_awready,s2_wvalid,s2_wready,s2_wlast,s2_bvalid,s2_bready,s2_arvalid,s2_arready,s2_rvalid,s2_rready,s2_rlast;
    wire [31:0] s2_awaddr,s2_wdata,s2_araddr,s2_rdata;
    wire [4:0]  s2_awid,s2_bid,s2_arid,s2_rid;
    wire [7:0]  s2_awlen,s2_arlen;
    wire [2:0]  s2_awsize,s2_arsize;
    wire [1:0]  s2_awburst,s2_bresp,s2_arburst,s2_rresp;
    wire [3:0]  s2_wstrb;

    // ------------ ICache ------------
    l1_icache inst_icache (
        .clk(clk), .rst_n(rst_n),
        .cpu_req(cpu_instr_req), .cpu_addr(cpu_instr_addr),
        .cpu_rdata(cpu_instr_data), .cpu_hit(), .cpu_stall(cpu_instr_stall),
        .icache_arvalid(ic_arvalid), .icache_arready(ic_arready), .icache_araddr(ic_araddr), .icache_arid(ic_arid), .icache_arlen(ic_arlen), .icache_arsize(ic_arsize), .icache_arburst(ic_arburst),
        .icache_rvalid(ic_rvalid), .icache_rready(ic_rready), .icache_rdata(ic_rdata), .icache_rid(ic_rid), .icache_rresp(ic_rresp), .icache_rlast(ic_rlast)
    );

    // ------------ DCache ------------
    l1_dcache inst_dcache (
        .clk(clk), .rst_n(rst_n),
        .cpu_req(cpu_data_req), .cpu_we(cpu_data_we), .cpu_wstrb(cpu_data_wstrb), .cpu_addr(cpu_data_addr), .cpu_wdata(cpu_data_wdata),
        .cpu_rdata(cpu_data_rdata), .cpu_hit(), .cpu_stall(cpu_data_stall),
        .dcache_arvalid(dc_arvalid), .dcache_arready(dc_arready), .dcache_araddr(dc_araddr), .dcache_arid(dc_arid), .dcache_arlen(dc_arlen), .dcache_arsize(dc_arsize), .dcache_arburst(dc_arburst),
        .dcache_rvalid(dc_rvalid), .dcache_rready(dc_rready), .dcache_rdata(dc_rdata), .dcache_rid(dc_rid), .dcache_rresp(dc_rresp), .dcache_rlast(dc_rlast),
        .dcache_awvalid(dc_awvalid), .dcache_awready(dc_awready), .dcache_awaddr(dc_awaddr), .dcache_awid(dc_awid), .dcache_awlen(dc_awlen), .dcache_awsize(dc_awsize), .dcache_awburst(dc_awburst),
        .dcache_wvalid(dc_wvalid), .dcache_wready(dc_wready), .dcache_wdata(dc_wdata), .dcache_wstrb(dc_wstrb), .dcache_wlast(dc_wlast),
        .dcache_bvalid(dc_bvalid), .dcache_bready(dc_bready), .dcache_bid(dc_bid), .dcache_bresp(dc_bresp)
    );

    wire l2_s_arready, l2_s_rvalid, l2_s_rlast;
    wire [31:0] l2_s_rdata;
    wire [3:0]  l2_s_rid;
    wire [1:0]  l2_s_rresp;

    // ------------ L2（当前实现中仅接入DCache上游端口） ------------
    l2_cache inst_l2 (
        .clk(clk), .rst_n(rst_n),
        .s_awvalid(dc_awvalid), .s_awready(dc_awready), .s_awaddr(dc_awaddr), .s_awid(dc_awid), .s_awlen(dc_awlen), .s_awsize(dc_awsize), .s_awburst(dc_awburst),
        .s_wvalid(dc_wvalid), .s_wready(dc_wready), .s_wdata(dc_wdata), .s_wstrb(dc_wstrb), .s_wlast(dc_wlast),
        .s_bvalid(dc_bvalid), .s_bready(dc_bready), .s_bid(dc_bid), .s_bresp(dc_bresp),
        .s_arvalid(dc_arvalid), .s_arready(l2_s_arready), .s_araddr(dc_araddr), .s_arid(dc_arid), .s_arlen(dc_arlen), .s_arsize(dc_arsize), .s_arburst(dc_arburst),
        .s_rvalid(l2_s_rvalid), .s_rready(dc_rready), .s_rdata(l2_s_rdata), .s_rid(l2_s_rid), .s_rresp(l2_s_rresp), .s_rlast(l2_s_rlast),
        .m_awvalid(m0_awvalid), .m_awready(m0_awready), .m_awaddr(m0_awaddr), .m_awid(m0_awid), .m_awlen(m0_awlen), .m_awsize(m0_awsize), .m_awburst(m0_awburst),
        .m_wvalid(m0_wvalid), .m_wready(m0_wready), .m_wdata(m0_wdata), .m_wstrb(m0_wstrb), .m_wlast(m0_wlast),
        .m_bvalid(m0_bvalid), .m_bready(m0_bready), .m_bid(m0_bid), .m_bresp(m0_bresp),
        .m_arvalid(m0_arvalid), .m_arready(m0_arready), .m_araddr(m0_araddr), .m_arid(m0_arid), .m_arlen(m0_arlen), .m_arsize(m0_arsize), .m_arburst(m0_arburst),
        .m_rvalid(m0_rvalid), .m_rready(m0_rready), .m_rdata(m0_rdata), .m_rid(m0_rid), .m_rresp(m0_rresp), .m_rlast(m0_rlast)
    );

    // DCache与L2连接
    assign dc_arready = l2_s_arready;
    assign dc_rvalid  = l2_s_rvalid;
    assign dc_rdata   = l2_s_rdata;
    assign dc_rid     = l2_s_rid;
    assign dc_rresp   = l2_s_rresp;
    assign dc_rlast   = l2_s_rlast;

    // ICache当前作为结构占位，读miss接口先保持空闲响应
    assign ic_arready = 1'b1;
    assign ic_rvalid  = 1'b0;
    assign ic_rdata   = 32'd0;
    assign ic_rid     = 4'd0;
    assign ic_rresp   = `AXI_RESP_OKAY;
    assign ic_rlast   = 1'b0;

    // ------------ DMA ------------
    dma_ctrl inst_dma (
        .clk(clk), .rst_n(rst_n),
        .cfg_awvalid(s1_awvalid), .cfg_awready(s1_awready), .cfg_awaddr(s1_awaddr), .cfg_awid(s1_awid[3:0]), .cfg_awlen(s1_awlen), .cfg_awsize(s1_awsize), .cfg_awburst(s1_awburst),
        .cfg_wvalid(s1_wvalid), .cfg_wready(s1_wready), .cfg_wdata(s1_wdata), .cfg_wstrb(s1_wstrb), .cfg_wlast(s1_wlast),
        .cfg_bvalid(s1_bvalid), .cfg_bready(s1_bready), .cfg_bid(s1_bid[3:0]), .cfg_bresp(s1_bresp),
        .cfg_arvalid(s1_arvalid), .cfg_arready(s1_arready), .cfg_araddr(s1_araddr), .cfg_arid(s1_arid[3:0]), .cfg_arlen(s1_arlen), .cfg_arsize(s1_arsize), .cfg_arburst(s1_arburst),
        .cfg_rvalid(s1_rvalid), .cfg_rready(s1_rready), .cfg_rdata(s1_rdata), .cfg_rid(s1_rid[3:0]), .cfg_rresp(s1_rresp), .cfg_rlast(s1_rlast),
        .dma_arvalid(m1_arvalid), .dma_arready(m1_arready), .dma_araddr(m1_araddr), .dma_arid(m1_arid), .dma_arlen(m1_arlen), .dma_arsize(m1_arsize), .dma_arburst(m1_arburst),
        .dma_rvalid(m1_rvalid), .dma_rready(m1_rready), .dma_rdata(m1_rdata), .dma_rid(m1_rid), .dma_rresp(m1_rresp), .dma_rlast(m1_rlast),
        .dma_awvalid(m1_awvalid), .dma_awready(m1_awready), .dma_awaddr(m1_awaddr), .dma_awid(m1_awid), .dma_awlen(m1_awlen), .dma_awsize(m1_awsize), .dma_awburst(m1_awburst),
        .dma_wvalid(m1_wvalid), .dma_wready(m1_wready), .dma_wdata(m1_wdata), .dma_wstrb(m1_wstrb), .dma_wlast(m1_wlast),
        .dma_bvalid(m1_bvalid), .dma_bready(m1_bready), .dma_bid(m1_bid), .dma_bresp(m1_bresp),
        .irq(dma_irq)
    );

    // ------------ AXI互联 ------------
    axi4_interconnect inst_noc (
        .clk(clk), .rst_n(rst_n),
        .m0_awvalid(m0_awvalid), .m0_awready(m0_awready), .m0_awaddr(m0_awaddr), .m0_awid(m0_awid), .m0_awlen(m0_awlen), .m0_awsize(m0_awsize), .m0_awburst(m0_awburst),
        .m0_wvalid(m0_wvalid), .m0_wready(m0_wready), .m0_wdata(m0_wdata), .m0_wstrb(m0_wstrb), .m0_wlast(m0_wlast),
        .m0_bvalid(m0_bvalid), .m0_bready(m0_bready), .m0_bid(m0_bid), .m0_bresp(m0_bresp),
        .m0_arvalid(m0_arvalid), .m0_arready(m0_arready), .m0_araddr(m0_araddr), .m0_arid(m0_arid), .m0_arlen(m0_arlen), .m0_arsize(m0_arsize), .m0_arburst(m0_arburst),
        .m0_rvalid(m0_rvalid), .m0_rready(m0_rready), .m0_rdata(m0_rdata), .m0_rid(m0_rid), .m0_rresp(m0_rresp), .m0_rlast(m0_rlast),
        .m1_awvalid(m1_awvalid), .m1_awready(m1_awready), .m1_awaddr(m1_awaddr), .m1_awid(m1_awid), .m1_awlen(m1_awlen), .m1_awsize(m1_awsize), .m1_awburst(m1_awburst),
        .m1_wvalid(m1_wvalid), .m1_wready(m1_wready), .m1_wdata(m1_wdata), .m1_wstrb(m1_wstrb), .m1_wlast(m1_wlast),
        .m1_bvalid(m1_bvalid), .m1_bready(m1_bready), .m1_bid(m1_bid), .m1_bresp(m1_bresp),
        .m1_arvalid(m1_arvalid), .m1_arready(m1_arready), .m1_araddr(m1_araddr), .m1_arid(m1_arid), .m1_arlen(m1_arlen), .m1_arsize(m1_arsize), .m1_arburst(m1_arburst),
        .m1_rvalid(m1_rvalid), .m1_rready(m1_rready), .m1_rdata(m1_rdata), .m1_rid(m1_rid), .m1_rresp(m1_rresp), .m1_rlast(m1_rlast),
        .s0_awvalid(s0_awvalid), .s0_awready(s0_awready), .s0_awaddr(s0_awaddr), .s0_awid(s0_awid), .s0_awlen(s0_awlen), .s0_awsize(s0_awsize), .s0_awburst(s0_awburst),
        .s0_wvalid(s0_wvalid), .s0_wready(s0_wready), .s0_wdata(s0_wdata), .s0_wstrb(s0_wstrb), .s0_wlast(s0_wlast),
        .s0_bvalid(s0_bvalid), .s0_bready(s0_bready), .s0_bid(s0_bid), .s0_bresp(s0_bresp),
        .s0_arvalid(s0_arvalid), .s0_arready(s0_arready), .s0_araddr(s0_araddr), .s0_arid(s0_arid), .s0_arlen(s0_arlen), .s0_arsize(s0_arsize), .s0_arburst(s0_arburst),
        .s0_rvalid(s0_rvalid), .s0_rready(s0_rready), .s0_rdata(s0_rdata), .s0_rid(s0_rid), .s0_rresp(s0_rresp), .s0_rlast(s0_rlast),
        .s1_awvalid(s1_awvalid), .s1_awready(s1_awready), .s1_awaddr(s1_awaddr), .s1_awid(s1_awid), .s1_awlen(s1_awlen), .s1_awsize(s1_awsize), .s1_awburst(s1_awburst),
        .s1_wvalid(s1_wvalid), .s1_wready(s1_wready), .s1_wdata(s1_wdata), .s1_wstrb(s1_wstrb), .s1_wlast(s1_wlast),
        .s1_bvalid(s1_bvalid), .s1_bready(s1_bready), .s1_bid(s1_bid), .s1_bresp(s1_bresp),
        .s1_arvalid(s1_arvalid), .s1_arready(s1_arready), .s1_araddr(s1_araddr), .s1_arid(s1_arid), .s1_arlen(s1_arlen), .s1_arsize(s1_arsize), .s1_arburst(s1_arburst),
        .s1_rvalid(s1_rvalid), .s1_rready(s1_rready), .s1_rdata(s1_rdata), .s1_rid(s1_rid), .s1_rresp(s1_rresp), .s1_rlast(s1_rlast),
        .s2_awvalid(s2_awvalid), .s2_awready(s2_awready), .s2_awaddr(s2_awaddr), .s2_awid(s2_awid), .s2_awlen(s2_awlen), .s2_awsize(s2_awsize), .s2_awburst(s2_awburst),
        .s2_wvalid(s2_wvalid), .s2_wready(s2_wready), .s2_wdata(s2_wdata), .s2_wstrb(s2_wstrb), .s2_wlast(s2_wlast),
        .s2_bvalid(s2_bvalid), .s2_bready(s2_bready), .s2_bid(s2_bid), .s2_bresp(s2_bresp),
        .s2_arvalid(s2_arvalid), .s2_arready(s2_arready), .s2_araddr(s2_araddr), .s2_arid(s2_arid), .s2_arlen(s2_arlen), .s2_arsize(s2_arsize), .s2_arburst(s2_arburst),
        .s2_rvalid(s2_rvalid), .s2_rready(s2_rready), .s2_rdata(s2_rdata), .s2_rid(s2_rid), .s2_rresp(s2_rresp), .s2_rlast(s2_rlast)
    );

    // ------------ 主存（Slave0） ------------
    main_mem inst_mem (
        .clk(clk), .rst_n(rst_n),
        .s_awvalid(s0_awvalid), .s_awready(s0_awready), .s_awaddr(s0_awaddr), .s_awid(s0_awid), .s_awlen(s0_awlen), .s_awsize(s0_awsize), .s_awburst(s0_awburst),
        .s_wvalid(s0_wvalid), .s_wready(s0_wready), .s_wdata(s0_wdata), .s_wstrb(s0_wstrb), .s_wlast(s0_wlast),
        .s_bvalid(s0_bvalid), .s_bready(s0_bready), .s_bid(s0_bid), .s_bresp(s0_bresp),
        .s_arvalid(s0_arvalid), .s_arready(s0_arready), .s_araddr(s0_araddr), .s_arid(s0_arid), .s_arlen(s0_arlen), .s_arsize(s0_arsize), .s_arburst(s0_arburst),
        .s_rvalid(s0_rvalid), .s_rready(s0_rready), .s_rdata(s0_rdata), .s_rid(s0_rid), .s_rresp(s0_rresp), .s_rlast(s0_rlast)
    );

    // ------------ GPIO Stub（Slave2） ------------
    gpio_slave_stub inst_gpio (
        .clk(clk), .rst_n(rst_n),
        .s_awvalid(s2_awvalid), .s_awready(s2_awready), .s_awaddr(s2_awaddr), .s_awid(s2_awid), .s_awlen(s2_awlen), .s_awsize(s2_awsize), .s_awburst(s2_awburst),
        .s_wvalid(s2_wvalid), .s_wready(s2_wready), .s_wdata(s2_wdata), .s_wstrb(s2_wstrb), .s_wlast(s2_wlast),
        .s_bvalid(s2_bvalid), .s_bready(s2_bready), .s_bid(s2_bid), .s_bresp(s2_bresp),
        .s_arvalid(s2_arvalid), .s_arready(s2_arready), .s_araddr(s2_araddr), .s_arid(s2_arid), .s_arlen(s2_arlen), .s_arsize(s2_arsize), .s_arburst(s2_arburst),
        .s_rvalid(s2_rvalid), .s_rready(s2_rready), .s_rdata(s2_rdata), .s_rid(s2_rid), .s_rresp(s2_rresp), .s_rlast(s2_rlast)
    );

endmodule

// ================================================================
// GPIO从机桩模块：用于Slave2，占位返回OKAY
// ================================================================
module gpio_slave_stub (
    input clk,
    input rst_n,
    input s_awvalid,
    output s_awready,
    input [31:0] s_awaddr,
    input [4:0] s_awid,
    input [7:0] s_awlen,
    input [2:0] s_awsize,
    input [1:0] s_awburst,
    input s_wvalid,
    output s_wready,
    input [31:0] s_wdata,
    input [3:0] s_wstrb,
    input s_wlast,
    output reg s_bvalid,
    input s_bready,
    output reg [4:0] s_bid,
    output reg [1:0] s_bresp,
    input s_arvalid,
    output s_arready,
    input [31:0] s_araddr,
    input [4:0] s_arid,
    input [7:0] s_arlen,
    input [2:0] s_arsize,
    input [1:0] s_arburst,
    output reg s_rvalid,
    input s_rready,
    output reg [31:0] s_rdata,
    output reg [4:0] s_rid,
    output reg [1:0] s_rresp,
    output reg s_rlast
);
    assign s_awready = 1'b1;
    assign s_wready  = 1'b1;
    assign s_arready = 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            s_bvalid<=0; s_bid<=0; s_bresp<=`AXI_RESP_OKAY;
            s_rvalid<=0; s_rdata<=0; s_rid<=0; s_rresp<=`AXI_RESP_OKAY; s_rlast<=0;
        end else begin
            if (s_awvalid && s_wvalid && s_wlast) begin
                s_bvalid <= 1'b1;
                s_bid    <= s_awid;
                s_bresp  <= `AXI_RESP_OKAY;
            end
            if (s_bvalid && s_bready) s_bvalid <= 1'b0;

            if (s_arvalid) begin
                s_rvalid <= 1'b1;
                s_rid    <= s_arid;
                s_rdata  <= 32'hA5A5_0000 | s_araddr[15:0];
                s_rresp  <= `AXI_RESP_OKAY;
                s_rlast  <= 1'b1;
            end
            if (s_rvalid && s_rready) begin
                s_rvalid <= 1'b0;
                s_rlast  <= 1'b0;
            end
        end
    end
endmodule
