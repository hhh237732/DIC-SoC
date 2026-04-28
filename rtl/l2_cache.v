`include "axi4_defines.vh"

// ================================================================
// 模块名称：l2_cache
// 功能说明：
//   16KB 4-way L2 Cache。
//   提供AXI Slave（上游L1）与AXI Master（下游主存）接口。
//   实现写回+写分配，4-way PLRU替换。
// ================================================================
module l2_cache (
    input clk,
    input rst_n,
    // 上游AXI Slave
    input         s_awvalid,
    output reg    s_awready,
    input  [31:0] s_awaddr,
    input  [3:0]  s_awid,
    input  [7:0]  s_awlen,
    input  [2:0]  s_awsize,
    input  [1:0]  s_awburst,
    input         s_wvalid,
    output reg    s_wready,
    input  [31:0] s_wdata,
    input  [3:0]  s_wstrb,
    input         s_wlast,
    output reg    s_bvalid,
    input         s_bready,
    output reg [3:0] s_bid,
    output reg [1:0] s_bresp,
    input         s_arvalid,
    output reg    s_arready,
    input  [31:0] s_araddr,
    input  [3:0]  s_arid,
    input  [7:0]  s_arlen,
    input  [2:0]  s_arsize,
    input  [1:0]  s_arburst,
    output reg    s_rvalid,
    input         s_rready,
    output reg [31:0] s_rdata,
    output reg [3:0]  s_rid,
    output reg [1:0]  s_rresp,
    output reg        s_rlast,
    // 下游AXI Master
    output reg        m_awvalid,
    input             m_awready,
    output reg [31:0] m_awaddr,
    output reg [3:0]  m_awid,
    output reg [7:0]  m_awlen,
    output reg [2:0]  m_awsize,
    output reg [1:0]  m_awburst,
    output reg        m_wvalid,
    input             m_wready,
    output reg [31:0] m_wdata,
    output reg [3:0]  m_wstrb,
    output reg        m_wlast,
    input             m_bvalid,
    output reg        m_bready,
    input  [3:0]      m_bid,
    input  [1:0]      m_bresp,
    output reg        m_arvalid,
    input             m_arready,
    output reg [31:0] m_araddr,
    output reg [3:0]  m_arid,
    output reg [7:0]  m_arlen,
    output reg [2:0]  m_arsize,
    output reg [1:0]  m_arburst,
    input             m_rvalid,
    output            m_rready,
    input  [31:0]     m_rdata,
    input  [3:0]      m_rid,
    input  [1:0]      m_rresp,
    input             m_rlast,

    // Performance counters
    output reg [31:0] perf_hit_cnt,
    output reg [31:0] perf_miss_cnt
);

    localparam SETS=64, WAYS=4, WORDS=16, TAGW=20;
    localparam IDLE=4'd0, TAG=4'd1, WB_AW=4'd2, WB_W=4'd3, WB_B=4'd4, RD_AR=4'd5, RD_R=4'd6, RESP_R=4'd7, RESP_W=4'd8;
    // 新增状态：FILL_DONE修复NBA读竞争；NC_*实现非缓存旁路直通
    localparam FILL_DONE=4'd9, NC_WR_AW=4'd10, NC_WR_B=4'd11, NC_RD_AR=4'd12, NC_RD_R=4'd13;
    reg [3:0] st;

    reg [TAGW-1:0] tag_arr [0:SETS-1][0:WAYS-1];
    reg            val_arr [0:SETS-1][0:WAYS-1];
    reg            dirty_arr[0:SETS-1][0:WAYS-1];
    reg [31:0]     data_arr[0:SETS-1][0:WAYS-1][0:WORDS-1];
    reg [2:0]      plru_arr[0:SETS-1];

    reg req_is_wr;
    reg [31:0] req_addr;
    reg [31:0] req_wdata;
    reg [3:0]  req_wstrb;
    reg [3:0]  req_id;
    reg [1:0]  req_resp;
    reg [1:0]  hit_way;
    reg [1:0]  victim_way;
    reg [3:0]  beat;

    wire [5:0] idx = req_addr[11:6];
    wire [3:0] off = req_addr[5:2];
    wire [19:0] tag = req_addr[31:12];

    // 非缓存区域判定（与L1D保持一致）
    wire nc_req = (req_addr[31:28] != 4'h0);

    wire h0 = val_arr[idx][0] && tag_arr[idx][0]==tag;
    wire h1 = val_arr[idx][1] && tag_arr[idx][1]==tag;
    wire h2 = val_arr[idx][2] && tag_arr[idx][2]==tag;
    wire h3 = val_arr[idx][3] && tag_arr[idx][3]==tag;
    wire hit = h0|h1|h2|h3;

    function [1:0] plru_pick;
        input [2:0] p;
        begin
            if (p[2]==1'b0) plru_pick = (p[1]==1'b0)?2'd0:2'd1;
            else plru_pick = (p[0]==1'b0)?2'd2:2'd3;
        end
    endfunction

    function [2:0] plru_upd;
        input [2:0] p;
        input [1:0] w;
        begin
            plru_upd = p;
            case(w)
                2'd0: begin plru_upd[2]=1'b1; plru_upd[1]=1'b1; end
                2'd1: begin plru_upd[2]=1'b1; plru_upd[1]=1'b0; end
                2'd2: begin plru_upd[2]=1'b0; plru_upd[0]=1'b1; end
                2'd3: begin plru_upd[2]=1'b0; plru_upd[0]=1'b0; end
            endcase
        end
    endfunction

    assign m_rready = (st==RD_R) || (st==NC_RD_R);

    integer s,w,ww;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            st<=IDLE;
            s_awready<=1; s_wready<=1; s_bvalid<=0; s_bid<=0; s_bresp<=`AXI_RESP_OKAY;
            s_arready<=1; s_rvalid<=0; s_rdata<=0; s_rid<=0; s_rresp<=`AXI_RESP_OKAY; s_rlast<=0;
            m_awvalid<=0; m_awaddr<=0; m_awid<=0; m_awlen<=8'd15; m_awsize<=3'd2; m_awburst<=`AXI_BURST_INCR;
            m_wvalid<=0; m_wdata<=0; m_wstrb<=4'hF; m_wlast<=0; m_bready<=0;
            m_arvalid<=0; m_araddr<=0; m_arid<=0; m_arlen<=8'd15; m_arsize<=3'd2; m_arburst<=`AXI_BURST_INCR;
            req_is_wr<=0; req_addr<=0; req_wdata<=0; req_wstrb<=0; req_id<=0; req_resp<=`AXI_RESP_OKAY;
            hit_way<=0; victim_way<=0; beat<=0;
            perf_hit_cnt<=32'd0; perf_miss_cnt<=32'd0;
            for(s=0;s<SETS;s=s+1) begin
                plru_arr[s]<=3'b000;
                for(w=0;w<WAYS;w=w+1) begin
                    val_arr[s][w]<=0; dirty_arr[s][w]<=0; tag_arr[s][w]<=0;
                    for(ww=0;ww<WORDS;ww=ww+1) data_arr[s][w][ww]<=0;
                end
            end
        end else begin
            case(st)
                IDLE: begin
                    if (s_arvalid && s_arready) begin
                        req_is_wr<=0; req_addr<=s_araddr; req_id<=s_arid; req_resp<=`AXI_RESP_OKAY; st<=TAG;
                    end else if (s_awvalid && s_awready && s_wvalid && s_wready) begin
                        req_is_wr<=1; req_addr<=s_awaddr; req_id<=s_awid; req_wdata<=s_wdata; req_wstrb<=s_wstrb; req_resp<=`AXI_RESP_OKAY; st<=TAG;
                    end
                end
                TAG: begin
                    if (nc_req) begin
                        // 非缓存地址：直通到下游AXI主存/设备
                        if (req_is_wr) begin
                            m_awvalid <= 1'b1;
                            m_awaddr  <= req_addr;
                            m_awlen   <= 8'd0;
                            m_awsize  <= 3'd2;
                            m_awburst <= `AXI_BURST_INCR;
                            m_awid    <= 4'h3;
                            m_wvalid  <= 1'b1;
                            m_wdata   <= req_wdata;
                            m_wstrb   <= req_wstrb;
                            m_wlast   <= 1'b1;
                            st <= NC_WR_AW;
                        end else begin
                            m_arvalid <= 1'b1;
                            m_araddr  <= req_addr;
                            m_arlen   <= 8'd0;
                            m_arsize  <= 3'd2;
                            m_arburst <= `AXI_BURST_INCR;
                            m_arid    <= 4'h3;
                            st <= NC_RD_AR;
                        end
                    end else if (hit) begin
                        perf_hit_cnt <= perf_hit_cnt + 1'b1;
                        hit_way <= h0?2'd0:(h1?2'd1:(h2?2'd2:2'd3));
                        if (req_is_wr) begin
                            if (req_wstrb[0]) data_arr[idx][h0?0:h1?1:h2?2:3][off][7:0] <= req_wdata[7:0];
                            if (req_wstrb[1]) data_arr[idx][h0?0:h1?1:h2?2:3][off][15:8] <= req_wdata[15:8];
                            if (req_wstrb[2]) data_arr[idx][h0?0:h1?1:h2?2:3][off][23:16] <= req_wdata[23:16];
                            if (req_wstrb[3]) data_arr[idx][h0?0:h1?1:h2?2:3][off][31:24] <= req_wdata[31:24];
                            dirty_arr[idx][h0?0:h1?1:h2?2:3] <= 1'b1;
                            plru_arr[idx] <= plru_upd(plru_arr[idx], h0?0:h1?1:h2?2:3);
                            st<=RESP_W;
                        end else begin
                            s_rid<=req_id; s_rdata<=data_arr[idx][h0?0:h1?1:h2?2:3][off]; s_rresp<=`AXI_RESP_OKAY; s_rlast<=1'b1; s_rvalid<=1'b1;
                            plru_arr[idx] <= plru_upd(plru_arr[idx], h0?0:h1?1:h2?2:3);
                            st<=RESP_R;
                        end
                    end else begin
                        perf_miss_cnt <= perf_miss_cnt + 1'b1;
                        victim_way <= plru_pick(plru_arr[idx]);
                        if (val_arr[idx][plru_pick(plru_arr[idx])] && dirty_arr[idx][plru_pick(plru_arr[idx])]) begin
                            m_awaddr <= {tag_arr[idx][plru_pick(plru_arr[idx])], idx, 6'b0};
                            m_awid<=4'h3; m_awlen<=8'd15; m_awvalid<=1'b1; st<=WB_AW;
                        end else begin
                            m_araddr <= {req_addr[31:6],6'b0};
                            m_arid<=4'h3; m_arlen<=8'd15; m_arvalid<=1'b1; st<=RD_AR;
                        end
                    end
                end
                WB_AW: begin
                    if (m_awvalid && m_awready) begin m_awvalid<=0; beat<=0; st<=WB_W; end
                end
                WB_W: begin
                    if(!m_wvalid) begin
                        m_wvalid<=1'b1; m_wdata<=data_arr[idx][victim_way][beat]; m_wstrb<=4'hF; m_wlast<=(beat==4'd15);
                    end else if (m_wvalid && m_wready) begin
                        m_wvalid<=0; beat<=beat+1'b1;
                        if (beat==4'd15) begin m_bready<=1'b1; st<=WB_B; end
                    end
                end
                WB_B: begin
                    if (m_bvalid && m_bready) begin
                        if (m_bresp != `AXI_RESP_OKAY) req_resp <= m_bresp;
                        m_bready<=0;
                        dirty_arr[idx][victim_way] <= 1'b0;
                        m_araddr <= {req_addr[31:6],6'b0};
                        m_arid<=4'h3; m_arlen<=8'd15; m_arvalid<=1'b1; st<=RD_AR;
                    end
                end
                RD_AR: begin
                    if (m_arvalid && m_arready) begin m_arvalid<=0; beat<=0; st<=RD_R; end
                end
                RD_R: begin
                    if (m_rvalid && m_rready) begin
                        data_arr[idx][victim_way][beat] <= m_rdata;
                        beat <= beat + 1'b1;
                        if (m_rlast) begin
                            tag_arr[idx][victim_way] <= tag;
                            val_arr[idx][victim_way] <= 1'b1;
                            dirty_arr[idx][victim_way] <= 1'b0;
                            plru_arr[idx] <= plru_upd(plru_arr[idx], victim_way);
                            if (req_is_wr) begin
                                if (req_wstrb[0]) data_arr[idx][victim_way][off][7:0] <= req_wdata[7:0];
                                if (req_wstrb[1]) data_arr[idx][victim_way][off][15:8] <= req_wdata[15:8];
                                if (req_wstrb[2]) data_arr[idx][victim_way][off][23:16] <= req_wdata[23:16];
                                if (req_wstrb[3]) data_arr[idx][victim_way][off][31:24] <= req_wdata[31:24];
                                dirty_arr[idx][victim_way] <= 1'b1;
                                st<=RESP_W;
                            end else begin
                                // 进入FILL_DONE等待1拍，确保NBA写入data_arr已提交
                                st<=FILL_DONE;
                            end
                        end
                    end
                end
                // FILL_DONE：data_arr中的填充数据已由RD_R的NBA提交，可安全读取
                FILL_DONE: begin
                    s_rid    <= req_id;
                    s_rdata  <= data_arr[idx][victim_way][off];
                    s_rresp  <= req_resp;
                    s_rlast  <= 1'b1;
                    s_rvalid <= 1'b1;
                    st <= RESP_R;
                end
                RESP_R: begin
                    if (s_rvalid && s_rready) begin s_rvalid<=0; s_rlast<=0; st<=IDLE; end
                end
                RESP_W: begin
                    s_bid<=req_id; s_bresp<=req_resp; s_bvalid<=1'b1;
                    if (s_bvalid && s_bready) begin s_bvalid<=0; st<=IDLE; end
                end
                // --------------------------------------------------------
                // 非缓存（NC）直通状态：将事务透传到下游AXI总线
                // --------------------------------------------------------
                // NC写：AW + W 同拍发出，等待两路握手后进入B等待
                NC_WR_AW: begin
                    if (m_awvalid && m_awready) m_awvalid <= 0;
                    if (m_wvalid  && m_wready)  begin m_wvalid <= 0; m_wlast <= 0; end
                    if ((!m_awvalid || m_awready) && (!m_wvalid || m_wready)) begin
                        m_bready <= 1'b1;
                        st <= NC_WR_B;
                    end
                end
                NC_WR_B: begin
                    if (m_bvalid && m_bready) begin
                        m_bready <= 0;
                        req_resp <= m_bresp;
                        st <= RESP_W;
                    end
                end
                // NC读：单拍AR，接收R数据后直接回给上游
                NC_RD_AR: begin
                    if (m_arvalid && m_arready) begin
                        m_arvalid <= 0;
                        st <= NC_RD_R;
                    end
                end
                NC_RD_R: begin
                    if (m_rvalid && m_rready) begin
                        // 直接捕获m_rdata（不经过data_arr，无NBA竞争）
                        s_rdata  <= m_rdata;
                        s_rid    <= req_id;
                        s_rresp  <= m_rresp;
                        s_rlast  <= 1'b1;
                        s_rvalid <= 1'b1;
                        st <= RESP_R;
                    end
                end
            endcase
        end
    end
endmodule
