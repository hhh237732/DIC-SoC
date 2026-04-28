`include "../axi4_defines.vh"

// ================================================================
// Module: l2_arbiter
// Author: hhh237732
// Purpose: L2 cache port arbiter - round-robin between L1I (s1,
//          read-only) and L1D (s0, read+write).
//
// ID encoding: L2 slave uses 4-bit IDs.
//   bit[3]=0  -> transaction originated from s0 (L1D)
//   bit[3]=1  -> transaction originated from s1 (L1I)
//   Lower 3 bits carry the original cache ID.
//
// Read state machine:
//   RD_IDLE  - arbitrate; present winning AR to L2
//   RD_GNT0  - s0 (L1D) holds grant; route R-channel to s0
//   RD_GNT1  - s1 (L1I) holds grant; route R-channel to s1
//
// Write channel: s0 only, pure combinational pass-through.
// ================================================================
module l2_arbiter #(
    parameter NUM_MASTERS = 2,
    parameter ARB_MODE    = "RR"   // "RR" = round-robin, "FIXED" = fixed priority
)(
    input  clk,
    input  rst_n,

    // ---- Slave port 0 : L1D (read + write) ----
    input         s0_arvalid,
    output        s0_arready,
    input  [31:0] s0_araddr,
    input  [3:0]  s0_arid,
    input  [7:0]  s0_arlen,
    input  [2:0]  s0_arsize,
    input  [1:0]  s0_arburst,
    output        s0_rvalid,
    input         s0_rready,
    output [31:0] s0_rdata,
    output [3:0]  s0_rid,
    output [1:0]  s0_rresp,
    output        s0_rlast,

    input         s0_awvalid,
    output        s0_awready,
    input  [31:0] s0_awaddr,
    input  [3:0]  s0_awid,
    input  [7:0]  s0_awlen,
    input  [2:0]  s0_awsize,
    input  [1:0]  s0_awburst,
    input         s0_wvalid,
    output        s0_wready,
    input  [31:0] s0_wdata,
    input  [3:0]  s0_wstrb,
    input         s0_wlast,
    output        s0_bvalid,
    input         s0_bready,
    output [3:0]  s0_bid,
    output [1:0]  s0_bresp,

    // ---- Slave port 1 : L1I (read only) ----
    input         s1_arvalid,
    output        s1_arready,
    input  [31:0] s1_araddr,
    input  [3:0]  s1_arid,
    input  [7:0]  s1_arlen,
    input  [2:0]  s1_arsize,
    input  [1:0]  s1_arburst,
    output        s1_rvalid,
    input         s1_rready,
    output [31:0] s1_rdata,
    output [3:0]  s1_rid,
    output [1:0]  s1_rresp,
    output        s1_rlast,

    // ---- Master port : L2 cache slave ----
    output        m_arvalid,
    input         m_arready,
    output [31:0] m_araddr,
    output [3:0]  m_arid,
    output [7:0]  m_arlen,
    output [2:0]  m_arsize,
    output [1:0]  m_arburst,
    input         m_rvalid,
    output        m_rready,
    input  [31:0] m_rdata,
    input  [3:0]  m_rid,
    input  [1:0]  m_rresp,
    input         m_rlast,

    output        m_awvalid,
    input         m_awready,
    output [31:0] m_awaddr,
    output [3:0]  m_awid,
    output [7:0]  m_awlen,
    output [2:0]  m_awsize,
    output [1:0]  m_awburst,
    output        m_wvalid,
    input         m_wready,
    output [31:0] m_wdata,
    output [3:0]  m_wstrb,
    output        m_wlast,
    input         m_bvalid,
    output        m_bready,
    input  [3:0]  m_bid,
    input  [1:0]  m_bresp,

    // Debug/monitoring outputs
    output [1:0]  grant,
    output        grant_valid
);

    // Read arbitration states
    localparam RD_IDLE = 2'd0;
    localparam RD_GNT0 = 2'd1;  // s0 (L1D) holds read grant
    localparam RD_GNT1 = 2'd2;  // s1 (L1I) holds read grant

    reg [1:0] rd_state;
    reg       rr_token; // 0 = prefer s0, 1 = prefer s1

    // Arbitration decision (combinational, only meaningful in RD_IDLE)
    wire s0_wants_rd = s0_arvalid;
    wire s1_wants_rd = s1_arvalid;

    wire gnt0_rr = s0_wants_rd && (rr_token == 1'b0 || !s1_wants_rd);
    wire gnt1_rr = s1_wants_rd && (rr_token == 1'b1 || !s0_wants_rd);
    wire gnt0_fx = s0_wants_rd;
    wire gnt1_fx = s1_wants_rd && !s0_wants_rd;

    wire sel_s0 = (ARB_MODE == "RR") ? gnt0_rr : gnt0_fx;
    wire sel_s1 = (ARB_MODE == "RR") ? gnt1_rr : gnt1_fx;

    // ----------------------------------------------------------------
    // AR channel mux (active only in RD_IDLE)
    // ----------------------------------------------------------------
    assign m_arvalid = (rd_state == RD_IDLE) ?
                           (sel_s0 ? s0_arvalid :
                            sel_s1 ? s1_arvalid : 1'b0) : 1'b0;

    assign m_araddr  = (sel_s1 && rd_state == RD_IDLE) ? s1_araddr  : s0_araddr;
    assign m_arid    = (sel_s1 && rd_state == RD_IDLE) ?
                           {1'b1, s1_arid[2:0]} : {1'b0, s0_arid[2:0]};
    assign m_arlen   = (sel_s1 && rd_state == RD_IDLE) ? s1_arlen   : s0_arlen;
    assign m_arsize  = (sel_s1 && rd_state == RD_IDLE) ? s1_arsize  : s0_arsize;
    assign m_arburst = (sel_s1 && rd_state == RD_IDLE) ? s1_arburst : s0_arburst;

    // AR ready feedback to slaves (only in IDLE when they win)
    assign s0_arready = (rd_state == RD_IDLE) && sel_s0 && m_arready;
    assign s1_arready = (rd_state == RD_IDLE) && sel_s1 && !sel_s0 && m_arready;

    // ----------------------------------------------------------------
    // R channel routing by grant state
    // ----------------------------------------------------------------
    assign s0_rvalid = m_rvalid && (rd_state == RD_GNT0);
    assign s1_rvalid = m_rvalid && (rd_state == RD_GNT1);
    assign s0_rdata  = m_rdata;
    assign s1_rdata  = m_rdata;
    assign s0_rid    = m_rid;
    assign s1_rid    = m_rid;
    assign s0_rresp  = m_rresp;
    assign s1_rresp  = m_rresp;
    assign s0_rlast  = m_rlast;
    assign s1_rlast  = m_rlast;
    assign m_rready  = (rd_state == RD_GNT0) ? s0_rready :
                       (rd_state == RD_GNT1) ? s1_rready : 1'b1;

    // ----------------------------------------------------------------
    // Write channel: s0 (L1D) only - combinational pass-through
    // ----------------------------------------------------------------
    assign m_awvalid  = s0_awvalid;
    assign m_awaddr   = s0_awaddr;
    assign m_awid     = {1'b0, s0_awid[2:0]};
    assign m_awlen    = s0_awlen;
    assign m_awsize   = s0_awsize;
    assign m_awburst  = s0_awburst;
    assign s0_awready = m_awready;

    assign m_wvalid   = s0_wvalid;
    assign m_wdata    = s0_wdata;
    assign m_wstrb    = s0_wstrb;
    assign m_wlast    = s0_wlast;
    assign s0_wready  = m_wready;

    assign s0_bvalid  = m_bvalid;
    assign s0_bid     = m_bid;
    assign s0_bresp   = m_bresp;
    assign m_bready   = s0_bready;

    // ----------------------------------------------------------------
    // Debug outputs
    // ----------------------------------------------------------------
    assign grant       = (rd_state == RD_GNT0) ? 2'd1 :
                         (rd_state == RD_GNT1) ? 2'd2 : 2'd0;
    assign grant_valid = (rd_state != RD_IDLE);

    // ----------------------------------------------------------------
    // Read arbitration state machine
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state <= RD_IDLE;
            rr_token <= 1'b0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    if (sel_s0 && s0_arvalid && m_arready) begin
                        rd_state <= RD_GNT0;
                        if (ARB_MODE == "RR") rr_token <= 1'b1;
                    end else if (sel_s1 && s1_arvalid && m_arready) begin
                        rd_state <= RD_GNT1;
                        if (ARB_MODE == "RR") rr_token <= 1'b0;
                    end
                end
                RD_GNT0: begin
                    if (m_rvalid && s0_rready && m_rlast)
                        rd_state <= RD_IDLE;
                end
                RD_GNT1: begin
                    if (m_rvalid && s1_rready && m_rlast)
                        rd_state <= RD_IDLE;
                end
                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule
