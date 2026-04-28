// ================================================================
// tb_dma_engine.sv - DMA engine unit testbench
// Author: hhh237732
// Tests: register programming, start, completion, interrupt
// ================================================================
`timescale 1ns/1ps
`include "../rtl/axi4_defines.vh"

module tb_dma_engine;

    logic        clk, rst_n;

    // ---- TB drives (DUT inputs) ----
    // CFG slave inputs
    logic        cfg_awvalid; logic [31:0] cfg_awaddr; logic [3:0] cfg_awid;
    logic  [7:0] cfg_awlen;   logic  [2:0] cfg_awsize; logic [1:0] cfg_awburst;
    logic        cfg_wvalid;  logic [31:0] cfg_wdata;  logic [3:0] cfg_wstrb;
    logic        cfg_wlast;   logic        cfg_bready;
    logic        cfg_arvalid; logic [31:0] cfg_araddr; logic [3:0] cfg_arid;
    logic  [7:0] cfg_arlen;   logic  [2:0] cfg_arsize; logic [1:0] cfg_arburst;
    logic        cfg_rready;
    // DMA master inputs (from mem model)
    logic        dma_arready;
    logic        dma_rvalid;  logic [31:0] dma_rdata;  logic [3:0] dma_rid;
    logic  [1:0] dma_rresp;   logic        dma_rlast;
    logic        dma_awready;
    logic        dma_wready;
    logic        dma_bvalid;  logic [3:0] dma_bid;     logic [1:0] dma_bresp;

    // ---- DUT drives (DUT outputs) ----
    wire         cfg_awready, cfg_wready, cfg_bvalid;
    wire  [3:0]  cfg_bid;
    wire  [1:0]  cfg_bresp;
    wire         cfg_arready, cfg_rvalid, cfg_rlast;
    wire [31:0]  cfg_rdata;
    wire  [3:0]  cfg_rid;
    wire  [1:0]  cfg_rresp;
    wire         dma_arvalid; wire [31:0] dma_araddr; wire [3:0] dma_arid;
    wire  [7:0]  dma_arlen;   wire  [2:0] dma_arsize; wire [1:0] dma_arburst;
    wire         dma_rready;
    wire         dma_awvalid; wire [31:0] dma_awaddr; wire [3:0] dma_awid;
    wire  [7:0]  dma_awlen;   wire  [2:0] dma_awsize; wire [1:0] dma_awburst;
    wire         dma_wvalid;  wire [31:0] dma_wdata;  wire [3:0] dma_wstrb;
    wire         dma_wlast;   wire        dma_bready;
    wire         irq;

    dma_ctrl dut (.*);

    // Tie off burst/len for single-beat config writes
    assign cfg_awlen = 8'd0; assign cfg_awsize = 3'd2; assign cfg_awburst = 2'd1;
    assign cfg_arlen = 8'd0; assign cfg_arsize = 3'd2; assign cfg_arburst = 2'd1;
    assign cfg_wlast = 1'b1;

    always #5 clk = ~clk;

    // ----------------------------------------------------------------
    // Memory model (256 words)
    // ----------------------------------------------------------------
    logic [31:0] mem [0:255];
    initial foreach(mem[i]) mem[i] = 32'h1000_0000 + i;

    // AXI master read responder
    logic [31:0] rd_base;
    logic  [3:0] rd_id_lat;
    int rd_beat_r, rd_len_lat;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_arready <= 1; dma_rvalid <= 0; dma_rdata <= 0;
            dma_rid <= 0; dma_rresp <= 0; dma_rlast <= 0;
            rd_beat_r <= 0; rd_len_lat <= 0;
        end else begin
            if (dma_arvalid && dma_arready) begin
                rd_base    <= dma_araddr; rd_id_lat  <= dma_arid;
                rd_len_lat <= dma_arlen;  dma_arready <= 0;
                rd_beat_r  <= 0;
            end
            if (!dma_arready || dma_rvalid) begin
                dma_rvalid <= 1;
                dma_rid    <= rd_id_lat;
                dma_rresp  <= `AXI_RESP_OKAY;
                dma_rdata  <= mem[(rd_base[9:2] + rd_beat_r) % 256];
                dma_rlast  <= (rd_beat_r == rd_len_lat);
                if (dma_rvalid && dma_rready) begin
                    if (rd_beat_r == rd_len_lat) begin
                        dma_rvalid <= 0; dma_rlast <= 0; dma_arready <= 1;
                    end
                    rd_beat_r <= rd_beat_r + 1;
                end
            end
        end
    end

    // AXI master write responder
    logic [31:0] wr_mem [0:255];
    logic [31:0] wr_base_lat;
    int wr_beat_w;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_awready <= 1; dma_wready <= 0;
            dma_bvalid  <= 0; dma_bid    <= 0; dma_bresp <= 0;
            wr_beat_w <= 0;
        end else begin
            if (dma_awvalid && dma_awready) begin
                dma_awready  <= 0; dma_wready <= 1;
                wr_base_lat  <= dma_awaddr; wr_beat_w <= 0;
            end
            if (dma_wvalid && dma_wready) begin
                wr_mem[(wr_base_lat[9:2] + wr_beat_w) % 256] <= dma_wdata;
                wr_beat_w <= wr_beat_w + 1;
                if (dma_wlast) begin
                    dma_wready <= 0; dma_bvalid <= 1;
                    dma_bid    <= dma_awid; dma_bresp <= `AXI_RESP_OKAY;
                end
            end
            if (dma_bvalid && dma_bready) begin
                dma_bvalid <= 0; dma_awready <= 1;
            end
        end
    end

    // ----------------------------------------------------------------
    // Driver tasks
    // ----------------------------------------------------------------
    task automatic wait_clk(int n = 1); repeat(n) @(posedge clk); endtask

    task automatic cfg_write(input logic [31:0] addr, input logic [31:0] data);
        int t;
        @(posedge clk);
        cfg_awvalid <= 1; cfg_awaddr <= addr; cfg_awid <= 0;
        cfg_wvalid  <= 1; cfg_wdata  <= data; cfg_wstrb <= 4'hF;
        cfg_bready  <= 1;
        t = 0;
        do begin @(posedge clk); t++;
            if (t > 100) begin $display("CFG WR AW timeout"); $finish; end
        end while (!(cfg_awvalid && cfg_awready));
        cfg_awvalid <= 0;
        do begin @(posedge clk); t++;
            if (t > 100) begin $display("CFG WR W timeout"); $finish; end
        end while (!(cfg_wvalid && cfg_wready));
        cfg_wvalid <= 0;
        do begin @(posedge clk); t++;
            if (t > 100) begin $display("CFG WR B timeout"); $finish; end
        end while (!cfg_bvalid);
    endtask

    int fails;

    initial begin
        clk = 0; rst_n = 0; fails = 0;
        cfg_awvalid = 0; cfg_wvalid = 0; cfg_arvalid = 0;
        cfg_awid = 0; cfg_arid = 0;
        cfg_bready = 1; cfg_rready = 1;

        wait_clk(5);
        rst_n = 1;
        wait_clk(2);

        // Program DMA (DMA base = 0x1000_0000 per soc_top)
        $display("[TC1] DMA: src=0x0000_0000 dst=0x0000_0040 len=8 words");
        cfg_write(32'h1000_0008, 32'h0000_0000); // SRC
        cfg_write(32'h1000_000C, 32'h0000_0040); // DST
        cfg_write(32'h1000_0010, 32'd8);          // LEN
        cfg_write(32'h1000_0014, 32'h3);           // INT_EN done+err
        cfg_write(32'h1000_0000, 32'h1);           // START

        // Wait for IRQ (max 10000 cycles)
        begin : wait_irq
            int t;
            t = 0;
            while (!irq) begin
                @(posedge clk); t++;
                if (t > 10000) begin
                    $display("[TC1] DMA TIMEOUT after %0d cycles", t);
                    fails++;
                    disable wait_irq;
                end
            end
            $display("[TC1] DMA IRQ asserted after %0d cycles", t);
        end

        // TC2: Verify transferred data
        $display("[TC2] Verify transferred data");
        for (int i = 0; i < 8; i++) begin
            if (wr_mem[0+i] !== mem[i]) begin
                $display("  FAIL word%0d: got %08h exp %08h", i, wr_mem[0+i], mem[i]);
                fails++;
            end
        end
        if (fails == 0) $display("  PASS: all 8 words match");

        // TC3: IRQ stays asserted until STATUS cleared
        $display("[TC3] IRQ asserted = %b (expect 1)", irq);
        if (!irq) begin $display("  FAIL: IRQ not asserted"); fails++; end
        else $display("  PASS");

        if (fails == 0)
            $display("[TB_DMA] ALL TESTS PASSED");
        else
            $display("[TB_DMA] %0d FAILURE(S)", fails);
        #50 $finish;
    end

    initial begin #500000; $display("[TB_DMA] TIMEOUT"); $finish; end

endmodule
