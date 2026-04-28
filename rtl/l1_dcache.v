`include "axi4_defines.vh"

// ================================================================
// 模块名称：l1_dcache
// 功能说明：
//   2KB 2-way DCache，写回+写分配。
//   单请求阻塞式实现：命中直接访问，缺失时先写回脏行再回填。
// ================================================================
module l1_dcache (
    input         clk,
    input         rst_n,
    input         cpu_req,
    input         cpu_we,
    input  [3:0]  cpu_wstrb,
    input  [31:0] cpu_addr,
    input  [31:0] cpu_wdata,
    output reg [31:0] cpu_rdata,
    output        cpu_hit,
    output        cpu_stall,

    output reg        dcache_arvalid,
    input             dcache_arready,
    output reg [31:0] dcache_araddr,
    output reg [3:0]  dcache_arid,
    output reg [7:0]  dcache_arlen,
    output reg [2:0]  dcache_arsize,
    output reg [1:0]  dcache_arburst,
    input             dcache_rvalid,
    output            dcache_rready,
    input  [31:0]     dcache_rdata,
    input  [3:0]      dcache_rid,
    input  [1:0]      dcache_rresp,
    input             dcache_rlast,

    output reg        dcache_awvalid,
    input             dcache_awready,
    output reg [31:0] dcache_awaddr,
    output reg [3:0]  dcache_awid,
    output reg [7:0]  dcache_awlen,
    output reg [2:0]  dcache_awsize,
    output reg [1:0]  dcache_awburst,
    output reg        dcache_wvalid,
    input             dcache_wready,
    output reg [31:0] dcache_wdata,
    output reg [3:0]  dcache_wstrb,
    output reg        dcache_wlast,
    input             dcache_bvalid,
    output reg        dcache_bready,
    input  [3:0]      dcache_bid,
    input  [1:0]      dcache_bresp,

    // Performance counters
    output reg [31:0] perf_hit_cnt,
    output reg [31:0] perf_miss_cnt
);

    localparam SETS = 32;
    localparam WORDS = 8;
    localparam TAGW = 22;

    localparam IDLE=4'd0, TAG=4'd1, WB_AW=4'd2, WB_W=4'd3, WB_B=4'd4, FILL_AR=4'd5, FILL_R=4'd6, RESP=4'd7;
    reg [3:0] state;

    reg [TAGW-1:0] tag_arr [0:SETS-1][0:1];
    reg            val_arr [0:SETS-1][0:1];
    reg            dirty_arr[0:SETS-1][0:1];
    reg [31:0]     data_arr[0:SETS-1][0:1][0:WORDS-1];
    reg            lru_arr [0:SETS-1];

    reg pend_we;
    reg [3:0] pend_wstrb;
    reg [31:0] pend_addr, pend_wdata;
    reg victim;
    reg [2:0] beat;

    wire [4:0] idx  = pend_addr[9:5];
    wire [2:0] woff = pend_addr[4:2];
    wire [21:0] tag = pend_addr[31:10];

    wire w0_hit = val_arr[idx][0] && (tag_arr[idx][0] == tag);
    wire w1_hit = val_arr[idx][1] && (tag_arr[idx][1] == tag);
    wire hit = w0_hit || w1_hit;
    wire hit_way = w1_hit;

    assign cpu_hit = (state==IDLE) && cpu_req && hit;
    assign cpu_stall = cpu_req && !cpu_hit;
    assign dcache_rready = (state==FILL_R);

    integer s,w,ww;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=IDLE;
            cpu_rdata<=32'd0;
            dcache_arvalid<=0; dcache_awvalid<=0; dcache_wvalid<=0; dcache_bready<=0;
            dcache_araddr<=0; dcache_awaddr<=0; dcache_wdata<=0;
            dcache_arid<=0; dcache_awid<=0;
            dcache_arlen<=8'd7; dcache_awlen<=8'd7;
            dcache_arsize<=3'd2; dcache_awsize<=3'd2;
            dcache_arburst<=`AXI_BURST_INCR; dcache_awburst<=`AXI_BURST_INCR;
            dcache_wstrb<=4'hF; dcache_wlast<=0;
            pend_we<=0; pend_wstrb<=0; pend_addr<=0; pend_wdata<=0;
            victim<=0; beat<=0;
            perf_hit_cnt<=32'd0; perf_miss_cnt<=32'd0;
            for (s=0;s<SETS;s=s+1) begin
                lru_arr[s]<=0;
                for (w=0;w<2;w=w+1) begin
                    val_arr[s][w]<=0; dirty_arr[s][w]<=0; tag_arr[s][w]<=0;
                    for (ww=0;ww<WORDS;ww=ww+1) data_arr[s][w][ww]<=0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (cpu_req) begin
                        pend_we<=cpu_we; pend_wstrb<=cpu_wstrb; pend_addr<=cpu_addr; pend_wdata<=cpu_wdata;
                        state<=TAG;
                    end
                end
                TAG: begin
                    if (hit) begin
                        perf_hit_cnt <= perf_hit_cnt + 1'b1;
                        if (!pend_we) begin
                            cpu_rdata <= data_arr[idx][hit_way][woff];
                        end else begin
                            if (pend_wstrb[0]) data_arr[idx][hit_way][woff][7:0] <= pend_wdata[7:0];
                            if (pend_wstrb[1]) data_arr[idx][hit_way][woff][15:8] <= pend_wdata[15:8];
                            if (pend_wstrb[2]) data_arr[idx][hit_way][woff][23:16] <= pend_wdata[23:16];
                            if (pend_wstrb[3]) data_arr[idx][hit_way][woff][31:24] <= pend_wdata[31:24];
                            dirty_arr[idx][hit_way] <= 1'b1;
                        end
                        lru_arr[idx] <= ~hit_way;
                        state<=IDLE;
                    end else begin
                        perf_miss_cnt <= perf_miss_cnt + 1'b1;
                        victim <= lru_arr[idx];
                        if (val_arr[idx][lru_arr[idx]] && dirty_arr[idx][lru_arr[idx]]) begin
                            dcache_awaddr <= {tag_arr[idx][lru_arr[idx]], idx, 5'b0};
                            dcache_awvalid<=1'b1;
                            dcache_awlen<=8'd7; dcache_awsize<=3'd2; dcache_awburst<=`AXI_BURST_INCR; dcache_awid<=4'h2;
                            state<=WB_AW;
                        end else begin
                            dcache_araddr <= {pend_addr[31:5],5'b0};
                            dcache_arvalid<=1'b1;
                            dcache_arlen<=8'd7; dcache_arid<=4'h2;
                            state<=FILL_AR;
                        end
                    end
                end
                WB_AW: begin
                    if (dcache_awvalid && dcache_awready) begin
                        dcache_awvalid<=0;
                        beat<=0;
                        state<=WB_W;
                    end
                end
                WB_W: begin
                    if (!dcache_wvalid) begin
                        dcache_wvalid<=1'b1;
                        dcache_wdata<=data_arr[idx][victim][beat];
                        dcache_wstrb<=4'hF;
                        dcache_wlast<= (beat==3'd7);
                    end else if (dcache_wvalid && dcache_wready) begin
                        dcache_wvalid<=0;
                        if (beat==3'd7) begin
                            dcache_bready<=1'b1;
                            state<=WB_B;
                        end
                        beat<=beat+1'b1;
                    end
                end
                WB_B: begin
                    if (dcache_bvalid && dcache_bready) begin
                        dcache_bready<=1'b0;
                        dirty_arr[idx][victim] <= 1'b0;
                        dcache_araddr <= {pend_addr[31:5],5'b0};
                        dcache_arvalid<=1'b1;
                        dcache_arlen<=8'd7; dcache_arid<=4'h2;
                        state<=FILL_AR;
                    end
                end
                FILL_AR: begin
                    if (dcache_arvalid && dcache_arready) begin
                        dcache_arvalid<=0;
                        beat<=0;
                        state<=FILL_R;
                    end
                end
                FILL_R: begin
                    if (dcache_rvalid && dcache_rready) begin
                        data_arr[idx][victim][beat] <= dcache_rdata;
                        beat<=beat+1'b1;
                        if (dcache_rlast) begin
                            tag_arr[idx][victim] <= tag;
                            val_arr[idx][victim] <= 1'b1;
                            dirty_arr[idx][victim] <= 1'b0;
                            lru_arr[idx] <= ~victim;
                            state<=RESP;
                        end
                    end
                end
                RESP: begin
                    if (pend_we) begin
                        if (pend_wstrb[0]) data_arr[idx][victim][woff][7:0] <= pend_wdata[7:0];
                        if (pend_wstrb[1]) data_arr[idx][victim][woff][15:8] <= pend_wdata[15:8];
                        if (pend_wstrb[2]) data_arr[idx][victim][woff][23:16] <= pend_wdata[23:16];
                        if (pend_wstrb[3]) data_arr[idx][victim][woff][31:24] <= pend_wdata[31:24];
                        dirty_arr[idx][victim] <= 1'b1;
                    end else begin
                        cpu_rdata <= data_arr[idx][victim][woff];
                    end
                    state<=IDLE;
                end
            endcase
        end
    end
endmodule
