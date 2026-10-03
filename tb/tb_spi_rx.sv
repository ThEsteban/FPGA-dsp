`timescale 1ns/1ps
`default_nettype none

module tb_spi_rx;

    logic clk = 1'b0;
    logic reset = 1'b1;

    logic spi_sck = 1'b0;
    logic spi_mosi = 1'b0;
    logic spi_cs_n = 1'b1;

    logic [15:0] data_out;
    logic data_valid;

    integer received_count = 0;
    integer error_count = 0;

    logic [15:0] last_received_word;

localparam logic [15:0] TEST_WORD = 16'hA801;

    // Approximately 27 MHz.
    always #18.518 clk = ~clk;

    spi_rx dut (
        .clk(clk),
        .reset(reset),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_cs_n(spi_cs_n),
        .data_out(data_out),
        .data_valid(data_valid)
    );

    always @(posedge clk) begin
        if (data_valid) begin
            received_count = received_count + 1;
            last_received_word = data_out;

            if (data_out !== 16'hA801) begin
                error_count = error_count + 1;

                $display(
                    "ERROR time=%0t received=0x%04h expected=0xA801",
                    $time,
                    data_out
                );
            end
        end
    end

    task automatic send_and_check(
        input integer phase_delay_ns,
        input integer half_period_ns
    );
        integer bit_index;
        integer count_before;
        begin
            count_before = received_count;

            // Start each packet at a different position relative to clk.
            @(posedge clk);
            #(phase_delay_ns);

            spi_cs_n = 1'b0;

            // CS setup time.
            #2000;

            // SPI mode 0, MSB first.
            for (bit_index = 15; bit_index >= 0; bit_index = bit_index - 1) begin
                spi_mosi = TEST_WORD[bit_index]; 

                #(half_period_ns);
                spi_sck = 1'b1;

                #(half_period_ns);
                spi_sck = 1'b0;
            end

            // CS hold time.
            #2000;
            spi_cs_n = 1'b1;
            spi_mosi = 1'b0;

            repeat (10) @(posedge clk);

            if (received_count != count_before + 1) begin
                error_count = error_count + 1;

                $display(
                    "ERROR phase=%0d ns: expected one word, received %0d",
                    phase_delay_ns,
                    received_count - count_before
                );
            end else if (last_received_word !== 16'hA801) begin
                $display(
                    "ERROR phase=%0d ns: received 0x%04h",
                    phase_delay_ns,
                    last_received_word
                );
            end
        end
    endtask

    integer phase;

    initial begin
        $dumpfile("build/tb_spi_rx.vcd");
        $dumpvars(0, tb_spi_rx);

        repeat (10) @(posedge clk);
        reset = 1'b0;
        repeat (10) @(posedge clk);

        $display("Testing 500 kHz SPI");

        // One 27 MHz period is approximately 37 ns.
        // Sweep every possible whole-nanosecond phase relationship.
        for (phase = 0; phase <= 37; phase = phase + 1) begin
            send_and_check(phase, 1000);
        end

        $display("Testing 1 MHz SPI");

        for (phase = 0; phase <= 37; phase = phase + 1) begin
            send_and_check(phase, 500);
        end

        $display(
            "Finished: received=%0d errors=%0d",
            received_count,
            error_count
        );

        if (error_count == 0)
            $display("PASS: all clean SPI packets were received correctly");
        else
            $display("FAIL: SPI receiver has digital timing/boundary errors");

        $finish;
    end

endmodule

`default_nettype wire