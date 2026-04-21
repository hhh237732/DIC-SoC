`include "axi4_defines.vh"

// ================================================================
// 模块名称：sync_fifo
// 功能说明：
//   256x32同步FIFO，使用同一时钟域读写，二进制指针管理。
//   支持full/empty/almost_full/almost_empty/data_count状态输出。
// ================================================================
module sync_fifo #(
    parameter DEPTH = 256,
    parameter WIDTH = 32
) (
    input                  clk,
    input                  rst_n,
    // 写端口
    input                  wr_en,
    input  [WIDTH-1:0]     wr_data,
    output                 full,
    output                 almost_full,
    // 读端口
    input                  rd_en,
    output reg [WIDTH-1:0] rd_data,
    output                 empty,
    output                 almost_empty,
    // 状态
    output [8:0]           data_count
);

    localparam PTR_W = 9;

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [PTR_W-1:0] wr_ptr;
    reg [PTR_W-1:0] rd_ptr;

    wire wr_fire = wr_en && !full;
    wire rd_fire = rd_en && !empty;

    assign data_count    = wr_ptr - rd_ptr;
    assign full          = (data_count == DEPTH[8:0]);
    assign empty         = (data_count == 9'd0);
    assign almost_full   = (data_count >= 9'd240);
    assign almost_empty  = (data_count <= 9'd16);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {PTR_W{1'b0}};
        end else if (wr_fire) begin
            mem[wr_ptr[7:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr  <= {PTR_W{1'b0}};
            rd_data <= {WIDTH{1'b0}};
        end else if (rd_fire) begin
            rd_data <= mem[rd_ptr[7:0]];
            rd_ptr  <= rd_ptr + 1'b1;
        end
    end

endmodule
