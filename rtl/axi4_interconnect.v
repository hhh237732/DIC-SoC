`include "axi4_defines.vh"

// ================================================================
// 模块名称：axi4_interconnect
// 功能说明：
//   2主3从AXI4互联，读写独立。
//   - 地址解码（S0/S1/S2）
//   - 每个从机AW/AR优先级仲裁（M0优先）
//   - ID扩展：送从机ID = {master_sel, master_id}
//   - B/R根据ID最高位返回对应主机
//   - 地址非法请求返回DECERR
// ================================================================
module axi4_interconnect #(
    parameter SLV0_BASE = `SLAVE0_BASE,
    parameter SLV0_HIGH = `SLAVE0_HIGH,
    parameter SLV1_BASE = `SLAVE1_BASE,
    parameter SLV1_HIGH = `SLAVE1_HIGH,
    parameter SLV2_BASE = `SLAVE2_BASE,
    parameter SLV2_HIGH = `SLAVE2_HIGH
) (
    input clk,
    input rst_n,

    // ---------------- Master0 ----------------
    input         m0_awvalid,
    output        m0_awready,
    input  [31:0] m0_awaddr,
    input  [3:0]  m0_awid,
    input  [7:0]  m0_awlen,
    input  [2:0]  m0_awsize,
    input  [1:0]  m0_awburst,
    input         m0_wvalid,
    output        m0_wready,
    input  [31:0] m0_wdata,
    input  [3:0]  m0_wstrb,
    input         m0_wlast,
    output reg    m0_bvalid,
    input         m0_bready,
    output reg [3:0] m0_bid,
    output reg [1:0] m0_bresp,

    input         m0_arvalid,
    output        m0_arready,
    input  [31:0] m0_araddr,
    input  [3:0]  m0_arid,
    input  [7:0]  m0_arlen,
    input  [2:0]  m0_arsize,
    input  [1:0]  m0_arburst,
    output reg    m0_rvalid,
    input         m0_rready,
    output reg [31:0] m0_rdata,
    output reg [3:0]  m0_rid,
    output reg [1:0]  m0_rresp,
    output reg        m0_rlast,

    // ---------------- Master1 ----------------
    input         m1_awvalid,
    output        m1_awready,
    input  [31:0] m1_awaddr,
    input  [3:0]  m1_awid,
    input  [7:0]  m1_awlen,
    input  [2:0]  m1_awsize,
    input  [1:0]  m1_awburst,
    input         m1_wvalid,
    output        m1_wready,
    input  [31:0] m1_wdata,
    input  [3:0]  m1_wstrb,
    input         m1_wlast,
    output reg    m1_bvalid,
    input         m1_bready,
    output reg [3:0] m1_bid,
    output reg [1:0] m1_bresp,

    input         m1_arvalid,
    output        m1_arready,
    input  [31:0] m1_araddr,
    input  [3:0]  m1_arid,
    input  [7:0]  m1_arlen,
    input  [2:0]  m1_arsize,
    input  [1:0]  m1_arburst,
    output reg    m1_rvalid,
    input         m1_rready,
    output reg [31:0] m1_rdata,
    output reg [3:0]  m1_rid,
    output reg [1:0]  m1_rresp,
    output reg        m1_rlast,

    // ---------------- Slave0 ----------------
    output        s0_awvalid,
    input         s0_awready,
    output [31:0] s0_awaddr,
    output [4:0]  s0_awid,
    output [7:0]  s0_awlen,
    output [2:0]  s0_awsize,
    output [1:0]  s0_awburst,
    output        s0_wvalid,
    input         s0_wready,
    output [31:0] s0_wdata,
    output [3:0]  s0_wstrb,
    output        s0_wlast,
    input         s0_bvalid,
    output        s0_bready,
    input  [4:0]  s0_bid,
    input  [1:0]  s0_bresp,
    output        s0_arvalid,
    input         s0_arready,
    output [31:0] s0_araddr,
    output [4:0]  s0_arid,
    output [7:0]  s0_arlen,
    output [2:0]  s0_arsize,
    output [1:0]  s0_arburst,
    input         s0_rvalid,
    output        s0_rready,
    input  [31:0] s0_rdata,
    input  [4:0]  s0_rid,
    input  [1:0]  s0_rresp,
    input         s0_rlast,

    // ---------------- Slave1 ----------------
    output        s1_awvalid,
    input         s1_awready,
    output [31:0] s1_awaddr,
    output [4:0]  s1_awid,
    output [7:0]  s1_awlen,
    output [2:0]  s1_awsize,
    output [1:0]  s1_awburst,
    output        s1_wvalid,
    input         s1_wready,
    output [31:0] s1_wdata,
    output [3:0]  s1_wstrb,
    output        s1_wlast,
    input         s1_bvalid,
    output        s1_bready,
    input  [4:0]  s1_bid,
    input  [1:0]  s1_bresp,
    output        s1_arvalid,
    input         s1_arready,
    output [31:0] s1_araddr,
    output [4:0]  s1_arid,
    output [7:0]  s1_arlen,
    output [2:0]  s1_arsize,
    output [1:0]  s1_arburst,
    input         s1_rvalid,
    output        s1_rready,
    input  [31:0] s1_rdata,
    input  [4:0]  s1_rid,
    input  [1:0]  s1_rresp,
    input         s1_rlast,

    // ---------------- Slave2 ----------------
    output        s2_awvalid,
    input         s2_awready,
    output [31:0] s2_awaddr,
    output [4:0]  s2_awid,
    output [7:0]  s2_awlen,
    output [2:0]  s2_awsize,
    output [1:0]  s2_awburst,
    output        s2_wvalid,
    input         s2_wready,
    output [31:0] s2_wdata,
    output [3:0]  s2_wstrb,
    output        s2_wlast,
    input         s2_bvalid,
    output        s2_bready,
    input  [4:0]  s2_bid,
    input  [1:0]  s2_bresp,
    output        s2_arvalid,
    input         s2_arready,
    output [31:0] s2_araddr,
    output [4:0]  s2_arid,
    output [7:0]  s2_arlen,
    output [2:0]  s2_arsize,
    output [1:0]  s2_arburst,
    input         s2_rvalid,
    output        s2_rready,
    input  [31:0] s2_rdata,
    input  [4:0]  s2_rid,
    input  [1:0]  s2_rresp,
    input         s2_rlast
);

    function [1:0] dec_slave;
        input [31:0] addr;
        begin
            if ((addr >= SLV0_BASE) && (addr <= SLV0_HIGH)) dec_slave = 2'd0;
            else if ((addr >= SLV1_BASE) && (addr <= SLV1_HIGH)) dec_slave = 2'd1;
            else if ((addr >= SLV2_BASE) && (addr <= SLV2_HIGH)) dec_slave = 2'd2;
            else dec_slave = 2'd3;
        end
    endfunction

    // 写通道每个从机的授权持有者
    reg wr_busy0, wr_busy1, wr_busy2;
    reg wr_owner0, wr_owner1, wr_owner2; // 0:m0 1:m1

    // 读地址通道每个从机授权
    wire [1:0] aw_sel0 = dec_slave(m0_awaddr);
    wire [1:0] aw_sel1 = dec_slave(m1_awaddr);
    wire [1:0] ar_sel0 = dec_slave(m0_araddr);
    wire [1:0] ar_sel1 = dec_slave(m1_araddr);

    wire m0_aw_to_s0 = m0_awvalid && (aw_sel0 == 2'd0) && !wr_busy0;
    wire m0_aw_to_s1 = m0_awvalid && (aw_sel0 == 2'd1) && !wr_busy1;
    wire m0_aw_to_s2 = m0_awvalid && (aw_sel0 == 2'd2) && !wr_busy2;

    wire m1_aw_to_s0 = m1_awvalid && (aw_sel1 == 2'd0) && !wr_busy0 && !m0_aw_to_s0;
    wire m1_aw_to_s1 = m1_awvalid && (aw_sel1 == 2'd1) && !wr_busy1 && !m0_aw_to_s1;
    wire m1_aw_to_s2 = m1_awvalid && (aw_sel1 == 2'd2) && !wr_busy2 && !m0_aw_to_s2;

    assign s0_awvalid = m0_aw_to_s0 || m1_aw_to_s0;
    assign s1_awvalid = m0_aw_to_s1 || m1_aw_to_s1;
    assign s2_awvalid = m0_aw_to_s2 || m1_aw_to_s2;

    assign s0_awaddr  = m0_aw_to_s0 ? m0_awaddr : m1_awaddr;
    assign s1_awaddr  = m0_aw_to_s1 ? m0_awaddr : m1_awaddr;
    assign s2_awaddr  = m0_aw_to_s2 ? m0_awaddr : m1_awaddr;

    assign s0_awid    = m0_aw_to_s0 ? {1'b0,m0_awid} : {1'b1,m1_awid};
    assign s1_awid    = m0_aw_to_s1 ? {1'b0,m0_awid} : {1'b1,m1_awid};
    assign s2_awid    = m0_aw_to_s2 ? {1'b0,m0_awid} : {1'b1,m1_awid};

    assign s0_awlen   = m0_aw_to_s0 ? m0_awlen : m1_awlen;
    assign s1_awlen   = m0_aw_to_s1 ? m0_awlen : m1_awlen;
    assign s2_awlen   = m0_aw_to_s2 ? m0_awlen : m1_awlen;
    assign s0_awsize  = m0_aw_to_s0 ? m0_awsize : m1_awsize;
    assign s1_awsize  = m0_aw_to_s1 ? m0_awsize : m1_awsize;
    assign s2_awsize  = m0_aw_to_s2 ? m0_awsize : m1_awsize;
    assign s0_awburst = m0_aw_to_s0 ? m0_awburst : m1_awburst;
    assign s1_awburst = m0_aw_to_s1 ? m0_awburst : m1_awburst;
    assign s2_awburst = m0_aw_to_s2 ? m0_awburst : m1_awburst;

    assign m0_awready = (m0_aw_to_s0 && s0_awready) || (m0_aw_to_s1 && s1_awready) || (m0_aw_to_s2 && s2_awready) || (m0_awvalid && (aw_sel0==2'd3));
    assign m1_awready = (m1_aw_to_s0 && s0_awready) || (m1_aw_to_s1 && s1_awready) || (m1_aw_to_s2 && s2_awready) || (m1_awvalid && (aw_sel1==2'd3));

    // W通道跟随对应写事务owner
    assign s0_wvalid = wr_busy0 ? (wr_owner0 ? m1_wvalid : m0_wvalid) : 1'b0;
    assign s1_wvalid = wr_busy1 ? (wr_owner1 ? m1_wvalid : m0_wvalid) : 1'b0;
    assign s2_wvalid = wr_busy2 ? (wr_owner2 ? m1_wvalid : m0_wvalid) : 1'b0;

    assign s0_wdata  = wr_owner0 ? m1_wdata : m0_wdata;
    assign s1_wdata  = wr_owner1 ? m1_wdata : m0_wdata;
    assign s2_wdata  = wr_owner2 ? m1_wdata : m0_wdata;
    assign s0_wstrb  = wr_owner0 ? m1_wstrb : m0_wstrb;
    assign s1_wstrb  = wr_owner1 ? m1_wstrb : m0_wstrb;
    assign s2_wstrb  = wr_owner2 ? m1_wstrb : m0_wstrb;
    assign s0_wlast  = wr_owner0 ? m1_wlast : m0_wlast;
    assign s1_wlast  = wr_owner1 ? m1_wlast : m0_wlast;
    assign s2_wlast  = wr_owner2 ? m1_wlast : m0_wlast;

    assign m0_wready = (wr_busy0 && !wr_owner0 && s0_wready) || (wr_busy1 && !wr_owner1 && s1_wready) || (wr_busy2 && !wr_owner2 && s2_wready);
    assign m1_wready = (wr_busy0 &&  wr_owner0 && s0_wready) || (wr_busy1 &&  wr_owner1 && s1_wready) || (wr_busy2 &&  wr_owner2 && s2_wready);

    // B通道路由
    assign s0_bready = (s0_bid[4] == 1'b0) ? m0_bready : m1_bready;
    assign s1_bready = (s1_bid[4] == 1'b0) ? m0_bready : m1_bready;
    assign s2_bready = (s2_bid[4] == 1'b0) ? m0_bready : m1_bready;

    // AR仲裁（M0优先）
    wire m0_ar_to_s0 = m0_arvalid && (ar_sel0 == 2'd0);
    wire m0_ar_to_s1 = m0_arvalid && (ar_sel0 == 2'd1);
    wire m0_ar_to_s2 = m0_arvalid && (ar_sel0 == 2'd2);

    wire m1_ar_to_s0 = m1_arvalid && (ar_sel1 == 2'd0) && !m0_ar_to_s0;
    wire m1_ar_to_s1 = m1_arvalid && (ar_sel1 == 2'd1) && !m0_ar_to_s1;
    wire m1_ar_to_s2 = m1_arvalid && (ar_sel1 == 2'd2) && !m0_ar_to_s2;

    assign s0_arvalid = m0_ar_to_s0 || m1_ar_to_s0;
    assign s1_arvalid = m0_ar_to_s1 || m1_ar_to_s1;
    assign s2_arvalid = m0_ar_to_s2 || m1_ar_to_s2;

    assign s0_araddr  = m0_ar_to_s0 ? m0_araddr : m1_araddr;
    assign s1_araddr  = m0_ar_to_s1 ? m0_araddr : m1_araddr;
    assign s2_araddr  = m0_ar_to_s2 ? m0_araddr : m1_araddr;
    assign s0_arid    = m0_ar_to_s0 ? {1'b0,m0_arid} : {1'b1,m1_arid};
    assign s1_arid    = m0_ar_to_s1 ? {1'b0,m0_arid} : {1'b1,m1_arid};
    assign s2_arid    = m0_ar_to_s2 ? {1'b0,m0_arid} : {1'b1,m1_arid};
    assign s0_arlen   = m0_ar_to_s0 ? m0_arlen : m1_arlen;
    assign s1_arlen   = m0_ar_to_s1 ? m0_arlen : m1_arlen;
    assign s2_arlen   = m0_ar_to_s2 ? m0_arlen : m1_arlen;
    assign s0_arsize  = m0_ar_to_s0 ? m0_arsize : m1_arsize;
    assign s1_arsize  = m0_ar_to_s1 ? m0_arsize : m1_arsize;
    assign s2_arsize  = m0_ar_to_s2 ? m0_arsize : m1_arsize;
    assign s0_arburst = m0_ar_to_s0 ? m0_arburst : m1_arburst;
    assign s1_arburst = m0_ar_to_s1 ? m0_arburst : m1_arburst;
    assign s2_arburst = m0_ar_to_s2 ? m0_arburst : m1_arburst;

    assign m0_arready = (m0_ar_to_s0 && s0_arready) || (m0_ar_to_s1 && s1_arready) || (m0_ar_to_s2 && s2_arready) || (m0_arvalid && (ar_sel0==2'd3));
    assign m1_arready = (m1_ar_to_s0 && s0_arready) || (m1_ar_to_s1 && s1_arready) || (m1_ar_to_s2 && s2_arready) || (m1_arvalid && (ar_sel1==2'd3));

    assign s0_rready = (s0_rid[4] == 1'b0) ? m0_rready : m1_rready;
    assign s1_rready = (s1_rid[4] == 1'b0) ? m0_rready : m1_rready;
    assign s2_rready = (s2_rid[4] == 1'b0) ? m0_rready : m1_rready;

    // DECERR响应
    reg m0_decerr_bvalid, m1_decerr_bvalid;
    reg [3:0] m0_decerr_bid, m1_decerr_bid;
    reg m0_decerr_rvalid, m1_decerr_rvalid;
    reg [3:0] m0_decerr_rid, m1_decerr_rid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_busy0 <= 1'b0; wr_busy1 <= 1'b0; wr_busy2 <= 1'b0;
            wr_owner0 <= 1'b0; wr_owner1 <= 1'b0; wr_owner2 <= 1'b0;
            m0_bvalid <= 1'b0; m1_bvalid <= 1'b0;
            m0_bresp <= `AXI_RESP_OKAY; m1_bresp <= `AXI_RESP_OKAY;
            m0_bid <= 4'd0; m1_bid <= 4'd0;
            m0_rvalid <= 1'b0; m1_rvalid <= 1'b0;
            m0_rdata <= 32'd0; m1_rdata <= 32'd0;
            m0_rresp <= `AXI_RESP_OKAY; m1_rresp <= `AXI_RESP_OKAY;
            m0_rid <= 4'd0; m1_rid <= 4'd0;
            m0_rlast <= 1'b0; m1_rlast <= 1'b0;
            m0_decerr_bvalid <= 1'b0; m1_decerr_bvalid <= 1'b0;
            m0_decerr_rvalid <= 1'b0; m1_decerr_rvalid <= 1'b0;
            m0_decerr_bid <= 4'd0; m1_decerr_bid <= 4'd0;
            m0_decerr_rid <= 4'd0; m1_decerr_rid <= 4'd0;
        end else begin
            // AW握手后锁定W owner
            if (m0_aw_to_s0 && s0_awready) begin wr_busy0 <= 1'b1; wr_owner0 <= 1'b0; end
            if (m1_aw_to_s0 && s0_awready) begin wr_busy0 <= 1'b1; wr_owner0 <= 1'b1; end
            if (m0_aw_to_s1 && s1_awready) begin wr_busy1 <= 1'b1; wr_owner1 <= 1'b0; end
            if (m1_aw_to_s1 && s1_awready) begin wr_busy1 <= 1'b1; wr_owner1 <= 1'b1; end
            if (m0_aw_to_s2 && s2_awready) begin wr_busy2 <= 1'b1; wr_owner2 <= 1'b0; end
            if (m1_aw_to_s2 && s2_awready) begin wr_busy2 <= 1'b1; wr_owner2 <= 1'b1; end

            // WLAST后释放
            if (wr_busy0 && s0_wvalid && s0_wready && s0_wlast) wr_busy0 <= 1'b0;
            if (wr_busy1 && s1_wvalid && s1_wready && s1_wlast) wr_busy1 <= 1'b0;
            if (wr_busy2 && s2_wvalid && s2_wready && s2_wlast) wr_busy2 <= 1'b0;

            // 地址非法生成DECERR
            if (m0_awvalid && m0_awready && (aw_sel0 == 2'd3)) begin m0_decerr_bvalid <= 1'b1; m0_decerr_bid <= m0_awid; end
            if (m1_awvalid && m1_awready && (aw_sel1 == 2'd3)) begin m1_decerr_bvalid <= 1'b1; m1_decerr_bid <= m1_awid; end
            if (m0_arvalid && m0_arready && (ar_sel0 == 2'd3)) begin m0_decerr_rvalid <= 1'b1; m0_decerr_rid <= m0_arid; end
            if (m1_arvalid && m1_arready && (ar_sel1 == 2'd3)) begin m1_decerr_rvalid <= 1'b1; m1_decerr_rid <= m1_arid; end

            if (m0_decerr_bvalid && m0_bready) m0_decerr_bvalid <= 1'b0;
            if (m1_decerr_bvalid && m1_bready) m1_decerr_bvalid <= 1'b0;
            if (m0_decerr_rvalid && m0_rready) m0_decerr_rvalid <= 1'b0;
            if (m1_decerr_rvalid && m1_rready) m1_decerr_rvalid <= 1'b0;

            // 默认输出
            m0_bvalid <= 1'b0; m1_bvalid <= 1'b0;
            m0_rvalid <= 1'b0; m1_rvalid <= 1'b0;

            // B回路（一次只处理一个）
            if (s0_bvalid) begin
                if (!s0_bid[4]) begin m0_bvalid <= 1'b1; m0_bid <= s0_bid[3:0]; m0_bresp <= s0_bresp; end
                else begin m1_bvalid <= 1'b1; m1_bid <= s0_bid[3:0]; m1_bresp <= s0_bresp; end
            end else if (s1_bvalid) begin
                if (!s1_bid[4]) begin m0_bvalid <= 1'b1; m0_bid <= s1_bid[3:0]; m0_bresp <= s1_bresp; end
                else begin m1_bvalid <= 1'b1; m1_bid <= s1_bid[3:0]; m1_bresp <= s1_bresp; end
            end else if (s2_bvalid) begin
                if (!s2_bid[4]) begin m0_bvalid <= 1'b1; m0_bid <= s2_bid[3:0]; m0_bresp <= s2_bresp; end
                else begin m1_bvalid <= 1'b1; m1_bid <= s2_bid[3:0]; m1_bresp <= s2_bresp; end
            end

            if (m0_decerr_bvalid) begin m0_bvalid <= 1'b1; m0_bid <= m0_decerr_bid; m0_bresp <= `AXI_RESP_DECERR; end
            if (m1_decerr_bvalid) begin m1_bvalid <= 1'b1; m1_bid <= m1_decerr_bid; m1_bresp <= `AXI_RESP_DECERR; end

            // R回路
            if (s0_rvalid) begin
                if (!s0_rid[4]) begin
                    m0_rvalid <= 1'b1; m0_rid <= s0_rid[3:0]; m0_rdata <= s0_rdata; m0_rresp <= s0_rresp; m0_rlast <= s0_rlast;
                end else begin
                    m1_rvalid <= 1'b1; m1_rid <= s0_rid[3:0]; m1_rdata <= s0_rdata; m1_rresp <= s0_rresp; m1_rlast <= s0_rlast;
                end
            end else if (s1_rvalid) begin
                if (!s1_rid[4]) begin
                    m0_rvalid <= 1'b1; m0_rid <= s1_rid[3:0]; m0_rdata <= s1_rdata; m0_rresp <= s1_rresp; m0_rlast <= s1_rlast;
                end else begin
                    m1_rvalid <= 1'b1; m1_rid <= s1_rid[3:0]; m1_rdata <= s1_rdata; m1_rresp <= s1_rresp; m1_rlast <= s1_rlast;
                end
            end else if (s2_rvalid) begin
                if (!s2_rid[4]) begin
                    m0_rvalid <= 1'b1; m0_rid <= s2_rid[3:0]; m0_rdata <= s2_rdata; m0_rresp <= s2_rresp; m0_rlast <= s2_rlast;
                end else begin
                    m1_rvalid <= 1'b1; m1_rid <= s2_rid[3:0]; m1_rdata <= s2_rdata; m1_rresp <= s2_rresp; m1_rlast <= s2_rlast;
                end
            end

            if (m0_decerr_rvalid) begin
                m0_rvalid <= 1'b1; m0_rid <= m0_decerr_rid; m0_rdata <= 32'd0; m0_rresp <= `AXI_RESP_DECERR; m0_rlast <= 1'b1;
            end
            if (m1_decerr_rvalid) begin
                m1_rvalid <= 1'b1; m1_rid <= m1_decerr_rid; m1_rdata <= 32'd0; m1_rresp <= `AXI_RESP_DECERR; m1_rlast <= 1'b1;
            end
        end
    end

endmodule
