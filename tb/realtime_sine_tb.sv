`timescale 1ns/1ps

module realtime_sine_tb;

    logic clk;
    logic reset;

    logic signed [11:0] sample_in;
    logic sample_valid;

    logic signed [15:0] sample_out;
    logic output_valid;

    integer n;
    integer sample_value;

    real PI = 3.14159265358979323846;

    // 27 MHz / 8 kHz = 3375 FPGA clocks per ADC sample
    localparam integer CLOCKS_PER_SAMPLE = 3375;

    fir_filter dut (
        .clk(clk),
        .reset(reset),
        .sample_in(sample_in),
        .sample_valid(sample_valid),
        .sample_out(sample_out),
        .output_valid(output_valid)
    );



    // 27 MHz FPGA clock
    //
    // period = 1 / 27 MHz = 37.037 ns
    // half period = 18.5185 ns

    initial begin
        clk = 1'b0;
    end

    always #18.5185 clk = ~clk;

    task send_adc_sample(
        input logic signed [11:0] value
    );
    begin

        // Change inputs away from positive clock edge
        @(negedge clk);

        sample_in    = value;
        sample_valid = 1'b1;

        // FIR accepts sample here
        @(posedge clk);

        @(negedge clk);
        sample_valid = 1'b0;

        repeat (CLOCKS_PER_SAMPLE - 1)
            @(posedge clk);

    end
    endtask


  
    initial begin

        reset        = 1'b1;
        sample_in    = 12'sd0;
        sample_valid = 1'b0;

        repeat (5) @(posedge clk);

        @(negedge clk);
        reset = 1'b0;



        for (n = 0; n < 256; n = n + 1) begin

            sample_value = $rtoi(
                  600.0 * $sin(
                      2.0 * PI * 250.0 * n / 8000.0
                  )
                + 600.0 * $sin(
                      2.0 * PI * 2500.0 * n / 8000.0
                  )
            );

            send_adc_sample(sample_value);

        end


        repeat (100) @(posedge clk);

        $finish;

    end



    always @(posedge clk) begin
        if (sample_valid) begin
            $display(
                "ADC  time=%0t  input=%0d",
                $time,
                sample_in
            );
        end
    end


  
    always @(posedge clk) begin
        if (output_valid) begin
            $display(
                "FIR  time=%0t  output=%0d",
                $time,
                sample_out
            );
        end
    end




    initial begin
        $dumpfile("build/realtime_sine_tb.vcd");
        $dumpvars(0, realtime_sine_tb);
    end

endmodule