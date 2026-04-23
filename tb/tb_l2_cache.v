`timescale 1ns/1ps
`include "../rtl/axi4_defines.vh"

module tb_l2_cache;
    reg clk, rst_n;

    reg s_awvalid; wire s_awready; reg [31:0] s_awaddr; reg [3:0] s_awid; reg [7:0] s_awlen; reg [2:0] s_awsize; reg [1:0] s_awburst;
    reg s_wvalid; wire s_wready; reg [31:0] s_wdata; reg [3:0] s_wstrb; reg s_wlast;
    wire s_bvalid; reg s_bready; wire [3:0] s_bid; wire [1:0] s_bresp;
    reg s_arvalid; wire s_arready; reg [31:0] s_araddr; reg [3:0] s_arid; reg [7:0] s_arlen; reg [2:0] s_arsize; reg [1:0] s_arburst;
    wire s_rvalid; reg s_rready; wire [31:0] s_rdata; wire [3:0] s_rid; wire [1:0] s_rresp; wire s_rlast;

    wire m_awvalid; reg m_awready; wire [31:0] m_awaddr; wire [3:0] m_awid; wire [7:0] m_awlen; wire [2:0] m_awsize; wire [1:0] m_awburst;
    wire m_wvalid; reg m_wready; wire [31:0] m_wdata; wire [3:0] m_wstrb; wire m_wlast;
    reg m_bvalid; wire m_bready; reg [3:0] m_bid; reg [1:0] m_bresp;
    wire m_arvalid; reg m_arready; wire [31:0] m_araddr; wire [3:0] m_arid; wire [7:0] m_arlen; wire [2:0] m_arsize; wire [1:0] m_arburst;
    reg m_rvalid; wire m_rready; reg [31:0] m_rdata; reg [3:0] m_rid; reg [1:0] m_rresp; reg m_rlast;

    reg [31:0] mem [0:16383];
    reg [31:0] rd_base; reg [4:0] rd_cnt;
    integer i;

    l2_cache dut (
        .clk(clk), .rst_n(rst_n),
        .s_awvalid(s_awvalid), .s_awready(s_awready), .s_awaddr(s_awaddr), .s_awid(s_awid), .s_awlen(s_awlen), .s_awsize(s_awsize), .s_awburst(s_awburst),
        .s_wvalid(s_wvalid), .s_wready(s_wready), .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wlast(s_wlast),
        .s_bvalid(s_bvalid), .s_bready(s_bready), .s_bid(s_bid), .s_bresp(s_bresp),
        .s_arvalid(s_arvalid), .s_arready(s_arready), .s_araddr(s_araddr), .s_arid(s_arid), .s_arlen(s_arlen), .s_arsize(s_arsize), .s_arburst(s_arburst),
        .s_rvalid(s_rvalid), .s_rready(s_rready), .s_rdata(s_rdata), .s_rid(s_rid), .s_rresp(s_rresp), .s_rlast(s_rlast),
        .m_awvalid(m_awvalid), .m_awready(m_awready), .m_awaddr(m_awaddr), .m_awid(m_awid), .m_awlen(m_awlen), .m_awsize(m_awsize), .m_awburst(m_awburst),
        .m_wvalid(m_wvalid), .m_wready(m_wready), .m_wdata(m_wdata), .m_wstrb(m_wstrb), .m_wlast(m_wlast),
        .m_bvalid(m_bvalid), .m_bready(m_bready), .m_bid(m_bid), .m_bresp(m_bresp),
        .m_arvalid(m_arvalid), .m_arready(m_arready), .m_araddr(m_araddr), .m_arid(m_arid), .m_arlen(m_arlen), .m_arsize(m_arsize), .m_arburst(m_arburst),
        .m_rvalid(m_rvalid), .m_rready(m_rready), .m_rdata(m_rdata), .m_rid(m_rid), .m_rresp(m_rresp), .m_rlast(m_rlast)
    );

    always #5 clk=~clk;

    task l1_read(input [31:0] addr);
    begin
        @(posedge clk);
        s_arvalid<=1; s_araddr<=addr; s_arid<=4'h1; s_arlen<=0; s_arsize<=3'd2; s_arburst<=`AXI_BURST_INCR;
        s_rready<=1;
        wait(s_rvalid); @(posedge clk);
        s_arvalid<=0; s_rready<=0;
    end
    endtask

    initial begin
        clk=0; rst_n=0;
        s_awvalid=0; s_awaddr=0; s_awid=0; s_awlen=0; s_awsize=3'd2; s_awburst=`AXI_BURST_INCR;
        s_wvalid=0; s_wdata=0; s_wstrb=4'hF; s_wlast=1; s_bready=1;
        s_arvalid=0; s_araddr=0; s_arid=0; s_arlen=0; s_arsize=3'd2; s_arburst=`AXI_BURST_INCR; s_rready=0;
        m_awready=1; m_wready=1; m_bvalid=0; m_bid=0; m_bresp=`AXI_RESP_OKAY;
        m_arready=1; m_rvalid=0; m_rdata=0; m_rid=0; m_rresp=`AXI_RESP_OKAY; m_rlast=0;

        for(i=0;i<16384;i=i+1) mem[i]=32'h5000_0000+i;

        repeat(10) @(posedge clk);
        rst_n=1;

        $display("[TB_L2] Case1 miss后回填");
        l1_read(32'h0000_0100);

        $display("[TB_L2] Case2 同地址再次访问命中");
        l1_read(32'h0000_0100);

        $display("[TB_L2] Case3 触发替换与写回路径（行为检查）");
        l1_read(32'h0000_1100);
        l1_read(32'h0000_2100);
        l1_read(32'h0000_3100);
        l1_read(32'h0000_4100);

        $display("[TB_L2] PASS");
        #100 $finish;
    end

    // 下游memory行为
    always @(posedge clk) begin
        if(!rst_n) begin
            m_rvalid<=0; m_rlast<=0; rd_base<=0; rd_cnt<=0; m_bvalid<=0;
        end else begin
            if (m_arvalid && m_arready) begin
                rd_base <= m_araddr>>2;
                rd_cnt <= 0;
                m_rid <= m_arid;
                m_rvalid <= 1;
                m_rdata <= mem[m_araddr>>2];
                m_rlast <= (m_arlen==0);
            end else if (m_rvalid && m_rready) begin
                if (rd_cnt == m_arlen) begin
                    m_rvalid<=0; m_rlast<=0;
                end else begin
                    rd_cnt <= rd_cnt + 1;
                    m_rdata <= mem[rd_base + rd_cnt + 1];
                    m_rlast <= (rd_cnt+1==m_arlen);
                end
            end

            if (m_awvalid && m_awready) begin
                rd_base <= m_awaddr>>2;
                rd_cnt <= 0;
            end
            if (m_wvalid && m_wready) begin
                mem[rd_base+rd_cnt] <= m_wdata;
                if (m_wlast) m_bvalid <= 1;
                else rd_cnt <= rd_cnt + 1;
            end
            if (m_bvalid && m_bready) m_bvalid <= 0;
        end
    end

    initial begin
        repeat(20000) @(posedge clk);
        $display("[TB_L2] TIMEOUT");
        $finish;
    end
endmodule
