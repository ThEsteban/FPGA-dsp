`timescale 1ns/1ps

module blinker_tb;
    logic clk;
    logic reset; 
    logic led; 
    blinker #( .MAX_COUNT(4) )my_blinker( // set parameter to make testing simpler, make led turn on/off every 4 clock cycles. 
        .clk(clk), 
        .reset(reset), 
        .led(led)
    ); 

initial begin
    clk = 0; 
    forever  begin
        #5 clk = ~clk; //determine edge length, depends on 'timescale
    end
end

initial begin
    $dumpfile("build/blinker.vcd"); 
    $dumpvars(0, blinker_tb); 

    reset = 1; 
    #20; //wait 20 ns
    reset = 0; //blinker starts counting after 20ns
    #150; //blinker starts count until 170ns
    $finish; 
end 

endmodule 

