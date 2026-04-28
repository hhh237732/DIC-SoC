`include "axi4_defines.vh"

// ================================================================
// 模块名称：dma_ctrl
// 功能说明：
//   DMA子系统顶层：寄存器文件 + 主控DMA + FIFO + 中断模块。
// ================================================================
module dma_ctrl (
    input         clk,
    input         rst_n,

    // 配置AXI Slave接口
    input         cfg_awvalid,
    output        cfg_awready,
    input  [31:0] cfg_awaddr,
    input  [3:0]  cfg_awid,
    input  [7:0]  cfg_awlen,
    input  [2:0]  cfg_awsize,
    input  [1:0]  cfg_awburst,
    input         cfg_wvalid,
    output        cfg_wready,
    input  [31:0] cfg_wdata,
    input  [3:0]  cfg_wstrb,
    input         cfg_wlast,
    output        cfg_bvalid,
    input         cfg_bready,
    output [3:0]  cfg_bid,
    output [1:0]  cfg_bresp,
    input         cfg_arvalid,
    output        cfg_arready,
    input  [31:0] cfg_araddr,
    input  [3:0]  cfg_arid,
    input  [7:0]  cfg_arlen,
    input  [2:0]  cfg_arsize,
    input  [1:0]  cfg_arburst,
    output        cfg_rvalid,
    input         cfg_rready,
    output [31:0] cfg_rdata,
    output [3:0]  cfg_rid,
    output [1:0]  cfg_rresp,
    output        cfg_rlast,

    // 数据AXI Master接口
    output        dma_arvalid,
    input         dma_arready,
    output [31:0] dma_araddr,
    output [3:0]  dma_arid,
    output [7:0]  dma_arlen,
    output [2:0]  dma_arsize,
    output [1:0]  dma_arburst,
    input         dma_rvalid,
    output        dma_rready,
    input  [31:0] dma_rdata,
    input  [3:0]  dma_rid,
    input  [1:0]  dma_rresp,
    input         dma_rlast,
    output        dma_awvalid,
    input         dma_awready,
    output [31:0] dma_awaddr,
    output [3:0]  dma_awid,
    output [7:0]  dma_awlen,
    output [2:0]  dma_awsize,
    output [1:0]  dma_awburst,
    output        dma_wvalid,
    input         dma_wready,
    output [31:0] dma_wdata,
    output [3:0]  dma_wstrb,
    output        dma_wlast,
    input         dma_bvalid,
    output        dma_bready,
    input  [3:0]  dma_bid,
    input  [1:0]  dma_bresp,

    output        irq
);

    wire reg_dma_start;
    wire reg_dma_abort;
    wire [31:0] reg_src_addr;
    wire [31:0] reg_dst_addr;
    wire [31:0] reg_length;
    wire [7:0]  reg_burst_max;
    wire done_ie;
    wire err_ie;
    wire done_clr;
    wire err_clr;

    wire dma_busy;
    wire dma_done;
    wire dma_error;

    wire fifo_wr_en;
    wire [31:0] fifo_wr_data;
    wire fifo_full;
    wire fifo_rd_en;
    wire [31:0] fifo_rd_data;
    wire fifo_empty;
    wire [8:0] fifo_data_count;

    dma_regfile u_regfile (
        .clk(clk), .rst_n(rst_n),
        .s_awvalid(cfg_awvalid), .s_awready(cfg_awready), .s_awaddr(cfg_awaddr), .s_awid(cfg_awid), .s_awlen(cfg_awlen), .s_awsize(cfg_awsize), .s_awburst(cfg_awburst),
        .s_wvalid(cfg_wvalid), .s_wready(cfg_wready), .s_wdata(cfg_wdata), .s_wstrb(cfg_wstrb), .s_wlast(cfg_wlast),
        .s_bvalid(cfg_bvalid), .s_bready(cfg_bready), .s_bid(cfg_bid), .s_bresp(cfg_bresp),
        .s_arvalid(cfg_arvalid), .s_arready(cfg_arready), .s_araddr(cfg_araddr), .s_arid(cfg_arid), .s_arlen(cfg_arlen), .s_arsize(cfg_arsize), .s_arburst(cfg_arburst),
        .s_rvalid(cfg_rvalid), .s_rready(cfg_rready), .s_rdata(cfg_rdata), .s_rid(cfg_rid), .s_rresp(cfg_rresp), .s_rlast(cfg_rlast),
        .dma_start(reg_dma_start), .dma_abort(reg_dma_abort),
        .dma_src_addr(reg_src_addr), .dma_dst_addr(reg_dst_addr), .dma_length(reg_length),
        .done_ie(done_ie), .err_ie(err_ie), .dma_burst_max(reg_burst_max),
        .dma_busy(dma_busy), .dma_done(dma_done), .dma_error(dma_error),
        .done_clr(done_clr), .err_clr(err_clr)
    );

    dma_master u_master (
        .clk(clk), .rst_n(rst_n),
        .dma_start(reg_dma_start), .dma_abort(reg_dma_abort),
        .src_addr(reg_src_addr), .dst_addr(reg_dst_addr), .length(reg_length),
        .burst_max(reg_burst_max),
        .dma_busy(dma_busy), .dma_done(dma_done), .dma_error(dma_error),
        .fifo_wr_en(fifo_wr_en), .fifo_wr_data(fifo_wr_data), .fifo_full(fifo_full),
        .fifo_rd_en(fifo_rd_en), .fifo_rd_data(fifo_rd_data), .fifo_empty(fifo_empty), .fifo_data_count(fifo_data_count),
        .m_arvalid(dma_arvalid), .m_arready(dma_arready), .m_araddr(dma_araddr), .m_arid(dma_arid), .m_arlen(dma_arlen), .m_arsize(dma_arsize), .m_arburst(dma_arburst),
        .m_rvalid(dma_rvalid), .m_rready(dma_rready), .m_rdata(dma_rdata), .m_rid(dma_rid), .m_rresp(dma_rresp), .m_rlast(dma_rlast),
        .m_awvalid(dma_awvalid), .m_awready(dma_awready), .m_awaddr(dma_awaddr), .m_awid(dma_awid), .m_awlen(dma_awlen), .m_awsize(dma_awsize), .m_awburst(dma_awburst),
        .m_wvalid(dma_wvalid), .m_wready(dma_wready), .m_wdata(dma_wdata), .m_wstrb(dma_wstrb), .m_wlast(dma_wlast),
        .m_bvalid(dma_bvalid), .m_bready(dma_bready), .m_bid(dma_bid), .m_bresp(dma_bresp)
    );

    sync_fifo #(.DEPTH(256), .WIDTH(32)) u_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr_en(fifo_wr_en), .wr_data(fifo_wr_data), .full(fifo_full), .almost_full(),
        .rd_en(fifo_rd_en), .rd_data(fifo_rd_data), .empty(fifo_empty), .almost_empty(),
        .data_count(fifo_data_count)
    );

    dma_intr u_intr (
        .clk(clk), .rst_n(rst_n),
        .dma_done(dma_done), .dma_error(dma_error),
        .done_ie(done_ie), .err_ie(err_ie),
        .done_clr(done_clr), .err_clr(err_clr),
        .intr_done(), .intr_error(), .intr_out(irq)
    );

endmodule
