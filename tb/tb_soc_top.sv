// ================================================================
// tb_soc_top.sv - Comprehensive SoC end-to-end testbench
// Author: hhh237732
// Tests: ICache miss fill, DCache read/write, DMA transfer, MMIO
// ================================================================
`timescale 1ns/1ps
`include "../rtl/axi4_defines.vh"

module tb_soc_top;
    // DUT ports
    logic        clk, rst_n;
    logic        cpu_instr_req;
    logic [31:0] cpu_instr_addr;
    logic [31:0] cpu_instr_data;
    logic        cpu_instr_stall;
    logic        cpu_data_req;
    logic        cpu_data_we;
    logic  [3:0] cpu_data_wstrb;
    logic [31:0] cpu_data_addr;
    logic [31:0] cpu_data_wdata;
    logic [31:0] cpu_data_rdata;
    logic        cpu_data_stall;
    logic        dma_irq;
    logic        cpu_irq;

    soc_top dut (.*);

    always #5 clk = ~clk;

    // ----------------------------------------------------------------
    // Tasks
    // ----------------------------------------------------------------
    task automatic wait_clk(int n = 1);
        repeat(n) @(posedge clk);
    endtask

    // Instruction fetch with stall handling (max 200 cycles)
    task automatic ifetch(input logic [31:0] addr, output logic [31:0] data);
        int timeout;
        @(posedge clk);
        cpu_instr_req  <= 1'b1;
        cpu_instr_addr <= addr;
        timeout = 0;
        do begin
            @(posedge clk);
            timeout++;
            if (timeout > 200) begin
                $display("[TB] ERROR: ICache stall timeout addr=%08h", addr);
                $finish;
            end
        end while (cpu_instr_stall);
        data = cpu_instr_data;
        cpu_instr_req <= 1'b0;
    endtask

    // Data read with stall handling
    task automatic dread(input logic [31:0] addr, output logic [31:0] data);
        int timeout;
        @(posedge clk);
        cpu_data_req   <= 1'b1;
        cpu_data_we    <= 1'b0;
        cpu_data_wstrb <= 4'hF;
        cpu_data_addr  <= addr;
        timeout = 0;
        do begin
            @(posedge clk);
            timeout++;
            if (timeout > 200) begin
                $display("[TB] ERROR: DCache read stall timeout addr=%08h", addr);
                $finish;
            end
        end while (cpu_data_stall);
        data = cpu_data_rdata;
        cpu_data_req <= 1'b0;
    endtask

    // Data write with stall handling
    task automatic dwrite(input logic [31:0] addr, input logic [31:0] wdata,
                          input logic [3:0] strb = 4'hF);
        int timeout;
        @(posedge clk);
        cpu_data_req   <= 1'b1;
        cpu_data_we    <= 1'b1;
        cpu_data_wstrb <= strb;
        cpu_data_addr  <= addr;
        cpu_data_wdata <= wdata;
        timeout = 0;
        do begin
            @(posedge clk);
            timeout++;
            if (timeout > 200) begin
                $display("[TB] ERROR: DCache write stall timeout addr=%08h", addr);
                $finish;
            end
        end while (cpu_data_stall);
        cpu_data_req <= 1'b0;
        cpu_data_we  <= 1'b0;
    endtask

    // ----------------------------------------------------------------
    // Test sequence
    // ----------------------------------------------------------------
    logic [31:0] rdata;
    int          fail_cnt;

    initial begin
        clk  = 0; rst_n = 0;
        fail_cnt = 0;
        cpu_instr_req = 0; cpu_instr_addr = 0;
        cpu_data_req  = 0; cpu_data_we   = 0;
        cpu_data_wstrb = 4'hF;
        cpu_data_addr  = 0; cpu_data_wdata = 0;

        wait_clk(10);
        rst_n = 1;
        wait_clk(5);

        // ---- TC1: ICache cold miss + fill ----
        $display("[TC1] ICache cold miss at 0x0000_0000");
        ifetch(32'h0000_0000, rdata);
        $display("      instr_data = %08h (L1I miss->L2->mem)", rdata);

        // ---- TC2: ICache second access (should hit) ----
        $display("[TC2] ICache hit (same cache line)");
        ifetch(32'h0000_0004, rdata);
        $display("      instr_data = %08h", rdata);

        // ---- TC3: DCache write-allocate ----
        $display("[TC3] DCache write miss -> fill -> write");
        dwrite(32'h0000_0100, 32'hDEAD_BEEF);

        // ---- TC4: DCache read-hit (after fill) ----
        $display("[TC4] DCache read hit (same line)");
        dread(32'h0000_0100, rdata);
        if (rdata !== 32'hDEAD_BEEF) begin
            $display("      FAIL: got %08h expected DEADBEEF", rdata);
            fail_cnt++;
        end else $display("      PASS: %08h", rdata);

        // ---- TC5: MMIO ID register read ----
        $display("[TC5] MMIO ID read at 0x2000_0000");
        dread(32'h2000_0000, rdata);
        if (rdata !== 32'h444D4153) begin
            $display("      FAIL: got %08h expected 444D4153 (DMAS)", rdata);
            fail_cnt++;
        end else $display("      PASS: ID=%08h", rdata);

        // ---- TC6: MMIO SCRATCH read-write ----
        $display("[TC6] MMIO SCRATCH register at 0x2000_0008");
        dwrite(32'h2000_0008, 32'hCAFE_BABE);
        dread(32'h2000_0008, rdata);
        if (rdata !== 32'hCAFE_BABE) begin
            $display("      FAIL: got %08h expected CAFEBABE", rdata);
            fail_cnt++;
        end else $display("      PASS: scratch=%08h", rdata);

        // ---- TC7: DMA transfer ----
        $display("[TC7] DMA: src=0x100 dst=0x200 len=64");
        dwrite(32'h1000_0008, 32'h0000_0100); // SRC
        dwrite(32'h1000_000C, 32'h0000_0200); // DST
        dwrite(32'h1000_0010, 32'd16);        // LEN (16 words)
        dwrite(32'h1000_0014, 32'h3);         // INT_EN
        dwrite(32'h1000_0000, 32'h1);         // START
        wait_clk(500);
        $display("      DMA IRQ=%b CPU_IRQ=%b", dma_irq, cpu_irq);

        // ---- TC8: ICache + DCache simultaneous miss ----
        $display("[TC8] ICache miss at new line while DCache active");
        ifetch(32'h0000_0040, rdata);
        $display("      instr_data = %08h", rdata);

        // ---- TC9: MMIO perf counter read ----
        $display("[TC9] MMIO perf counters");
        dread(32'h2000_0010, rdata);
        $display("      L1I hit_cnt  = %0d", rdata);
        dread(32'h2000_0014, rdata);
        $display("      L1I miss_cnt = %0d", rdata);
        dread(32'h2000_0018, rdata);
        $display("      L1D hit_cnt  = %0d", rdata);
        dread(32'h2000_001C, rdata);
        $display("      L1D miss_cnt = %0d", rdata);
        dread(32'h2000_0020, rdata);
        $display("      L2  hit_cnt  = %0d", rdata);
        dread(32'h2000_0024, rdata);
        $display("      L2  miss_cnt = %0d", rdata);

        // ---- Summary ----
        if (fail_cnt == 0)
            $display("[TB] ALL TESTS PASSED");
        else
            $display("[TB] %0d TEST(S) FAILED", fail_cnt);

        #50 $finish;
    end

    // Timeout watchdog
    initial begin
        #500000;
        $display("[TB] TIMEOUT");
        $finish;
    end

endmodule
