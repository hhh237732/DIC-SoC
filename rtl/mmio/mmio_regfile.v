`include "axi4_defines.vh"

// ================================================================
// Module: mmio_regfile
// Author: hhh237732
// Purpose: AXI4-Lite slave MMIO register file.
//
// Register map (byte address relative to slave base 0x4000_1000):
//   0x00 ID_REG        RO  32'h444D4153 ("DMAS")
//   0x04 VERSION       RO  32'h00000109 (v1.9)
//   0x08 SCRATCH       RW  general-purpose scratch
//   0x0C IRQ_STATUS    W1C DMA IRQ sticky bit (write 1 to clear)
//   0x10 PERF_HIT_L1I  RO  L1I hit counter
//   0x14 PERF_MISS_L1I RO  L1I miss counter
//   0x18 PERF_HIT_L1D  RO  L1D hit counter
//   0x1C PERF_MISS_L1D RO  L1D miss counter
//   0x20 PERF_HIT_L2   RO  L2 hit counter
//   0x24 PERF_MISS_L2  RO  L2 miss counter
//   0x40 DMA_CTRL      RO  DMA control shadow
//   0x44 DMA_STATUS    RO  DMA status shadow (from dma_status_in)
//   0x48 DMA_SRC       RW  DMA source address shadow
//   0x4C DMA_DST       RW  DMA destination address shadow
//   0x50 DMA_LEN       RW  DMA length shadow
//
// Write channel state machine: W_IDLE -> W_WAIT -> W_RESP
// Read channel state machine:  R_IDLE -> R_DATA
// ================================================================
module mmio_regfile (
    input  clk,
    input  rst_n,

    // AXI4-Lite slave (single beats only; burst len ignored)
    input         s_awvalid,
    output reg    s_awready,
    input  [31:0] s_awaddr,
    input  [4:0]  s_awid,
    input  [7:0]  s_awlen,
    input  [2:0]  s_awsize,
    input  [1:0]  s_awburst,

    input         s_wvalid,
    output reg    s_wready,
    input  [31:0] s_wdata,
    input  [3:0]  s_wstrb,

    output reg    s_bvalid,
    input         s_bready,
    output reg [4:0] s_bid,
    output reg [1:0] s_bresp,

    input         s_arvalid,
    output reg    s_arready,
    input  [31:0] s_araddr,
    input  [4:0]  s_arid,
    input  [7:0]  s_arlen,
    input  [2:0]  s_arsize,
    input  [1:0]  s_arburst,

    output reg    s_rvalid,
    input         s_rready,
    output reg [31:0] s_rdata,
    output reg [4:0]  s_rid,
    output reg [1:0]  s_rresp,
    output reg        s_rlast,

    // Performance counter inputs
    input [31:0] l1i_hit_cnt,
    input [31:0] l1i_miss_cnt,
    input [31:0] l1d_hit_cnt,
    input [31:0] l1d_miss_cnt,
    input [31:0] l2_hit_cnt,
    input [31:0] l2_miss_cnt,

    // IRQ status input
    input        dma_irq,

    // DMA status shadow input
    input [31:0] dma_status_in
);

    // Read/write channel state machines
    localparam W_IDLE = 2'd0;
    localparam W_WAIT = 2'd1; // waiting for W data after AW accepted
    localparam W_RESP = 2'd2;
    localparam R_IDLE = 1'd0;
    localparam R_DATA = 1'd1;

    reg [1:0] w_state;
    reg       r_state;

    // Latched AW/W info
    reg [31:0] aw_addr_lat;
    reg [4:0]  aw_id_lat;
    reg [31:0] wdata_lat;
    reg [3:0]  wstrb_lat;

    // RW registers
    reg [31:0] reg_scratch;
    reg        reg_irq_status; // sticky, W1C
    reg [31:0] reg_dma_src;
    reg [31:0] reg_dma_dst;
    reg [31:0] reg_dma_len;

    // IRQ sticky capture
    reg dma_irq_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) dma_irq_r <= 1'b0;
        else        dma_irq_r <= dma_irq;
    end

    // Offset from slave base (use lower 8 bits)
    wire [7:0] wr_off = aw_addr_lat[7:0];
    wire [7:0] rd_off; // assigned from latched AR addr

    // Latched AR info
    reg [31:0] ar_addr_lat;
    reg [4:0]  ar_id_lat;
    assign rd_off = ar_addr_lat[7:0];

    // ----------------------------------------------------------------
    // Write channel state machine
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_state       <= W_IDLE;
            s_awready     <= 1'b0;
            s_wready      <= 1'b0;
            s_bvalid      <= 1'b0;
            s_bid         <= 5'd0;
            s_bresp       <= `AXI_RESP_OKAY;
            aw_addr_lat   <= 32'd0;
            aw_id_lat     <= 5'd0;
            wdata_lat     <= 32'd0;
            wstrb_lat     <= 4'd0;
            reg_scratch   <= 32'd0;
            reg_irq_status<= 1'b0;
            reg_dma_src   <= 32'd0;
            reg_dma_dst   <= 32'd0;
            reg_dma_len   <= 32'd0;
        end else begin
            // IRQ sticky set
            if (dma_irq && !dma_irq_r)
                reg_irq_status <= 1'b1;

            case (w_state)
                W_IDLE: begin
                    s_awready <= 1'b1;
                    s_wready  <= 1'b0;
                    if (s_awvalid && s_awready) begin
                        aw_addr_lat <= s_awaddr;
                        aw_id_lat   <= s_awid;
                        s_awready   <= 1'b0;
                        s_wready    <= 1'b1;
                        w_state     <= W_WAIT;
                    end
                end
                W_WAIT: begin
                    if (s_wvalid && s_wready) begin
                        wdata_lat <= s_wdata;
                        wstrb_lat <= s_wstrb;
                        s_wready  <= 1'b0;
                        // Register write decode
                        case (wr_off)
                            8'h08: begin // SCRATCH
                                if (s_wstrb[0]) reg_scratch[7:0]   <= s_wdata[7:0];
                                if (s_wstrb[1]) reg_scratch[15:8]  <= s_wdata[15:8];
                                if (s_wstrb[2]) reg_scratch[23:16] <= s_wdata[23:16];
                                if (s_wstrb[3]) reg_scratch[31:24] <= s_wdata[31:24];
                            end
                            8'h0C: begin // IRQ_STATUS W1C
                                if (s_wstrb[0] && s_wdata[0]) reg_irq_status <= 1'b0;
                            end
                            8'h48: begin // DMA_SRC shadow
                                if (s_wstrb[0]) reg_dma_src[7:0]   <= s_wdata[7:0];
                                if (s_wstrb[1]) reg_dma_src[15:8]  <= s_wdata[15:8];
                                if (s_wstrb[2]) reg_dma_src[23:16] <= s_wdata[23:16];
                                if (s_wstrb[3]) reg_dma_src[31:24] <= s_wdata[31:24];
                            end
                            8'h4C: begin // DMA_DST shadow
                                if (s_wstrb[0]) reg_dma_dst[7:0]   <= s_wdata[7:0];
                                if (s_wstrb[1]) reg_dma_dst[15:8]  <= s_wdata[15:8];
                                if (s_wstrb[2]) reg_dma_dst[23:16] <= s_wdata[23:16];
                                if (s_wstrb[3]) reg_dma_dst[31:24] <= s_wdata[31:24];
                            end
                            8'h50: begin // DMA_LEN shadow
                                if (s_wstrb[0]) reg_dma_len[7:0]   <= s_wdata[7:0];
                                if (s_wstrb[1]) reg_dma_len[15:8]  <= s_wdata[15:8];
                                if (s_wstrb[2]) reg_dma_len[23:16] <= s_wdata[23:16];
                                if (s_wstrb[3]) reg_dma_len[31:24] <= s_wdata[31:24];
                            end
                            default:; // read-only or reserved: ignore
                        endcase
                        s_bvalid <= 1'b1;
                        s_bid    <= aw_id_lat;
                        s_bresp  <= `AXI_RESP_OKAY;
                        w_state  <= W_RESP;
                    end
                end
                W_RESP: begin
                    if (s_bvalid && s_bready) begin
                        s_bvalid <= 1'b0;
                        w_state  <= W_IDLE;
                    end
                end
                default: w_state <= W_IDLE;
            endcase
        end
    end

    // ----------------------------------------------------------------
    // Read channel state machine
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state     <= R_IDLE;
            s_arready   <= 1'b0;
            s_rvalid    <= 1'b0;
            s_rdata     <= 32'd0;
            s_rid       <= 5'd0;
            s_rresp     <= `AXI_RESP_OKAY;
            s_rlast     <= 1'b0;
            ar_addr_lat <= 32'd0;
            ar_id_lat   <= 5'd0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    s_arready <= 1'b1;
                    if (s_arvalid && s_arready) begin
                        ar_addr_lat <= s_araddr;
                        ar_id_lat   <= s_arid;
                        s_arready   <= 1'b0;
                        r_state     <= R_DATA;
                    end
                end
                R_DATA: begin
                    s_rvalid <= 1'b1;
                    s_rid    <= ar_id_lat;
                    s_rresp  <= `AXI_RESP_OKAY;
                    s_rlast  <= 1'b1;
                    // Register read decode
                    case (rd_off)
                        8'h00: s_rdata <= 32'h444D4153; // ID "DMAS"
                        8'h04: s_rdata <= 32'h00000109; // VERSION v1.9
                        8'h08: s_rdata <= reg_scratch;
                        8'h0C: s_rdata <= {31'd0, reg_irq_status};
                        8'h10: s_rdata <= l1i_hit_cnt;
                        8'h14: s_rdata <= l1i_miss_cnt;
                        8'h18: s_rdata <= l1d_hit_cnt;
                        8'h1C: s_rdata <= l1d_miss_cnt;
                        8'h20: s_rdata <= l2_hit_cnt;
                        8'h24: s_rdata <= l2_miss_cnt;
                        8'h40: s_rdata <= 32'd0;          // DMA_CTRL shadow (unused)
                        8'h44: s_rdata <= dma_status_in;
                        8'h48: s_rdata <= reg_dma_src;
                        8'h4C: s_rdata <= reg_dma_dst;
                        8'h50: s_rdata <= reg_dma_len;
                        default: s_rdata <= 32'hDEAD_BEEF;
                    endcase
                    if (s_rvalid && s_rready) begin
                        s_rvalid <= 1'b0;
                        s_rlast  <= 1'b0;
                        r_state  <= R_IDLE;
                    end
                end
                default: r_state <= R_IDLE;
            endcase
        end
    end

endmodule
