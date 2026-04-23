`timescale 1ns/1ps
`include "../rtl/axi4_defines.vh"

module tb_sync_fifo;
    reg clk;
    reg rst_n;
    reg wr_en;
    reg [31:0] wr_data;
    reg rd_en;
    wire [31:0] rd_data;
    wire full, almost_full, empty, almost_empty;
    wire [8:0] data_count;

    integer i;
    integer err;

    sync_fifo dut (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_data(wr_data), .full(full), .almost_full(almost_full),
        .rd_en(rd_en), .rd_data(rd_data), .empty(empty), .almost_empty(almost_empty),
        .data_count(data_count)
    );

    always #5 clk = ~clk;

    task push(input [31:0] d);
    begin
        @(posedge clk);
        wr_en <= 1'b1;
        wr_data <= d;
        rd_en <= 1'b0;
        @(posedge clk);
        wr_en <= 1'b0;
    end
    endtask

    task pop;
    begin
        @(posedge clk);
        rd_en <= 1'b1;
        wr_en <= 1'b0;
        @(posedge clk);
        rd_en <= 1'b0;
    end
    endtask

    initial begin
        clk=0; rst_n=0; wr_en=0; wr_data=0; rd_en=0; err=0;
        repeat(5) @(posedge clk);
        rst_n=1;

        $display("[TB_FIFO] Case1: 基本读写");
        for (i=0;i<16;i=i+1) push(i);
        if (data_count != 16) begin $display("FAIL: data_count != 16"); err=err+1; end
        for (i=0;i<16;i=i+1) pop();
        if (!empty) begin $display("FAIL: FIFO should be empty"); err=err+1; end

        $display("[TB_FIFO] Case2: 写满与full保护");
        for (i=0;i<256;i=i+1) push(i+32'h1000);
        if (!full) begin $display("FAIL: full not asserted"); err=err+1; end
        push(32'hDEAD_BEEF);
        if (data_count != 9'd256) begin $display("FAIL: overflow write should be blocked"); err=err+1; end

        $display("[TB_FIFO] Case3: 读空与empty保护");
        for (i=0;i<256;i=i+1) pop();
        if (!empty) begin $display("FAIL: empty not asserted"); err=err+1; end
        pop();
        if (data_count != 0) begin $display("FAIL: underflow read should be blocked"); err=err+1; end

        $display("[TB_FIFO] Case4: random mixed");
        for (i=0;i<200;i=i+1) begin
            @(posedge clk);
            wr_en <= ($random % 3) != 0;
            rd_en <= ($random % 2) == 0;
            wr_data <= $random;
        end
        @(posedge clk); wr_en<=0; rd_en<=0;

        $display("[TB_FIFO] Case5/6: almost flag与计数检查");
        if (almost_empty !== (data_count <= 16)) begin $display("FAIL: almost_empty mismatch"); err=err+1; end
        if (almost_full  !== (data_count >= 240)) begin $display("FAIL: almost_full mismatch"); err=err+1; end

        if (err==0) $display("[TB_FIFO] PASS");
        else $display("[TB_FIFO] FAIL, err=%0d", err);
        #20;
        $finish;
    end

    initial begin
        repeat (10000) @(posedge clk);
        $display("[TB_FIFO] TIMEOUT");
        $finish;
    end
endmodule
