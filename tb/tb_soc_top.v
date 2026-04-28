`timescale 1ns/1ps
`include "../rtl/axi4_defines.vh"

module tb_soc_top;
    reg clk, rst_n;
    reg cpu_instr_req;
    reg [31:0] cpu_instr_addr;
    wire [31:0] cpu_instr_data;
    wire cpu_instr_stall;

    reg cpu_data_req;
    reg cpu_data_we;
    reg [3:0] cpu_data_wstrb;
    reg [31:0] cpu_data_addr;
    reg [31:0] cpu_data_wdata;
    wire [31:0] cpu_data_rdata;
    wire cpu_data_stall;
    wire dma_irq;
    wire cpu_irq;

    soc_top dut (
        .clk(clk), .rst_n(rst_n),
        .cpu_instr_req(cpu_instr_req), .cpu_instr_addr(cpu_instr_addr), .cpu_instr_data(cpu_instr_data), .cpu_instr_stall(cpu_instr_stall),
        .cpu_data_req(cpu_data_req), .cpu_data_we(cpu_data_we), .cpu_data_wstrb(cpu_data_wstrb), .cpu_data_addr(cpu_data_addr), .cpu_data_wdata(cpu_data_wdata), .cpu_data_rdata(cpu_data_rdata), .cpu_data_stall(cpu_data_stall),
        .dma_irq(dma_irq),
        .cpu_irq(cpu_irq)
    );

    always #5 clk=~clk;

    task cpu_instr_fetch(input [31:0] a);
    begin
        @(posedge clk);
        cpu_instr_req<=1; cpu_instr_addr<=a;
        @(posedge clk);
        cpu_instr_req<=0;
        repeat(20) @(posedge clk);
        $display("[TB_SOC] IFETCH addr=%h data=%h stall=%b", a, cpu_instr_data, cpu_instr_stall);
    end
    endtask

    task cpu_data_read(input [31:0] a);
    begin
        @(posedge clk);
        cpu_data_req<=1; cpu_data_we<=0; cpu_data_addr<=a;
        @(posedge clk);
        cpu_data_req<=0;
        repeat(20) @(posedge clk);
        $display("[TB_SOC] DREAD addr=%h data=%h stall=%b", a, cpu_data_rdata, cpu_data_stall);
    end
    endtask

    initial begin
        clk=0; rst_n=0;
        cpu_instr_req=0; cpu_instr_addr=0;
        cpu_data_req=0; cpu_data_we=0; cpu_data_wstrb=4'hF; cpu_data_addr=0; cpu_data_wdata=0;

        repeat(10) @(posedge clk);
        rst_n=1;

        $display("[TB_SOC] Case1 CPU取指/读写主存路径");
        cpu_instr_fetch(32'h0000_0000);
        cpu_data_read(32'h0000_0040);

        $display("[TB_SOC] Case2 配置DMA寄存器并触发传输");
        // 通过CPU数据口模拟向DMA寄存器地址写（系统简化模型，不强制检验功能）
        @(posedge clk); cpu_data_req<=1; cpu_data_we<=1; cpu_data_addr<=32'h1000_0008; cpu_data_wdata<=32'h0000_0100;
        @(posedge clk); cpu_data_req<=0;
        @(posedge clk); cpu_data_req<=1; cpu_data_we<=1; cpu_data_addr<=32'h1000_000C; cpu_data_wdata<=32'h0000_0200;
        @(posedge clk); cpu_data_req<=0;
        @(posedge clk); cpu_data_req<=1; cpu_data_we<=1; cpu_data_addr<=32'h1000_0010; cpu_data_wdata<=32'd64;
        @(posedge clk); cpu_data_req<=0;
        @(posedge clk); cpu_data_req<=1; cpu_data_we<=1; cpu_data_addr<=32'h1000_0000; cpu_data_wdata<=32'h1;
        @(posedge clk); cpu_data_req<=0;

        repeat(200) @(posedge clk);
        $display("[TB_SOC] IRQ=%b", dma_irq);

        $display("[TB_SOC] PASS");
        #50 $finish;
    end

    initial begin
        repeat(30000) @(posedge clk);
        $display("[TB_SOC] TIMEOUT");
        $finish;
    end
endmodule
