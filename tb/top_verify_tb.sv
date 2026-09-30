`timescale 1ns/1ps

module top_verify_tb;

    logic clk;
    logic reset;

    logic spi_sck;
    logic spi_mosi;
    logic spi_cs_n;

    logic uart_tx_pin;

    // 27 MHz FPGA clock
    initial clk = 0;
    always #18.5185 clk = ~clk;

    top_verify dut (
        .clk(clk),
        .reset(reset),

        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_cs_n(spi_cs_n),

        .uart_tx_pin(uart_tx_pin)
    );

    // Send one SPI bit, Mode 0
    task send_spi_bit(input logic bit_value);
        begin
            // Data changes while SCK is low
            spi_mosi = bit_value;

            #500;          // half-period for 1 MHz SPI
            spi_sck = 1;   // receiver samples here

            #500;
            spi_sck = 0;
        end
    endtask

    // Send 16-bit word MSB first
    task send_spi_word(input logic [15:0] word);
        integer i;
        begin
            spi_cs_n = 0;

            for (i = 15; i >= 0; i = i - 1) begin
                send_spi_bit(word[i]);
            end

            #500;
            spi_cs_n = 1;
        end
    endtask

    initial begin
        $dumpfile("spi_tb.vcd");
        $dumpvars(0, top_verify_tb);

        reset    = 1;
        spi_sck  = 0;
        spi_mosi = 0;
        spi_cs_n = 1;

        // Reset for a few FPGA clocks
        #200;
        reset = 0;

        #1000;

        // Send known test word
        send_spi_word(16'h1234);

        // Wait long enough for UART to send both bytes
        #250000;

        $finish;
    end

endmodule