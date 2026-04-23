`timescale 1ns/1ps
`include "../rtl/axi4_defines.vh"

module tb_dma;
    reg clk, rst_n;

    // cfg master(BFM)
    reg         cfg_awvalid;
    wire        cfg_awready;
    reg [31:0]  cfg_awaddr;
    reg [3:0]   cfg_awid;
    reg [7:0]   cfg_awlen;
    reg [2:0]   cfg_awsize;
    reg [1:0]   cfg_awburst;
    reg         cfg_wvalid;
    wire        cfg_wready;
    reg [31:0]  cfg_wdata;
    reg [3:0]   cfg_wstrb;
    reg         cfg_wlast;
    wire        cfg_bvalid;
    reg         cfg_bready;
    wire [3:0]  cfg_bid;
    wire [1:0]  cfg_bresp;
    reg         cfg_arvalid;
    wire        cfg_arready;
    reg [31:0]  cfg_araddr;
    reg [3:0]   cfg_arid;
    reg [7:0]   cfg_arlen;
    reg [2:0]   cfg_arsize;
    reg [1:0]   cfg_arburst;
    wire        cfg_rvalid;
    reg         cfg_rready;
    wire [31:0] cfg_rdata;
    wire [3:0]  cfg_rid;
    wire [1:0]  cfg_rresp;
    wire        cfg_rlast;

    // dma master -> memory
    wire        dma_awvalid;
    reg         dma_awready;
    wire [31:0] dma_awaddr;
    wire [3:0]  dma_awid;
    wire [7:0]  dma_awlen;
    wire [2:0]  dma_awsize;
    wire [1:0]  dma_awburst;
    wire        dma_wvalid;
    reg         dma_wready;
    wire [31:0] dma_wdata;
    wire [3:0]  dma_wstrb;
    wire        dma_wlast;
    reg         dma_bvalid;
    wire        dma_bready;
    reg [3:0]   dma_bid;
    reg [1:0]   dma_bresp;
    wire        dma_arvalid;
    reg         dma_arready;
    wire [31:0] dma_araddr;
    wire [3:0]  dma_arid;
    wire [7:0]  dma_arlen;
    wire [2:0]  dma_arsize;
    wire [1:0]  dma_arburst;
    reg         dma_rvalid;
    wire        dma_rready;
    reg [31:0]  dma_rdata;
    reg [3:0]   dma_rid;
    reg [1:0]   dma_rresp;
    reg         dma_rlast;

    wire irq;

    reg [7:0] mem [0:65535];
    reg [31:0] rd_addr, wr_addr;
    reg [8:0]  rd_left, wr_left;

    integer i;
    integer err;

    dma_ctrl dut (
        .clk(clk), .rst_n(rst_n),
        .cfg_awvalid(cfg_awvalid), .cfg_awready(cfg_awready), .cfg_awaddr(cfg_awaddr), .cfg_awid(cfg_awid), .cfg_awlen(cfg_awlen), .cfg_awsize(cfg_awsize), .cfg_awburst(cfg_awburst),
        .cfg_wvalid(cfg_wvalid), .cfg_wready(cfg_wready), .cfg_wdata(cfg_wdata), .cfg_wstrb(cfg_wstrb), .cfg_wlast(cfg_wlast),
        .cfg_bvalid(cfg_bvalid), .cfg_bready(cfg_bready), .cfg_bid(cfg_bid), .cfg_bresp(cfg_bresp),
        .cfg_arvalid(cfg_arvalid), .cfg_arready(cfg_arready), .cfg_araddr(cfg_araddr), .cfg_arid(cfg_arid), .cfg_arlen(cfg_arlen), .cfg_arsize(cfg_arsize), .cfg_arburst(cfg_arburst),
        .cfg_rvalid(cfg_rvalid), .cfg_rready(cfg_rready), .cfg_rdata(cfg_rdata), .cfg_rid(cfg_rid), .cfg_rresp(cfg_rresp), .cfg_rlast(cfg_rlast),
        .dma_arvalid(dma_arvalid), .dma_arready(dma_arready), .dma_araddr(dma_araddr), .dma_arid(dma_arid), .dma_arlen(dma_arlen), .dma_arsize(dma_arsize), .dma_arburst(dma_arburst),
        .dma_rvalid(dma_rvalid), .dma_rready(dma_rready), .dma_rdata(dma_rdata), .dma_rid(dma_rid), .dma_rresp(dma_rresp), .dma_rlast(dma_rlast),
        .dma_awvalid(dma_awvalid), .dma_awready(dma_awready), .dma_awaddr(dma_awaddr), .dma_awid(dma_awid), .dma_awlen(dma_awlen), .dma_awsize(dma_awsize), .dma_awburst(dma_awburst),
        .dma_wvalid(dma_wvalid), .dma_wready(dma_wready), .dma_wdata(dma_wdata), .dma_wstrb(dma_wstrb), .dma_wlast(dma_wlast),
        .dma_bvalid(dma_bvalid), .dma_bready(dma_bready), .dma_bid(dma_bid), .dma_bresp(dma_bresp),
        .irq(irq)
    );

    always #5 clk = ~clk;

    task cpu_write(input [31:0] a, input [31:0] d);
    begin
        @(posedge clk);
        cfg_awaddr<=a; cfg_awid<=0; cfg_awlen<=0; cfg_awsize<=3'd2; cfg_awburst<=`AXI_BURST_INCR; cfg_awvalid<=1;
        cfg_wdata<=d; cfg_wstrb<=4'hF; cfg_wlast<=1; cfg_wvalid<=1;
        cfg_bready<=1;
        wait(cfg_bvalid); @(posedge clk);
        cfg_awvalid<=0; cfg_wvalid<=0; cfg_bready<=0;
    end
    endtask

    initial begin
        clk=0; rst_n=0; err=0;
        cfg_awvalid=0; cfg_awaddr=0; cfg_awid=0; cfg_awlen=0; cfg_awsize=0; cfg_awburst=0;
        cfg_wvalid=0; cfg_wdata=0; cfg_wstrb=0; cfg_wlast=0; cfg_bready=0;
        cfg_arvalid=0; cfg_araddr=0; cfg_arid=0; cfg_arlen=0; cfg_arsize=0; cfg_arburst=0; cfg_rready=0;
        dma_awready=1; dma_wready=1; dma_bvalid=0; dma_bid=0; dma_bresp=`AXI_RESP_OKAY;
        dma_arready=1; dma_rvalid=0; dma_rdata=0; dma_rid=0; dma_rresp=`AXI_RESP_OKAY; dma_rlast=0;
        rd_addr=0; wr_addr=0; rd_left=0; wr_left=0;

        for (i=0;i<65536;i=i+1) mem[i]=0;
        for (i=0;i<1024;i=i+1) begin
            mem[16'h0100 + i*4 + 0] = i[7:0];
            mem[16'h0100 + i*4 + 1] = i[15:8];
            mem[16'h0100 + i*4 + 2] = 8'h55;
            mem[16'h0100 + i*4 + 3] = 8'hAA;
        end

        repeat(10) @(posedge clk);
        rst_n=1;

        $display("[TB_DMA] Case1 启动256B搬运");
        cpu_write(32'h1000_0008, 32'h0000_0100);
        cpu_write(32'h1000_000C, 32'h0000_1100);
        cpu_write(32'h1000_0010, 32'd256);
        cpu_write(32'h1000_0014, 32'h1);
        cpu_write(32'h1000_0000, 32'h1);

        wait(irq==1'b1);
        repeat(10) @(posedge clk);

        for (i=0;i<64;i=i+1) begin
            if ({mem[16'h1100+i*4+3],mem[16'h1100+i*4+2],mem[16'h1100+i*4+1],mem[16'h1100+i*4+0]} !==
                {mem[16'h0100+i*4+3],mem[16'h0100+i*4+2],mem[16'h0100+i*4+1],mem[16'h0100+i*4+0]}) begin
                err=err+1;
            end
        end

        $display("[TB_DMA] Case2 4KB边界拆分");
        cpu_write(32'h1000_0008, 32'h0000_0F00);
        cpu_write(32'h1000_000C, 32'h0000_2000);
        cpu_write(32'h1000_0010, 32'd1024);
        cpu_write(32'h1000_0000, 32'h1);
        wait(irq==1'b1);
        repeat(20) @(posedge clk);

        if (err==0) $display("[TB_DMA] PASS");
        else $display("[TB_DMA] FAIL err=%0d", err);

        #20 $finish;
    end

    // 简单AXI内存行为
    always @(posedge clk) begin
        if (!rst_n) begin
            dma_bvalid <= 1'b0;
            dma_rvalid <= 1'b0;
            rd_left <= 0; wr_left <= 0;
        end else begin
            // 读地址握手
            if (dma_arvalid && dma_arready) begin
                rd_addr <= dma_araddr;
                rd_left <= dma_arlen;
                dma_rid <= dma_arid;
                dma_rresp <= `AXI_RESP_OKAY;
                dma_rvalid <= 1'b1;
                dma_rdata <= {mem[dma_araddr+3],mem[dma_araddr+2],mem[dma_araddr+1],mem[dma_araddr]};
                dma_rlast <= (dma_arlen==0);
            end else if (dma_rvalid && dma_rready) begin
                if (rd_left==0) dma_rvalid<=0;
                else begin
                    rd_addr <= rd_addr + 4;
                    rd_left <= rd_left - 1;
                    dma_rdata <= {mem[rd_addr+7],mem[rd_addr+6],mem[rd_addr+5],mem[rd_addr+4]};
                    dma_rlast <= (rd_left==1);
                end
            end

            // 写地址握手
            if (dma_awvalid && dma_awready) begin
                wr_addr <= dma_awaddr;
                wr_left <= dma_awlen;
            end
            if (dma_wvalid && dma_wready) begin
                if (dma_wstrb[0]) mem[wr_addr]   <= dma_wdata[7:0];
                if (dma_wstrb[1]) mem[wr_addr+1] <= dma_wdata[15:8];
                if (dma_wstrb[2]) mem[wr_addr+2] <= dma_wdata[23:16];
                if (dma_wstrb[3]) mem[wr_addr+3] <= dma_wdata[31:24];
                if (dma_wlast || wr_left==0) begin
                    dma_bvalid <= 1'b1;
                    dma_bid <= 4'h1;
                    dma_bresp <= `AXI_RESP_OKAY;
                end else begin
                    wr_left <= wr_left - 1;
                    wr_addr <= wr_addr + 4;
                end
            end
            if (dma_bvalid && dma_bready) dma_bvalid <= 1'b0;
        end
    end

    initial begin
        repeat(20000) @(posedge clk);
        $display("[TB_DMA] TIMEOUT");
        $finish;
    end
endmodule
