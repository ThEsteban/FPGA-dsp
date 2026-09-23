module top (
    input  logic clk,
    output logic led
);

    logic reset;

    logic signed [11:0] sample_in;
    logic sample_valid;

    logic signed [15:0] sample_out;
    logic output_valid;

    logic [11:0] sample_counter;

    // Temporary power-on reset
    logic [7:0] reset_counter = 0;

    always_ff @(posedge clk) begin
        if (!&reset_counter)
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


    // Light LED when FIR has reached expected DC output.
    always_ff @(posedge clk) begin
        if (reset)
            led <= 1'b1;
        else if (output_valid) begin
            if ((sample_out > 16'sd900) &&
                (sample_out < 16'sd1100))
                led <= 1'b0;
            else
                led <= 1'b1;
        end
    end

endmodule