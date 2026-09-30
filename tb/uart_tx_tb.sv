`timescale 1ns/1ps

module uart_tx_tb;

    logic clk = 0;
    logic reset = 1;
    logic [7:0] data_in;
    logic start;
    logic tx;
    logic busy;

    // 27 MHz clock
    always #18.5185 clk = ~clk;

    uart_tx #(
        .CLK_FREQ(27_000_000),
        .BAUD(115_200)
    ) dut (
        .clk(clk),
        .reset(reset),
        .data_in(data_in),
        .start(start),
        .tx(tx),
        .busy(busy)
    );

    initial begin

    $dumpfile("uart_tx.vcd");
    $dumpvars(0, uart_tx_tb);

    data_in = 8'h41;
    start   = 0;

    #100;
    reset = 0;

    @(negedge clk);

    start = 1;

    // Hold start across a complete rising edge
    @(negedge clk);

    start = 0;

    #100000;

    $finish;
end
endmodule