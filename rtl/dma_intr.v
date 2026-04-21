`include "axi4_defines.vh"

// ================================================================
// 模块名称：dma_intr
// 功能说明：
//   DMA中断与状态保持模块。
//   1) done/error脉冲置位状态寄存器
//   2) done_clr/err_clr写1清除
//   3) 输出经过中断使能门控
// ================================================================
module dma_intr (
    input  clk,
    input  rst_n,
    input  dma_done,
    input  dma_error,
    input  done_ie,
    input  err_ie,
    input  done_clr,
    input  err_clr,
    output intr_done,
    output intr_error,
    output intr_out
);

    reg done_lat;
    reg err_lat;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_lat <= 1'b0;
            err_lat  <= 1'b0;
        end else begin
            if (done_clr) done_lat <= 1'b0;
            else if (dma_done) done_lat <= 1'b1;

            if (err_clr) err_lat <= 1'b0;
            else if (dma_error) err_lat <= 1'b1;
        end
    end

    assign intr_done  = done_lat & done_ie;
    assign intr_error = err_lat & err_ie;
    assign intr_out   = intr_done | intr_error;

endmodule
