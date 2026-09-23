module impulse_tb; 

logic clk; 
logic reset; 
logic signed [11:0] sample_in; 
logic sample_valid; 

logic signed[15:0] sample_out; 
logic output_valid; 

fir_filter dut(
    .clk(clk),
    .reset(reset),
    .sample_in(sample_in),
    .sample_valid(sample_valid),
    .sample_out(sample_out),
    .output_valid(output_valid)
); 

task send_sample(input logic signed[11:0] value); 
begin 
    @(negedge clk);
    sample_in = value; 
    sample_valid = 1; 
    @(negedge clk); 
    sample_valid = 0; 
end
endtask

initial begin
    clk = 0; 
    reset = 1; 
    sample_in = 0; 
    sample_valid = 0; 

    repeat (2) @ (posedge clk); 

    @(negedge clk); 
    reset = 0; 
    repeat(40)begin
        send_sample(12'sd1000); 
    end 
    repeat(5) @ (posedge clk)
    $finish; 
end


always #5 clk = ~clk; 

always @(negedge clk) begin
    #1
    if (output_valid)
        $display("time=%0t sample_out=%0d", $time, sample_out);
end

endmodule