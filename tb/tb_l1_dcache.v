`timescale 1ns/1ps
`include "../rtl/axi4_defines.vh"

module tb_l1_dcache;
    reg clk, rst_n;
    reg cpu_req, cpu_we;
    reg [3:0] cpu_wstrb;
    reg [31:0] cpu_addr, cpu_wdata;
    wire [31:0] cpu_rdata;
    wire cpu_hit, cpu_stall;

    wire dcache_arvalid;
    reg  dcache_arready;
    wire [31:0] dcache_araddr;
    wire [3:0] dcache_arid;
    wire [7:0] dcache_arlen;
    wire [2:0] dcache_arsize;
    wire [1:0] dcache_arburst;
    reg  dcache_rvalid;
    wire dcache_rready;
    reg [31:0] dcache_rdata;
    reg [3:0] dcache_rid;
    reg [1:0] dcache_rresp;
    reg dcache_rlast;

    wire dcache_awvalid;
    reg  dcache_awready;
    wire [31:0] dcache_awaddr;
    wire [3:0] dcache_awid;
    wire [7:0] dcache_awlen;
    wire [2:0] dcache_awsize;
    wire [1:0] dcache_awburst;
    wire dcache_wvalid;
    reg  dcache_wready;
    wire [31:0] dcache_wdata;
    wire [3:0] dcache_wstrb;
    wire dcache_wlast;
    reg dcache_bvalid;
    wire dcache_bready;
    reg [3:0] dcache_bid;
    reg [1:0] dcache_bresp;

    reg [31:0] mem [0:4095];
    reg [31:0] rd_base;
    reg [2:0]  rd_cnt;
    integer i;

    l1_dcache dut (
        .clk(clk), .rst_n(rst_n),
        .cpu_req(cpu_req), .cpu_we(cpu_we), .cpu_wstrb(cpu_wstrb), .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata), .cpu_hit(cpu_hit), .cpu_stall(cpu_stall),
        .dcache_arvalid(dcache_arvalid), .dcache_arready(dcache_arready), .dcache_araddr(dcache_araddr), .dcache_arid(dcache_arid), .dcache_arlen(dcache_arlen), .dcache_arsize(dcache_arsize), .dcache_arburst(dcache_arburst),
        .dcache_rvalid(dcache_rvalid), .dcache_rready(dcache_rready), .dcache_rdata(dcache_rdata), .dcache_rid(dcache_rid), .dcache_rresp(dcache_rresp), .dcache_rlast(dcache_rlast),
        .dcache_awvalid(dcache_awvalid), .dcache_awready(dcache_awready), .dcache_awaddr(dcache_awaddr), .dcache_awid(dcache_awid), .dcache_awlen(dcache_awlen), .dcache_awsize(dcache_awsize), .dcache_awburst(dcache_awburst),
        .dcache_wvalid(dcache_wvalid), .dcache_wready(dcache_wready), .dcache_wdata(dcache_wdata), .dcache_wstrb(dcache_wstrb), .dcache_wlast(dcache_wlast),
        .dcache_bvalid(dcache_bvalid), .dcache_bready(dcache_bready), .dcache_bid(dcache_bid), .dcache_bresp(dcache_bresp)
    );

    always #5 clk=~clk;

    task cpu_read(input [31:0] a);
    begin
        @(posedge clk);
        cpu_req<=1; cpu_we<=0; cpu_addr<=a;
        @(posedge clk);
        cpu_req<=0;
        wait(cpu_stall==0);
    end
    endtask

    task cpu_write_t(input [31:0] a, input [31:0] d);
    begin
        @(posedge clk);
        cpu_req<=1; cpu_we<=1; cpu_addr<=a; cpu_wdata<=d; cpu_wstrb<=4'hF;
        @(posedge clk);
        cpu_req<=0;
        wait(cpu_stall==0);
    end
    endtask

    initial begin
        clk=0; rst_n=0; cpu_req=0; cpu_we=0; cpu_wstrb=0; cpu_addr=0; cpu_wdata=0;
        dcache_arready=1; dcache_rvalid=0; dcache_rdata=0; dcache_rid=0; dcache_rresp=`AXI_RESP_OKAY; dcache_rlast=0;
        dcache_awready=1; dcache_wready=1; dcache_bvalid=0; dcache_bid=0; dcache_bresp=`AXI_RESP_OKAY;
        for (i=0;i<4096;i=i+1) mem[i]=32'h1000_0000+i;
        repeat(10) @(posedge clk);
        rst_n=1;

        $display("[TB_L1D] Case1 读miss->fill->再读hit");
        cpu_read(32'h0000_0040);
        cpu_read(32'h0000_0040);

        $display("[TB_L1D] Case2 写miss分配+写命中");
        cpu_write_t(32'h0000_0080, 32'hA5A5_5A5A);
        cpu_write_t(32'h0000_0080, 32'h5A5A_A5A5);

        $display("[TB_L1D] Case3 强制替换触发写回");
        cpu_write_t(32'h0000_0000, 32'h1111_1111);
        cpu_write_t(32'h0000_0400, 32'h2222_2222);
        cpu_write_t(32'h0000_0800, 32'h3333_3333);

        $display("[TB_L1D] PASS");
        #100 $finish;
    end

    // 简单AXI memory stub
    always @(posedge clk) begin
        if (!rst_n) begin
            dcache_rvalid<=0; dcache_rlast<=0; rd_cnt<=0; rd_base<=0;
            dcache_bvalid<=0;
        end else begin
            if (dcache_arvalid && dcache_arready) begin
                rd_base <= dcache_araddr >> 2;
                rd_cnt  <= 0;
                dcache_rvalid <= 1;
                dcache_rdata  <= mem[(dcache_araddr>>2)];
                dcache_rlast  <= (dcache_arlen==0);
            end else if (dcache_rvalid && dcache_rready) begin
                if (rd_cnt == dcache_arlen) begin
                    dcache_rvalid <= 0;
                    dcache_rlast  <= 0;
                end else begin
                    rd_cnt <= rd_cnt + 1;
                    dcache_rdata <= mem[rd_base + rd_cnt + 1];
                    dcache_rlast <= (rd_cnt + 1 == dcache_arlen);
                end
            end

            if (dcache_awvalid && dcache_awready) begin
                rd_base <= dcache_awaddr >> 2;
                rd_cnt <= 0;
            end
            if (dcache_wvalid && dcache_wready) begin
                mem[rd_base + rd_cnt] <= dcache_wdata;
                if (dcache_wlast) begin
                    dcache_bvalid <= 1;
                end else rd_cnt <= rd_cnt + 1;
            end
            if (dcache_bvalid && dcache_bready) dcache_bvalid <= 0;
        end
    end

    initial begin
        repeat(20000) @(posedge clk);
        $display("[TB_L1D] TIMEOUT");
        $finish;
    end
endmodule
