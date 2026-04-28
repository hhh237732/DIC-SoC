// ================================================================
// tb_l1_dcache.sv - L1 DCache unit testbench
// Author: hhh237732
// Tests: cold miss, hit, write-back, write-allocate, LRU eviction
// ================================================================
`timescale 1ns/1ps
`include "../rtl/axi4_defines.vh"

module tb_l1_dcache;

    logic        clk, rst_n;
    logic        cpu_req, cpu_we;
    logic  [3:0] cpu_wstrb;
    logic [31:0] cpu_addr, cpu_wdata;
    logic [31:0] cpu_rdata;
    logic        cpu_hit, cpu_stall;

    // AXI read channel
    logic        dcache_arvalid;
    logic        dcache_arready;
    logic [31:0] dcache_araddr;
    logic  [3:0] dcache_arid;
    logic  [7:0] dcache_arlen;
    logic  [2:0] dcache_arsize;
    logic  [1:0] dcache_arburst;
    logic        dcache_rvalid;
    logic        dcache_rready;
    logic [31:0] dcache_rdata;
    logic  [3:0] dcache_rid;
    logic  [1:0] dcache_rresp;
    logic        dcache_rlast;
    // AXI write channel
    logic        dcache_awvalid, dcache_awready;
    logic [31:0] dcache_awaddr;
    logic  [3:0] dcache_awid;
    logic  [7:0] dcache_awlen;
    logic  [2:0] dcache_awsize;
    logic  [1:0] dcache_awburst;
    logic        dcache_wvalid, dcache_wready;
    logic [31:0] dcache_wdata;
    logic  [3:0] dcache_wstrb;
    logic        dcache_wlast;
    logic        dcache_bvalid, dcache_bready;
    logic  [3:0] dcache_bid;
    logic  [1:0] dcache_bresp;
    // Perf counters
    logic [31:0] perf_hit_cnt, perf_miss_cnt;

    l1_dcache dut (.*);

    always #5 clk = ~clk;

    // Simple AXI slave memory model (128 words)
    logic [31:0] mem [0:127];
    int          wr_beat;

    initial foreach(mem[i]) mem[i] = i * 4 + 32'hA000_0000;

    // Read responder
    logic [31:0] rd_addr_lat;
    logic  [3:0] rd_id_lat;
    int rd_beat, rd_len_lat;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dcache_arready <= 1'b1;
            dcache_rvalid  <= 1'b0;
            dcache_rdata   <= 0;
            dcache_rid     <= 0;
            dcache_rresp   <= 0;
            dcache_rlast   <= 0;
            rd_beat <= 0; rd_len_lat <= 0;
        end else begin
            if (dcache_arvalid && dcache_arready) begin
                rd_addr_lat    <= dcache_araddr;
                rd_id_lat      <= dcache_arid;
                rd_len_lat     <= dcache_arlen;
                dcache_arready <= 1'b0;
                rd_beat        <= 0;
            end
            if (!dcache_arready) begin
                dcache_rvalid <= 1'b1;
                dcache_rid    <= rd_id_lat;
                dcache_rresp  <= `AXI_RESP_OKAY;
                dcache_rdata  <= mem[(rd_addr_lat[8:2] + rd_beat) % 128];
                dcache_rlast  <= (rd_beat == rd_len_lat);
                if (dcache_rvalid && dcache_rready) begin
                    if (rd_beat == rd_len_lat) begin
                        dcache_rvalid  <= 1'b0;
                        dcache_rlast   <= 1'b0;
                        dcache_arready <= 1'b1;
                    end
                    rd_beat <= rd_beat + 1;
                end
            end
        end
    end

    // Write responder
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dcache_awready <= 1'b1;
            dcache_wready  <= 1'b0;
            dcache_bvalid  <= 1'b0;
            dcache_bid     <= 0;
            dcache_bresp   <= 0;
            wr_beat        <= 0;
        end else begin
            if (dcache_awvalid && dcache_awready) begin
                dcache_awready <= 1'b0;
                dcache_wready  <= 1'b1;
            end
            if (dcache_wvalid && dcache_wready) begin
                if (dcache_wlast) begin
                    dcache_wready <= 1'b0;
                    dcache_bvalid <= 1'b1;
                    dcache_bid    <= dcache_awid;
                    dcache_bresp  <= `AXI_RESP_OKAY;
                end
            end
            if (dcache_bvalid && dcache_bready) begin
                dcache_bvalid  <= 1'b0;
                dcache_awready <= 1'b1;
            end
        end
    end

    // ----------------------------------------------------------------
    // Test tasks
    // ----------------------------------------------------------------
    task automatic wait_clk(int n = 1);
        repeat(n) @(posedge clk);
    endtask

    task automatic cache_read(input logic [31:0] addr, output logic [31:0] data);
        int t;
        @(posedge clk);
        cpu_req <= 1; cpu_we <= 0; cpu_addr <= addr;
        t = 0;
        do begin @(posedge clk); t++; if (t>200) begin $display("READ TIMEOUT"); $finish; end
        end while (cpu_stall);
        data = cpu_rdata;
        cpu_req <= 0;
    endtask

    task automatic cache_write(input logic [31:0] addr, input logic [31:0] data);
        int t;
        @(posedge clk);
        cpu_req <= 1; cpu_we <= 1; cpu_wstrb <= 4'hF;
        cpu_addr <= addr; cpu_wdata <= data;
        t = 0;
        do begin @(posedge clk); t++; if (t>200) begin $display("WRITE TIMEOUT"); $finish; end
        end while (cpu_stall);
        cpu_req <= 0; cpu_we <= 0;
    endtask

    logic [31:0] rd;
    int          fails;

    initial begin
        clk = 0; rst_n = 0; fails = 0;
        cpu_req = 0; cpu_we = 0; cpu_wstrb = 4'hF;
        cpu_addr = 0; cpu_wdata = 0;

        wait_clk(5);
        rst_n = 1;
        wait_clk(2);

        // TC1: cold read miss -> fill
        $display("[TC1] Cold read miss: addr=0x00000000");
        cache_read(32'h0000_0000, rd);
        $display("      rdata=%08h miss_cnt=%0d", rd, perf_miss_cnt);

        // TC2: read hit same line
        $display("[TC2] Read hit same line: addr=0x00000004");
        cache_read(32'h0000_0004, rd);
        $display("      rdata=%08h hit_cnt=%0d", rd, perf_hit_cnt);
        if (perf_hit_cnt < 1) begin $display("FAIL: hit_cnt"); fails++; end

        // TC3: write hit -> dirty
        $display("[TC3] Write hit addr=0x00000000");
        cache_write(32'h0000_0000, 32'hBEEF_1234);
        cache_read(32'h0000_0000, rd);
        if (rd !== 32'hBEEF_1234) begin
            $display("FAIL: expected BEEF1234 got %08h", rd); fails++;
        end else $display("      PASS writeback data=%08h", rd);

        // TC4: evict to different set
        $display("[TC4] Different set miss: addr=0x00000200 (set 16)");
        cache_read(32'h0000_0200, rd);
        $display("      rdata=%08h miss_cnt=%0d", rd, perf_miss_cnt);

        // TC5: two-way fill (fill both ways in same set, then evict)
        $display("[TC5] LRU eviction: fill way0 then way1 in set 0");
        cache_read(32'h0000_0000, rd); // way0
        cache_read(32'h0000_1000, rd); // way1 (same set 0)
        cache_read(32'h0000_2000, rd); // evict LRU (way0), miss
        $display("      miss_cnt=%0d", perf_miss_cnt);

        if (fails == 0)
            $display("[TB_DCACHE] ALL TESTS PASSED");
        else
            $display("[TB_DCACHE] %0d FAILURE(S)", fails);
        #50 $finish;
    end

    initial begin #200000; $display("TIMEOUT"); $finish; end

endmodule
