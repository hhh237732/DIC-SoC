`include "axi4_defines.vh"

// ================================================================
// 模块名称：main_mem
// 功能说明：
//   仿真主存模型（64KB，字节寻址），AXI4 Slave接口，支持INCR burst读写。
// ================================================================
module main_mem (
    input         clk,
    input         rst_n,
    // AW
    input         s_awvalid,
    output reg    s_awready,
    input  [31:0] s_awaddr,
    input  [4:0]  s_awid,
    input  [7:0]  s_awlen,
    input  [2:0]  s_awsize,
    input  [1:0]  s_awburst,
    // W
    input         s_wvalid,
    output reg    s_wready,
    input  [31:0] s_wdata,
    input  [3:0]  s_wstrb,
    input         s_wlast,
    // B
    output reg    s_bvalid,
    input         s_bready,
    output reg [4:0] s_bid,
    output reg [1:0] s_bresp,
    // AR
    input         s_arvalid,
    output reg    s_arready,
    input  [31:0] s_araddr,
    input  [4:0]  s_arid,
    input  [7:0]  s_arlen,
    input  [2:0]  s_arsize,
    input  [1:0]  s_arburst,
    // R
    output reg    s_rvalid,
    input         s_rready,
    output reg [31:0] s_rdata,
    output reg [4:0]  s_rid,
    output reg [1:0]  s_rresp,
    output reg        s_rlast
);

    reg [7:0] mem [0:65535];

    localparam R_IDLE = 2'd0, R_DATA = 2'd1;
    localparam W_IDLE = 2'd0, W_DATA = 2'd1, W_RESP = 2'd2;

    reg [1:0] r_state;
    reg [1:0] w_state;

    reg [31:0] r_addr;
    reg [7:0]  r_left;
    reg [31:0] w_addr;
    reg [7:0]  w_left;

    integer i;
    initial begin
        for (i = 0; i < 65536; i = i + 1) mem[i] = i[7:0];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_awready <= 1'b1;
            s_wready  <= 1'b1;
            s_bvalid  <= 1'b0;
            s_bid     <= 5'd0;
            s_bresp   <= `AXI_RESP_OKAY;
            s_arready <= 1'b1;
            s_rvalid  <= 1'b0;
            s_rdata   <= 32'd0;
            s_rid     <= 5'd0;
            s_rresp   <= `AXI_RESP_OKAY;
            s_rlast   <= 1'b0;
            r_state   <= R_IDLE;
            w_state   <= W_IDLE;
            r_addr    <= 32'd0;
            w_addr    <= 32'd0;
            r_left    <= 8'd0;
            w_left    <= 8'd0;
        end else begin
            // 读通道
            case (r_state)
                R_IDLE: begin
                    if (s_arvalid && s_arready) begin
                        s_rid   <= s_arid;
                        r_addr  <= s_araddr;
                        r_left  <= s_arlen;
                        s_rresp <= `AXI_RESP_OKAY;
                        s_rdata <= {mem[s_araddr+3], mem[s_araddr+2], mem[s_araddr+1], mem[s_araddr]};
                        s_rlast <= (s_arlen == 8'd0);
                        s_rvalid<= 1'b1;
                        r_state <= R_DATA;
                    end
                end
                R_DATA: begin
                    if (s_rvalid && s_rready) begin
                        if (r_left == 0) begin
                            s_rvalid <= 1'b0;
                            s_rlast  <= 1'b0;
                            r_state  <= R_IDLE;
                        end else begin
                            r_left <= r_left - 1'b1;
                            r_addr <= r_addr + 32'd4;
                            s_rdata <= {mem[r_addr+7], mem[r_addr+6], mem[r_addr+5], mem[r_addr+4]};
                            s_rlast <= (r_left == 8'd1);
                            s_rvalid<= 1'b1;
                        end
                    end
                end
            endcase

            // 写通道
            case (w_state)
                W_IDLE: begin
                    if (s_awvalid && s_awready) begin
                        s_bid  <= s_awid;
                        w_addr <= s_awaddr;
                        w_left <= s_awlen;
                        w_state<= W_DATA;
                    end
                end
                W_DATA: begin
                    if (s_wvalid && s_wready) begin
                        if (s_wstrb[0]) mem[w_addr]   <= s_wdata[7:0];
                        if (s_wstrb[1]) mem[w_addr+1] <= s_wdata[15:8];
                        if (s_wstrb[2]) mem[w_addr+2] <= s_wdata[23:16];
                        if (s_wstrb[3]) mem[w_addr+3] <= s_wdata[31:24];

                        if (s_wlast || (w_left == 0)) begin
                            s_bresp <= `AXI_RESP_OKAY;
                            s_bvalid<= 1'b1;
                            w_state <= W_RESP;
                        end else begin
                            w_left <= w_left - 1'b1;
                            w_addr <= w_addr + 32'd4;
                        end
                    end
                end
                W_RESP: begin
                    if (s_bvalid && s_bready) begin
                        s_bvalid <= 1'b0;
                        w_state  <= W_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
