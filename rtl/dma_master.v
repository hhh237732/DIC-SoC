`include "axi4_defines.vh"

// ================================================================
// 模块名称：dma_master
// 功能说明：
//   DMA AXI4主控，读源地址数据写入FIFO，再从FIFO写往目标地址。
//   - 支持4KB边界拆分
//   - 读写状态机并行运行
//   - 错误脉冲输出（RRESP/BRESP非OKAY）
// ================================================================
module dma_master (
    input         clk,
    input         rst_n,
    input         dma_start,
    input         dma_abort,
    input  [31:0] src_addr,
    input  [31:0] dst_addr,
    input  [31:0] length,
    output        dma_busy,
    output reg    dma_done,
    output reg    dma_error,

    output reg        fifo_wr_en,
    output reg [31:0] fifo_wr_data,
    input             fifo_full,
    output reg        fifo_rd_en,
    input      [31:0] fifo_rd_data,
    input             fifo_empty,
    input      [8:0]  fifo_data_count,

    // AR
    output reg        m_arvalid,
    input             m_arready,
    output reg [31:0] m_araddr,
    output [3:0]      m_arid,
    output reg [7:0]  m_arlen,
    output [2:0]      m_arsize,
    output [1:0]      m_arburst,
    // R
    input             m_rvalid,
    output            m_rready,
    input      [31:0] m_rdata,
    input      [3:0]  m_rid,
    input      [1:0]  m_rresp,
    input             m_rlast,
    // AW
    output reg        m_awvalid,
    input             m_awready,
    output reg [31:0] m_awaddr,
    output [3:0]      m_awid,
    output reg [7:0]  m_awlen,
    output [2:0]      m_awsize,
    output [1:0]      m_awburst,
    // W
    output reg        m_wvalid,
    input             m_wready,
    output reg [31:0] m_wdata,
    output [3:0]      m_wstrb,
    output reg        m_wlast,
    // B
    input             m_bvalid,
    output reg        m_bready,
    input      [3:0]  m_bid,
    input      [1:0]  m_bresp
);

    localparam RD_IDLE = 2'd0, RD_ADDR = 2'd1, RD_DATA = 2'd2, RD_DONE = 2'd3;
    localparam WR_IDLE = 3'd0, WR_WAIT = 3'd1, WR_ADDR = 3'd2, WR_DATA = 3'd3, WR_RESP = 3'd4, WR_DONE = 3'd5;

    reg [1:0] rd_state;
    reg [2:0] wr_state;

    reg [31:0] rd_curr_addr;
    reg [31:0] wr_curr_addr;
    reg [31:0] rd_rem_words;
    reg [31:0] wr_rem_words;
    reg [8:0]  rd_beats_left;
    reg [8:0]  wr_beats_left;
    reg [8:0]  wr_beats_total;

    wire start_ok = dma_start && (length[1:0] == 2'b00) && (length != 32'd0);

    function [8:0] calc_beats;
        input [31:0] addr;
        input [31:0] remain_words;
        reg [11:0]   off;
        reg [8:0]    by_4k;
        reg [31:0]   minv;
        begin
            off   = addr[11:0];
            by_4k = (12'd4096 - off) >> 2;
            minv  = remain_words;
            if (minv > by_4k) minv = by_4k;
            if (minv > 32'd256) minv = 32'd256;
            calc_beats = minv[8:0];
        end
    endfunction

    assign m_arid    = 4'h1;
    assign m_arsize  = 3'd2;
    assign m_arburst = `AXI_BURST_INCR;
    assign m_awid    = 4'h1;
    assign m_awsize  = 3'd2;
    assign m_awburst = `AXI_BURST_INCR;
    assign m_wstrb   = 4'hF;

    assign m_rready  = (rd_state == RD_DATA) && !fifo_full;

    assign dma_busy = (rd_state != RD_IDLE) || (wr_state != WR_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state      <= RD_IDLE;
            wr_state      <= WR_IDLE;
            rd_curr_addr  <= 32'd0;
            wr_curr_addr  <= 32'd0;
            rd_rem_words  <= 32'd0;
            wr_rem_words  <= 32'd0;
            rd_beats_left <= 9'd0;
            wr_beats_left <= 9'd0;
            wr_beats_total<= 9'd0;

            m_arvalid     <= 1'b0;
            m_araddr      <= 32'd0;
            m_arlen       <= 8'd0;
            m_awvalid     <= 1'b0;
            m_awaddr      <= 32'd0;
            m_awlen       <= 8'd0;
            m_wvalid      <= 1'b0;
            m_wdata       <= 32'd0;
            m_wlast       <= 1'b0;
            m_bready      <= 1'b0;

            fifo_wr_en    <= 1'b0;
            fifo_wr_data  <= 32'd0;
            fifo_rd_en    <= 1'b0;

            dma_done      <= 1'b0;
            dma_error     <= 1'b0;
        end else begin
            fifo_wr_en <= 1'b0;
            fifo_rd_en <= 1'b0;
            dma_done   <= 1'b0;
            dma_error  <= 1'b0;

            if (dma_abort) begin
                rd_state  <= RD_IDLE;
                wr_state  <= WR_IDLE;
                m_arvalid <= 1'b0;
                m_awvalid <= 1'b0;
                m_wvalid  <= 1'b0;
                m_bready  <= 1'b0;
            end else if (start_ok && (rd_state == RD_IDLE) && (wr_state == WR_IDLE)) begin
                rd_curr_addr <= src_addr;
                wr_curr_addr <= dst_addr;
                rd_rem_words <= length >> 2;
                wr_rem_words <= length >> 2;
                rd_state     <= RD_ADDR;
                wr_state     <= WR_WAIT;
            end

            // ---------------- 读状态机 ----------------
            case (rd_state)
                RD_IDLE: begin
                    m_arvalid <= 1'b0;
                end
                RD_ADDR: begin
                    if (!m_arvalid && (rd_rem_words != 0)) begin
                        rd_beats_left <= calc_beats(rd_curr_addr, rd_rem_words);
                        m_araddr      <= rd_curr_addr;
                        m_arlen       <= calc_beats(rd_curr_addr, rd_rem_words) - 1'b1;
                        m_arvalid     <= 1'b1;
                    end
                    if (m_arvalid && m_arready) begin
                        m_arvalid <= 1'b0;
                        rd_state  <= RD_DATA;
                    end
                    if (rd_rem_words == 0) rd_state <= RD_DONE;
                end
                RD_DATA: begin
                    if (m_rvalid && m_rready) begin
                        fifo_wr_en   <= 1'b1;
                        fifo_wr_data <= m_rdata;
                        if (m_rresp != `AXI_RESP_OKAY) dma_error <= 1'b1;
                        if (rd_beats_left != 0) rd_beats_left <= rd_beats_left - 1'b1;
                        if (m_rlast) begin
                            rd_curr_addr <= rd_curr_addr + ((m_arlen + 1'b1) << 2);
                            rd_rem_words <= rd_rem_words - (m_arlen + 1'b1);
                            rd_state     <= (rd_rem_words == (m_arlen + 1'b1)) ? RD_DONE : RD_ADDR;
                        end
                    end
                end
                RD_DONE: begin
                    // 等待写侧完成
                end
                default: rd_state <= RD_IDLE;
            endcase

            // ---------------- 写状态机 ----------------
            case (wr_state)
                WR_IDLE: begin
                    m_awvalid <= 1'b0;
                    m_wvalid  <= 1'b0;
                    m_bready  <= 1'b0;
                end
                WR_WAIT: begin
                    if (wr_rem_words == 0) begin
                        wr_state <= WR_DONE;
                    end else begin
                        wr_beats_total <= calc_beats(wr_curr_addr, wr_rem_words);
                        if (fifo_data_count >= calc_beats(wr_curr_addr, wr_rem_words)) begin
                            wr_state <= WR_ADDR;
                        end
                    end
                end
                WR_ADDR: begin
                    if (!m_awvalid) begin
                        m_awaddr  <= wr_curr_addr;
                        m_awlen   <= wr_beats_total - 1'b1;
                        m_awvalid <= 1'b1;
                    end
                    if (m_awvalid && m_awready) begin
                        m_awvalid     <= 1'b0;
                        wr_beats_left <= wr_beats_total;
                        wr_state      <= WR_DATA;
                    end
                end
                WR_DATA: begin
                    if (!m_wvalid && !fifo_empty && (wr_beats_left != 0)) begin
                        fifo_rd_en <= 1'b1;
                        m_wdata    <= fifo_rd_data;
                        m_wvalid   <= 1'b1;
                        m_wlast    <= (wr_beats_left == 9'd1);
                    end
                    if (m_wvalid && m_wready) begin
                        m_wvalid <= 1'b0;
                        if (wr_beats_left != 0) wr_beats_left <= wr_beats_left - 1'b1;
                        if (wr_beats_left == 9'd1) begin
                            m_bready <= 1'b1;
                            wr_state <= WR_RESP;
                        end
                    end
                end
                WR_RESP: begin
                    if (m_bvalid && m_bready) begin
                        if (m_bresp != `AXI_RESP_OKAY) dma_error <= 1'b1;
                        m_bready     <= 1'b0;
                        wr_curr_addr <= wr_curr_addr + ((m_awlen + 1'b1) << 2);
                        wr_rem_words <= wr_rem_words - (m_awlen + 1'b1);
                        wr_state     <= (wr_rem_words == (m_awlen + 1'b1)) ? WR_DONE : WR_WAIT;
                    end
                end
                WR_DONE: begin
                    if (rd_state == RD_DONE) begin
                        dma_done <= 1'b1;
                        rd_state <= RD_IDLE;
                        wr_state <= WR_IDLE;
                    end
                end
                default: wr_state <= WR_IDLE;
            endcase
        end
    end

endmodule
