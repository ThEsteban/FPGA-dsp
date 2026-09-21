
module blinker #(
    parameter integer MAX_COUNT = 13_499_499
) ( // like macro in c
    input logic clk, 
    input logic reset, 
    output logic led
); 

logic [23:0] count; 

always_ff @( posedge clk ) begin : counter
    if(reset) begin
        count <= 0; 
        led <= 1; //nano 20k is active low for leds, see schematic
    end
    else if(count == MAX_COUNT) begin
        count <= 0; 
        led <= ~led; 
    end 
    else begin
        count <= count + 1;
    end
end

endmodule 


