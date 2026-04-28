`include "axi4_defines.vh"

// ================================================================
// 模块名称：dma_regfile
// 功能说明：
//   DMA控制寄存器AXI4 Slave。
//   仅支持单拍访问（ARLEN/AWLEN=0），32位字对齐。
// ================================================================
module dma_regfile (
    input         clk,
    input         rst_n,
    // AXI4 Slave - AW
    input         s_awvalid,
    output reg    s_awready,
    input  [31:0] s_awaddr,
    input  [3:0]  s_awid,
    input  [7:0]  s_awlen,
    input  [2:0]  s_awsize,
    input  [1:0]  s_awburst,
    // AXI4 Slave - W
    input         s_wvalid,
    output reg    s_wready,
    input  [31:0] s_wdata,
    input  [3:0]  s_wstrb,
    input         s_wlast,
    // AXI4 Slave - B
    output reg    s_bvalid,
    input         s_bready,
    output reg [3:0] s_bid,
    output reg [1:0] s_bresp,
    // AXI4 Slave - AR
    input         s_arvalid,
    output reg    s_arready,
    input  [31:0] s_araddr,
    input  [3:0]  s_arid,
    input  [7:0]  s_arlen,
    input  [2:0]  s_arsize,
    input  [1:0]  s_arburst,
    // AXI4 Slave - R
    output reg    s_rvalid,
    input         s_rready,
    output reg [31:0] s_rdata,
    output reg [3:0]  s_rid,
    output reg [1:0]  s_rresp,
    output reg        s_rlast,

    // 与DMA引擎连接
    output reg        dma_start,
    output reg        dma_abort,
    output [31:0]     dma_src_addr,
    output [31:0]     dma_dst_addr,
    output [31:0]     dma_length,
    output            done_ie,
    output            err_ie,
    output [7:0]      dma_burst_max,
    input             dma_busy,
    input             dma_done,
    input             dma_error,

    // 提供给中断模块/状态机清除
    output reg        done_clr,
    output reg        err_clr
);

    reg [31:0] reg_src_addr;
    reg [31:0] reg_dst_addr;
    reg [31:0] reg_length;
    reg [7:0]  reg_burst_max;   // BURST_MAX: limits per-burst beat count (default 255)
    reg [1:0]  reg_irq_mask;    // IRQ_MASK: bit0=done_en, bit1=err_en
    reg [1:0]  reg_irq_status;  // IRQ_STATUS: bit0=done_pend W1C, bit1=err_pend W1C

    reg status_done;
    reg status_error;

    // AW latch: hold pending address until W arrives (standard AXI4 behavior)
    reg        aw_pending;
    reg [31:0] awaddr_latched;
    reg [3:0]  awid_latched;
    reg        write_ok_lat;   // latch write_ok at AW acceptance time

    wire write_ok = (s_awlen == 8'd0) && (s_awsize == 3'd2) && (s_awburst == `AXI_BURST_INCR);
    wire read_ok  = (s_arlen == 8'd0) && (s_arsize == 3'd2) && (s_arburst == `AXI_BURST_INCR);

    assign dma_src_addr = reg_src_addr;
    assign dma_dst_addr = reg_dst_addr;
    assign dma_length   = reg_length;
    assign done_ie      = reg_irq_mask[0];
    assign err_ie       = reg_irq_mask[1];
    assign dma_burst_max = reg_burst_max;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_src_addr   <= 32'd0;
            reg_dst_addr   <= 32'd0;
            reg_length     <= 32'd0;
            reg_burst_max  <= 8'd255;
            reg_irq_mask   <= 2'b00;
            reg_irq_status <= 2'b00;
            status_done    <= 1'b0;
            status_error   <= 1'b0;
            dma_start      <= 1'b0;
            dma_abort      <= 1'b0;
            done_clr       <= 1'b0;
            err_clr        <= 1'b0;

            s_awready      <= 1'b1;
            s_wready       <= 1'b1;
            s_bvalid       <= 1'b0;
            s_bid          <= 4'd0;
            s_bresp        <= `AXI_RESP_OKAY;

            s_arready      <= 1'b1;
            s_rvalid       <= 1'b0;
            s_rdata        <= 32'd0;
            s_rid          <= 4'd0;
            s_rresp        <= `AXI_RESP_OKAY;
            s_rlast        <= 1'b1;

            aw_pending     <= 1'b0;
            awaddr_latched <= 32'd0;
            awid_latched   <= 4'd0;
            write_ok_lat   <= 1'b0;
        end else begin
            dma_start <= 1'b0;
            dma_abort <= 1'b0;
            done_clr  <= 1'b0;
            err_clr   <= 1'b0;

            if (dma_done)  status_done  <= 1'b1;
            if (dma_error) status_error <= 1'b1;

            if (dma_done  && reg_irq_mask[0]) reg_irq_status[0] <= 1'b1;
            if (dma_error && reg_irq_mask[1]) reg_irq_status[1] <= 1'b1;

            // ---- AW channel: latch address when accepted ----
            if (!aw_pending && s_awvalid && s_awready) begin
                awaddr_latched <= s_awaddr;
                awid_latched   <= s_awid;
                write_ok_lat   <= write_ok;
                aw_pending     <= 1'b1;
            end

            // ---- W channel: process when AW is pending ----
            if (aw_pending && s_wvalid && s_wready && s_wlast) begin
                if (write_ok_lat) begin
                    case (awaddr_latched[7:2])
                        6'd0: begin  // DMA_REG_CTRL
                            if (s_wdata[0]) dma_start <= 1'b1;
                            if (s_wdata[1]) dma_abort <= 1'b1;
                        end
                        6'd1: begin  // DMA_REG_STATUS
                            if (s_wdata[1]) begin
                                status_done <= 1'b0;
                                done_clr    <= 1'b1;
                            end
                            if (s_wdata[2]) begin
                                status_error <= 1'b0;
                                err_clr      <= 1'b1;
                            end
                        end
                        6'd2: reg_src_addr <= s_wdata;  // DMA_REG_SRCADDR
                        6'd3: reg_dst_addr <= s_wdata;  // DMA_REG_DSTADDR
                        6'd4: reg_length   <= s_wdata;  // DMA_REG_LEN
                        6'd5: reg_burst_max <= s_wdata[7:0];   // BURST_MAX
                        6'd6: reg_irq_mask  <= s_wdata[1:0];    // IRQ_MASK
                        6'd7: begin  // IRQ_STATUS W1C
                            if (s_wdata[0]) reg_irq_status[0] <= 1'b0;
                            if (s_wdata[1]) reg_irq_status[1] <= 1'b0;
                        end
                        default: ;
                    endcase
                    s_bresp <= `AXI_RESP_OKAY;
                end else begin
                    s_bresp <= `AXI_RESP_SLVERR;
                end
                s_bvalid   <= 1'b1;
                s_bid      <= awid_latched;
                aw_pending <= 1'b0;
            end

            if (s_bvalid && s_bready) s_bvalid <= 1'b0;

            if (s_arvalid && s_arready) begin
                s_rid   <= s_arid;
                s_rlast <= 1'b1;
                if (read_ok) begin
                    case (s_araddr[7:2])
                        6'd0: s_rdata <= 32'd0;                                            // DMA_REG_CTRL
                        6'd1: s_rdata <= {29'd0, status_error, status_done, dma_busy};    // DMA_REG_STATUS
                        6'd2: s_rdata <= reg_src_addr;                                     // DMA_REG_SRCADDR
                        6'd3: s_rdata <= reg_dst_addr;                                     // DMA_REG_DSTADDR
                        6'd4: s_rdata <= reg_length;                                       // DMA_REG_LEN
                        6'd5: s_rdata <= {24'd0, reg_burst_max};          // BURST_MAX
                        6'd6: s_rdata <= {30'd0, reg_irq_mask};           // IRQ_MASK
                        6'd7: s_rdata <= {30'd0, reg_irq_status};         // IRQ_STATUS
                        default: s_rdata <= 32'd0;
                    endcase
                    s_rresp <= `AXI_RESP_OKAY;
                end else begin
                    s_rdata <= 32'd0;
                    s_rresp <= `AXI_RESP_SLVERR;
                end
                s_rvalid <= 1'b1;
            end

            if (s_rvalid && s_rready) s_rvalid <= 1'b0;
        end
    end

endmodule
