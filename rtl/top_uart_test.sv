module top_uart_test (
    input  logic clk,
    output logic uart_tx_pin
);

    logic [7:0] power_on_count = 8'd0;
    logic       system_reset;

    logic [18:0] delay_count;
    logic        uart_start;
    logic        uart_busy;

    always_ff @(posedge clk) begin
        if (power_on_count != 8'd255)
            power_on_count <= power_on_count + 1'b1;
    end

    assign system_reset =
        (power_on_count != 8'd255);

    uart_tx #(
        .CLK_FREQ (27_000_000),
        .BAUD     (460_800)
    ) uart_sender (
        .clk     (clk),
        .reset   (system_reset),
        .data_in (8'h55),
        .start   (uart_start),
        .tx      (uart_tx_pin),
        .busy    (uart_busy)
    );

    // Transmit 0x55 approximately every 10 ms.
    always_ff @(posedge clk) begin
        if (system_reset) begin
            delay_count <= 19'd0;
            uart_start  <= 1'b0;
        end else begin
            uart_start <= 1'b0;

            if (delay_count == 19'd269_999) begin
                delay_count <= 19'd0;

                if (!uart_busy)
                    uart_start <= 1'b1;
            end else begin
                delay_count <= delay_count + 1'b1;
            end
        end
    end

endmodule