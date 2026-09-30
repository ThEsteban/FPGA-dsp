module top (
    input  logic clk,
    output logic led0, 
    output logic led1,
    output logic led2
);

logic reset;
logic debug_mac_positive;
logic debug_mac_near_expected;

    logic signed [11:0] sample_in;
    logic sample_valid;

    logic signed [15:0] sample_out;
    logic output_valid;

    logic [11:0] sample_counter;

    // Temporary power-on reset
    logic [7:0] reset_counter = 0;

    always_ff @(posedge clk) begin
        if (!(&reset_counter))
            reset_counter <= reset_counter + 1'b1;
    end

    assign reset = !(&reset_counter);


    // 27 MHz / 3375 = 8 kHz
    always_ff @(posedge clk) begin
        if (reset) begin
            sample_counter <= 0;
            sample_valid   <= 0;
            sample_in      <= 0;
        end
        else begin
            sample_valid <= 0;

            if (sample_counter == 3374) begin
                sample_counter <= 0;

                sample_in    <= 12'sd1000;
                sample_valid <= 1'b1;
            end
            else begin
                sample_counter <= sample_counter + 1'b1;
            end
        end
    end


    fir_filter fir (
        .clk(clk),
        .reset(reset),
        .sample_in(sample_in),
        .sample_valid(sample_valid),
        .sample_out(sample_out),
        .output_valid(output_valid)
    );

/*
logic saw_sample15;
logic saw_sample7; 
logic saw_sample0; 

always_ff @(posedge clk) begin
    if (reset) begin
        saw_sample15 <= 1'b0;
        saw_sample7  <= 1'b0;
        saw_sample0 <= 1'b0; 
    end
    else begin
        if (debug_sample15)
            saw_sample15 <= 1'b1;

        if (debug_sample7)
            saw_sample7 <= 1'b1;
        
        if(debug_sample0)
            saw_sample0 <= 1'b1; 
    end
end

assign led0 = ~saw_sample15; 
assign led1 = ~saw_sample7; 
assign led2 = ~saw_sample0; 

*/

always_ff @(posedge clk) begin
        if (reset)begin
            led0 <= 1'b1;
            led1 <= 1'b1; 
            led2 <= 1'b1; 
        end
        else if (output_valid) begin
            if ((sample_out > 16'sd900) &&
                (sample_out < 16'sd1100))
                led0<= 1'b0;
            else
                led0 <= 1'b1;
        end
    end



endmodule