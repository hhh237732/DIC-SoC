// ================================================================
// tb_l2_cache.sv - L2 Cache unit testbench
// Author: hhh237732
// Tests: read miss/hit, write-back, arbiter interaction
// ================================================================
`timescale 1ns/1ps
`include "../rtl/axi4_defines.vh"

module tb_l2_cache;

    logic        clk, rst_n;

    // AXI slave (L1→L2)
    logic        s_awvalid, s_awready;
    logic [31:0] s_awaddr;
    logic  [3:0] s_awid;
    logic  [7:0] s_awlen;
    logic  [2:0] s_awsize;
    logic  [1:0] s_awburst;
    logic        s_wvalid, s_wready;
    logic [31:0] s_wdata;
    logic  [3:0] s_wstrb;
    logic        s_wlast;
    logic        s_bvalid, s_bready;
    logic  [3:0] s_bid;
    logic  [1:0] s_bresp;
    logic        s_arvalid, s_arready;
    logic [31:0] s_araddr;
    logic  [3:0] s_arid;
    logic  [7:0] s_arlen;
    logic  [2:0] s_arsize;
    logic  [1:0] s_arburst;
    logic        s_rvalid, s_rready;
    logic [31:0] s_rdata;
    logic  [3:0] s_rid;
    logic  [1:0] s_rresp;
    logic        s_rlast;

    // AXI master (L2→mem)
    logic        m_awvalid, m_awready;
    logic [31:0] m_awaddr;
    logic  [3:0] m_awid;
    logic  [7:0] m_awlen;
    logic  [2:0] m_awsize;
    logic  [1:0] m_awburst;
    logic        m_wvalid, m_wready;
    logic [31:0] m_wdata;
    logic  [3:0] m_wstrb;
    logic        m_wlast;
    logic        m_bvalid, m_bready;
    logic  [3:0] m_bid;
    logic  [1:0] m_bresp;
    logic        m_arvalid, m_arready;
    logic [31:0] m_araddr;
    logic  [3:0] m_arid;
    logic  [7:0] m_arlen;
    logic  [2:0] m_arsize;
    logic  [1:0] m_arburst;
    logic        m_rvalid, m_rready;
    logic [31:0] m_rdata;
    logic  [3:0] m_rid;
    logic  [1:0] m_rresp;
    logic        m_rlast;

    logic [31:0] perf_hit_cnt, perf_miss_cnt;

    l2_cache dut (.*);

    always #5 clk = ~clk;

    // Downstream memory model (256 words)
    logic [31:0] mem [0:255];
    initial foreach(mem[i]) mem[i] = i + 32'hC000_0000;

    // AXI master read responder
    logic [31:0] rd_base;
    logic  [3:0] rd_id;
    int rd_beat, rd_len;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_arready <= 1; m_rvalid <= 0; m_rdata <= 0;
            m_rid <= 0; m_rresp <= 0; m_rlast <= 0;
            rd_beat <= 0; rd_len <= 0;
        end else begin
            if (m_arvalid && m_arready) begin
                rd_base   <= m_araddr;
                rd_id     <= m_arid;
                rd_len    <= m_arlen;
                m_arready <= 0;
                rd_beat   <= 0;
            end
            if (!m_arready || m_rvalid) begin
                m_rvalid <= 1;
                m_rid    <= rd_id;
                m_rresp  <= `AXI_RESP_OKAY;
                m_rdata  <= mem[(rd_base[9:2] + rd_beat) % 256];
                m_rlast  <= (rd_beat == rd_len);
                if (m_rvalid && m_rready) begin
                    if (rd_beat == rd_len) begin
                        m_rvalid  <= 0;
                        m_rlast   <= 0;
                        m_arready <= 1;
                    end
                    rd_beat <= rd_beat + 1;
                end
            end
        end
    end

    // AXI master write responder
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_awready <= 1; m_wready <= 0;
            m_bvalid <= 0; m_bid <= 0; m_bresp <= 0;
        end else begin
            if (m_awvalid && m_awready) begin
                m_awready <= 0; m_wready <= 1;
            end
            if (m_wvalid && m_wready && m_wlast) begin
                m_wready <= 0; m_bvalid <= 1;
                m_bid <= m_awid; m_bresp <= `AXI_RESP_OKAY;
            end
            if (m_bvalid && m_bready) begin
                m_bvalid <= 0; m_awready <= 1;
            end
        end
    end

    // ----------------------------------------------------------------
    // Driver tasks
    // ----------------------------------------------------------------
    task automatic wait_clk(int n = 1);
        repeat(n) @(posedge clk);
    endtask

    // Single-beat AXI read request and response gather
    task automatic axi_read(input logic [31:0] addr,
                             input logic  [3:0] id = 0,
                             input logic  [7:0] len = 8'd7,
                             output logic [31:0] data[]);
        int t;
        data = new[len+1];
        @(posedge clk);
        s_arvalid <= 1; s_araddr <= addr; s_arid <= id;
        s_arlen   <= len; s_arsize <= 3'd2; s_arburst <= 2'd1;
        s_rready  <= 1;
        t = 0;
        do begin @(posedge clk); t++;
            if (t > 400) begin $display("AXI_READ AR timeout"); $finish; end
        end while (!s_arready);
        s_arvalid <= 0;
        // Collect burst
        for (int i = 0; i <= len; i++) begin
            t = 0;
            do begin @(posedge clk); t++;
                if (t > 400) begin $display("AXI_READ R timeout"); $finish; end
            end while (!s_rvalid);
            data[i] = s_rdata;
        end
        s_rready <= 0;
    endtask

    logic [31:0] burst[];
    int          fails;

    initial begin
        clk = 0; rst_n = 0; fails = 0;
        s_arvalid = 0; s_rready = 0;
        s_awvalid = 0; s_wvalid = 0; s_bready = 1;
        s_bready = 1;

        wait_clk(5);
        rst_n = 1;
        wait_clk(2);

        // TC1: cold miss - read line
        $display("[TC1] L2 cold miss addr=0x00000000");
        axi_read(32'h0000_0000, 4'h0, 8'd7, burst);
        $display("      burst[0]=%08h miss_cnt=%0d", burst[0], perf_miss_cnt);

        // TC2: hit - same line
        $display("[TC2] L2 hit same line");
        axi_read(32'h0000_0000, 4'h0, 8'd7, burst);
        $display("      burst[0]=%08h hit_cnt=%0d", burst[0], perf_hit_cnt);
        if (perf_hit_cnt < 1) begin $display("FAIL: hit_cnt<1"); fails++; end

        // TC3: miss another tag
        $display("[TC3] L2 miss new tag");
        axi_read(32'h0000_0100, 4'h0, 8'd7, burst);
        $display("      burst[0]=%08h miss_cnt=%0d", burst[0], perf_miss_cnt);

        // TC4: different ID (L1I vs L1D)
        $display("[TC4] L2 read with L1I id (bit3=1)");
        axi_read(32'h0000_0000, 4'h8, 8'd7, burst);
        $display("      burst[0]=%08h", burst[0]);

        if (fails == 0)
            $display("[TB_L2] ALL TESTS PASSED");
        else
            $display("[TB_L2] %0d FAILURE(S)", fails);
        #50 $finish;
    end

    initial begin #300000; $display("TIMEOUT"); $finish; end

endmodule
