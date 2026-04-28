`include "axi4_defines.vh"

// ================================================================
// 模块名称：l1_icache
// 功能说明：
//   8KB 2-way 指令Cache，只读。
//   命中单周期返回；miss时AXI读8拍回填整行。
// ================================================================
module l1_icache (
    input         clk,
    input         rst_n,
    input         cpu_req,
    input  [31:0] cpu_addr,
    output [31:0] cpu_rdata,
    output        cpu_hit,
    output        cpu_stall,

    output reg        icache_arvalid,
    input             icache_arready,
    output reg [31:0] icache_araddr,
    output reg [3:0]  icache_arid,
    output reg [7:0]  icache_arlen,
    output reg [2:0]  icache_arsize,
    output reg [1:0]  icache_arburst,
    input             icache_rvalid,
    output            icache_rready,
    input  [31:0]     icache_rdata,
    input  [3:0]      icache_rid,
    input  [1:0]      icache_rresp,
    input             icache_rlast,

    // Performance counters
    output reg [31:0] perf_hit_cnt,
    output reg [31:0] perf_miss_cnt
);

    localparam SETS = 128;
    localparam WORDS = 8;
    localparam TAGW = 20;

    localparam ST_IDLE = 2'd0;
    localparam ST_REQ  = 2'd1;
    localparam ST_FILL = 2'd2;

    reg [1:0] state;

    reg [TAGW-1:0] tag_arr [0:SETS-1][0:1];
    reg            val_arr [0:SETS-1][0:1];
    reg [31:0]     data_arr[0:SETS-1][0:1][0:WORDS-1];
    reg            lru_arr [0:SETS-1];

    reg [31:0] miss_addr;
    reg [2:0]  fill_cnt;
    reg        victim_way;

    wire [6:0] idx  = cpu_addr[11:5];
    wire [2:0] woff = cpu_addr[4:2];
    wire [19:0] tag = cpu_addr[31:12];

    wire way0_hit = val_arr[idx][0] && (tag_arr[idx][0] == tag);
    wire way1_hit = val_arr[idx][1] && (tag_arr[idx][1] == tag);

    assign cpu_hit   = cpu_req && (state == ST_IDLE) && (way0_hit || way1_hit);
    assign cpu_rdata = way0_hit ? data_arr[idx][0][woff] : data_arr[idx][1][woff];
    assign cpu_stall = cpu_req && !cpu_hit;

    assign icache_rready = (state == ST_FILL);

    integer s, w, ww;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            icache_arvalid <= 1'b0;
            icache_araddr  <= 32'd0;
            icache_arid    <= 4'd0;
            icache_arlen   <= 8'd7;
            icache_arsize  <= 3'd2;
            icache_arburst <= `AXI_BURST_INCR;
            miss_addr      <= 32'd0;
            fill_cnt       <= 3'd0;
            victim_way     <= 1'b0;
            perf_hit_cnt   <= 32'd0;
            perf_miss_cnt  <= 32'd0;
            for (s = 0; s < SETS; s = s + 1) begin
                lru_arr[s] <= 1'b0;
                for (w = 0; w < 2; w = w + 1) begin
                    val_arr[s][w] <= 1'b0;
                    tag_arr[s][w] <= {TAGW{1'b0}};
                    for (ww = 0; ww < WORDS; ww = ww + 1) data_arr[s][w][ww] <= 32'd0;
                end
            end
        end else begin
            case (state)
                ST_IDLE: begin
                    if (cpu_req) begin
                        if (way0_hit) begin
                            lru_arr[idx] <= 1'b1;
                            perf_hit_cnt <= perf_hit_cnt + 1'b1;
                        end else if (way1_hit) begin
                            lru_arr[idx] <= 1'b0;
                            perf_hit_cnt <= perf_hit_cnt + 1'b1;
                        end else begin
                            perf_miss_cnt  <= perf_miss_cnt + 1'b1;
                            miss_addr      <= {cpu_addr[31:5], 5'b0};
                            victim_way     <= lru_arr[idx];
                            icache_araddr  <= {cpu_addr[31:5], 5'b0};
                            icache_arid    <= 4'h1;
                            icache_arlen   <= 8'd7;
                            icache_arsize  <= 3'd2;
                            icache_arburst <= `AXI_BURST_INCR;
                            icache_arvalid <= 1'b1;
                            state <= ST_REQ;
                        end
                    end
                end
                ST_REQ: begin
                    if (icache_arvalid && icache_arready) begin
                        icache_arvalid <= 1'b0;
                        fill_cnt <= 3'd0;
                        state <= ST_FILL;
                    end
                end
                ST_FILL: begin
                    if (icache_rvalid && icache_rready) begin
                        data_arr[miss_addr[11:5]][victim_way][fill_cnt] <= icache_rdata;
                        fill_cnt <= fill_cnt + 1'b1;
                        if (icache_rlast) begin
                            tag_arr[miss_addr[11:5]][victim_way] <= miss_addr[31:12];
                            val_arr[miss_addr[11:5]][victim_way] <= 1'b1;
                            lru_arr[miss_addr[11:5]] <= ~victim_way;
                            state <= ST_IDLE;
                        end
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
