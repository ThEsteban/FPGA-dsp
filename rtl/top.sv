module top (
    input logic clk,
    input logic reset, 
    output logic led
); 

logic reset; 

    blinker #(
        .MAX_COUNT(13_499_999)
    ) my_blinker (
        .clk(clk),
        .reset(reset),
        .led(led)
    );



endmodule