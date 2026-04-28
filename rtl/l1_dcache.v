`include "axi4_defines.vh"

// ================================================================
// 模块名称：l1_dcache
// 功能说明：
//   2KB 2-way DCache，写回+写分配。
//   - 命中：IDLE内直接处理（读数据组合输出，写更新dirty）
//   - 可缓存缺失：IDLE→WB_AW/FILL_AR→FILL_R→IDLE（写分配在FILL_R完成）
//   - 非缓存旁路（addr≥0x1000_0000）：NC单拍AXI事务，绕过cache阵列
// ================================================================
module l1_dcache (
    input         clk,
    input         rst_n,
    input         cpu_req,
    input         cpu_we,
    input  [3:0]  cpu_wstrb,
    input  [31:0] cpu_addr,
    input  [31:0] cpu_wdata,
    output [31:0] cpu_rdata,   // 组合输出（命中时直接给出）
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

    localparam SETS  = 32;
    localparam WORDS = 8;
    localparam TAGW  = 22;

    // 状态编码
    localparam IDLE    = 4'd0;
    localparam WB_AW   = 4'd1;   // 写回脏行 - AW握手
    localparam WB_W    = 4'd2;   // 写回脏行 - W数据传输
    localparam WB_B    = 4'd3;   // 写回脏行 - B响应
    localparam FILL_AR = 4'd4;   // 填充新行 - AR握手
    localparam FILL_R  = 4'd5;   // 填充新行 - R数据接收
    localparam NC_AR   = 4'd6;   // 非缓存读 - AR握手
    localparam NC_R    = 4'd7;   // 非缓存读 - R数据接收
    localparam NC_AW   = 4'd8;   // 非缓存写 - AW+W同时握手
    localparam NC_B    = 4'd9;   // 非缓存写 - B响应等待

    reg [3:0] state;

    reg [TAGW-1:0] tag_arr  [0:SETS-1][0:1];
    reg            val_arr  [0:SETS-1][0:1];
    reg            dirty_arr[0:SETS-1][0:1];
    reg [31:0]     data_arr [0:SETS-1][0:1][0:WORDS-1];
    reg            lru_arr  [0:SETS-1];

    reg        pend_we;
    reg [3:0]  pend_wstrb;
    reg [31:0] pend_addr, pend_wdata;
    reg        victim;
    reg [2:0]  beat;

    reg [31:0] cpu_rdata_r;  // 寄存型读数据（NC读 / 缺失填充后读）
    reg        nc_ok;        // NC事务完成标志（1拍内清除）

    // ----------------------------------------------------------------
    // 非缓存区域判定：0x0000_0000–0x0FFF_FFFF 可缓存，其余非缓存旁路
    // ----------------------------------------------------------------
    wire nc = (cpu_addr[31:28] != 4'h0);

    // ----------------------------------------------------------------
    // 基于 cpu_addr 的组合命中检测（IDLE 态使用，避免使用stale pend_addr）
    // ----------------------------------------------------------------
    wire [4:0]  cidx   = cpu_addr[9:5];
    wire [2:0]  cwoff  = cpu_addr[4:2];
    wire [21:0] ctag   = cpu_addr[31:10];

    wire cw0_hit = val_arr[cidx][0] && (tag_arr[cidx][0] == ctag);
    wire cw1_hit = val_arr[cidx][1] && (tag_arr[cidx][1] == ctag);
    wire chit    = cw0_hit || cw1_hit;
    wire chit_way = cw1_hit ? 1'b1 : 1'b0;

    // ----------------------------------------------------------------
    // 缺失处理阶段基于 pend_addr 的派生信号
    // ----------------------------------------------------------------
    wire [4:0]  idx  = pend_addr[9:5];
    wire [2:0]  woff = pend_addr[4:2];
    wire [21:0] tag  = pend_addr[31:10];

    // ----------------------------------------------------------------
    // 外部接口信号
    // ----------------------------------------------------------------
    // cpu_hit：IDLE且缓存命中，或NC事务刚完成
    assign cpu_hit   = (state == IDLE) && (nc_ok || (cpu_req && !nc && chit));
    assign cpu_stall = cpu_req && !cpu_hit;

    // dcache_rready：可缓存填充或NC读均需接收R通道数据
    assign dcache_rready = (state == FILL_R) || (state == NC_R);

    // cpu_rdata：IDLE可缓存读命中时组合输出，其余从寄存器输出
    assign cpu_rdata = (state == IDLE && cpu_req && !cpu_we && !nc && chit) ?
                       (chit_way ? data_arr[cidx][1][cwoff] : data_arr[cidx][0][cwoff]) :
                       cpu_rdata_r;

    // ----------------------------------------------------------------
    // FSM
    // ----------------------------------------------------------------
    integer s, w, ww;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            cpu_rdata_r  <= 32'd0;
            nc_ok        <= 1'b0;
            dcache_arvalid<=0; dcache_awvalid<=0; dcache_wvalid<=0; dcache_bready<=0;
            dcache_araddr<=0;  dcache_awaddr<=0;  dcache_wdata<=0;
            dcache_arid<=0;    dcache_awid<=0;
            dcache_arlen<=8'd7;  dcache_awlen<=8'd7;
            dcache_arsize<=3'd2; dcache_awsize<=3'd2;
            dcache_arburst<=`AXI_BURST_INCR; dcache_awburst<=`AXI_BURST_INCR;
            dcache_wstrb<=4'hF;  dcache_wlast<=0;
            pend_we<=0; pend_wstrb<=0; pend_addr<=0; pend_wdata<=0;
            victim<=0; beat<=0;
            perf_hit_cnt<=32'd0; perf_miss_cnt<=32'd0;
            for (s=0; s<SETS; s=s+1) begin
                lru_arr[s] <= 0;
                for (w=0; w<2; w=w+1) begin
                    val_arr[s][w]<=0; dirty_arr[s][w]<=0; tag_arr[s][w]<=0;
                    for (ww=0; ww<WORDS; ww=ww+1) data_arr[s][w][ww]<=0;
                end
            end
        end else begin
            case (state)
                // ----------------------------------------------------
                // IDLE：处理命中（读/写）及启动缺失流程
                // ----------------------------------------------------
                IDLE: begin
                    if (cpu_req) begin
                        if (nc_ok) begin
                            // NC事务已完成，清除标志；cpu_hit=1本拍内有效
                            nc_ok <= 1'b0;
                        end else if (nc) begin
                            // 非缓存地址 - 旁路AXI单拍事务
                            pend_addr  <= cpu_addr;
                            pend_we    <= cpu_we;
                            pend_wstrb <= cpu_wstrb;
                            pend_wdata <= cpu_wdata;
                            if (cpu_we) begin
                                // NC写：AW + W 同拍发出（awlen=0, wlast=1）
                                dcache_awvalid <= 1'b1;
                                dcache_awaddr  <= cpu_addr;
                                dcache_awlen   <= 8'd0;
                                dcache_awsize  <= 3'd2;
                                dcache_awburst <= `AXI_BURST_INCR;
                                dcache_awid    <= 4'h2;
                                dcache_wvalid  <= 1'b1;
                                dcache_wdata   <= cpu_wdata;
                                dcache_wstrb   <= cpu_wstrb;
                                dcache_wlast   <= 1'b1;
                                state <= NC_AW;
                            end else begin
                                // NC读：单拍AR
                                dcache_arvalid <= 1'b1;
                                dcache_araddr  <= cpu_addr;
                                dcache_arlen   <= 8'd0;
                                dcache_arsize  <= 3'd2;
                                dcache_arburst <= `AXI_BURST_INCR;
                                dcache_arid    <= 4'h2;
                                state <= NC_AR;
                            end
                        end else if (chit) begin
                            // 可缓存命中
                            perf_hit_cnt <= perf_hit_cnt + 1'b1;
                            lru_arr[cidx] <= ~chit_way;
                            if (cpu_we) begin
                                // 写命中：更新数据阵列并置dirty
                                if (cpu_wstrb[0]) data_arr[cidx][chit_way][cwoff][7:0]   <= cpu_wdata[7:0];
                                if (cpu_wstrb[1]) data_arr[cidx][chit_way][cwoff][15:8]  <= cpu_wdata[15:8];
                                if (cpu_wstrb[2]) data_arr[cidx][chit_way][cwoff][23:16] <= cpu_wdata[23:16];
                                if (cpu_wstrb[3]) data_arr[cidx][chit_way][cwoff][31:24] <= cpu_wdata[31:24];
                                dirty_arr[cidx][chit_way] <= 1'b1;
                            end
                            // 读命中：cpu_rdata组合输出，无需额外操作
                        end else begin
                            // 可缓存缺失
                            perf_miss_cnt <= perf_miss_cnt + 1'b1;
                            pend_addr  <= cpu_addr;
                            pend_we    <= cpu_we;
                            pend_wstrb <= cpu_wstrb;
                            pend_wdata <= cpu_wdata;
                            victim     <= lru_arr[cidx];
                            if (val_arr[cidx][lru_arr[cidx]] && dirty_arr[cidx][lru_arr[cidx]]) begin
                                // 脏行需先写回
                                dcache_awaddr  <= {tag_arr[cidx][lru_arr[cidx]], cidx, 5'b0};
                                dcache_awvalid <= 1'b1;
                                dcache_awlen   <= 8'd7;
                                dcache_awsize  <= 3'd2;
                                dcache_awburst <= `AXI_BURST_INCR;
                                dcache_awid    <= 4'h2;
                                state <= WB_AW;
                            end else begin
                                // 直接发起填充
                                dcache_araddr  <= {cpu_addr[31:5], 5'b0};
                                dcache_arvalid <= 1'b1;
                                dcache_arlen   <= 8'd7;
                                dcache_arsize  <= 3'd2;
                                dcache_arburst <= `AXI_BURST_INCR;
                                dcache_arid    <= 4'h2;
                                state <= FILL_AR;
                            end
                        end
                    end
                end

                // ----------------------------------------------------
                // 写回脏行：AW→W→B
                // ----------------------------------------------------
                WB_AW: begin
                    if (dcache_awvalid && dcache_awready) begin
                        dcache_awvalid <= 0;
                        beat <= 0;
                        state <= WB_W;
                    end
                end

                WB_W: begin
                    if (!dcache_wvalid) begin
                        dcache_wvalid <= 1'b1;
                        dcache_wdata  <= data_arr[idx][victim][beat];
                        dcache_wstrb  <= 4'hF;
                        dcache_wlast  <= (beat == 3'd7);
                    end else if (dcache_wvalid && dcache_wready) begin
                        dcache_wvalid <= 0;
                        if (beat == 3'd7) begin
                            dcache_bready <= 1'b1;
                            state <= WB_B;
                        end
                        beat <= beat + 1'b1;
                    end
                end

                WB_B: begin
                    if (dcache_bvalid && dcache_bready) begin
                        dcache_bready  <= 1'b0;
                        dirty_arr[idx][victim] <= 1'b0;
                        dcache_araddr  <= {pend_addr[31:5], 5'b0};
                        dcache_arvalid <= 1'b1;
                        dcache_arlen   <= 8'd7;
                        dcache_arsize  <= 3'd2;
                        dcache_arburst <= `AXI_BURST_INCR;
                        dcache_arid    <= 4'h2;
                        state <= FILL_AR;
                    end
                end

                // ----------------------------------------------------
                // 填充新行：AR→R（写分配在rlast拍完成）
                // ----------------------------------------------------
                FILL_AR: begin
                    if (dcache_arvalid && dcache_arready) begin
                        dcache_arvalid <= 0;
                        beat <= 0;
                        state <= FILL_R;
                    end
                end

                FILL_R: begin
                    if (dcache_rvalid && dcache_rready) begin
                        data_arr[idx][victim][beat] <= dcache_rdata;
                        beat <= beat + 1'b1;
                        if (dcache_rlast) begin
                            tag_arr[idx][victim]   <= tag;
                            val_arr[idx][victim]   <= 1'b1;
                            dirty_arr[idx][victim] <= 1'b0;
                            lru_arr[idx]           <= ~victim;
                            if (pend_we) begin
                                // 写分配：将待写数据直接嵌入已填充行
                                if (pend_wstrb[0]) data_arr[idx][victim][woff][7:0]   <= pend_wdata[7:0];
                                if (pend_wstrb[1]) data_arr[idx][victim][woff][15:8]  <= pend_wdata[15:8];
                                if (pend_wstrb[2]) data_arr[idx][victim][woff][23:16] <= pend_wdata[23:16];
                                if (pend_wstrb[3]) data_arr[idx][victim][woff][31:24] <= pend_wdata[31:24];
                                dirty_arr[idx][victim] <= 1'b1;
                            end
                            // 直接返回IDLE；下一拍IDLE中命中检测将通过
                            state <= IDLE;
                        end
                    end
                end

                // ----------------------------------------------------
                // 非缓存（NC）旁路状态
                // ----------------------------------------------------
                NC_AR: begin
                    if (dcache_arvalid && dcache_arready) begin
                        dcache_arvalid <= 0;
                        state <= NC_R;
                    end
                end

                NC_R: begin
                    if (dcache_rvalid && dcache_rready) begin
                        cpu_rdata_r <= dcache_rdata;
                        nc_ok       <= 1'b1;
                        state       <= IDLE;
                    end
                end

                // NC写：AW + W 同拍发出，等待双通道握手完毕再等B
                NC_AW: begin
                    if (dcache_awvalid && dcache_awready) dcache_awvalid <= 0;
                    if (dcache_wvalid  && dcache_wready)  begin
                        dcache_wvalid <= 0;
                        dcache_wlast  <= 0;
                    end
                    // 两个通道均握手完成（或本拍完成）则进入B等待
                    if ((!dcache_awvalid || dcache_awready) &&
                        (!dcache_wvalid  || dcache_wready)) begin
                        dcache_bready <= 1'b1;
                        state         <= NC_B;
                    end
                end

                NC_B: begin
                    if (dcache_bvalid && dcache_bready) begin
                        dcache_bready <= 0;
                        nc_ok         <= 1'b1;
                        state         <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
