// ================================================================
// Module: plic_lite
// Author: hhh237732
// Purpose: Minimal interrupt aggregator (Platform-Level Interrupt
//          Controller lite).  Up to 8 sources, per-source enable,
//          level-triggered OR aggregation to cpu_irq.
// ================================================================
module plic_lite (
    input        clk,
    input        rst_n,
    input  [7:0] irq_in,   // raw interrupt sources (active-high)
    input  [7:0] irq_en,   // per-source enable mask
    output       cpu_irq   // aggregated interrupt to CPU
);

    reg [7:0] irq_masked;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            irq_masked <= 8'd0;
        else
            irq_masked <= irq_in & irq_en;
    end

    assign cpu_irq = |irq_masked;

endmodule
