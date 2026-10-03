`default_nettype none 

module top_uart_test (
    input  logic clk,
    output logic uart_tx_pin,
    output logic uart_probe_pin,
    output logic heartbeat_pin
);

    localparam integer CLOCK_FREQUENCY = 27_000_000;
    localparam integer SAMPLE_RATE     = 8_000;
    localparam integer CLOCKS_PER_SAMPLE =
        CLOCK_FREQUENCY / SAMPLE_RATE;

    logic [7:0] power_on_count = 8'd0;
    logic [23:0] heartbeat_counter = 24'd0;
    logic system_reset;

    logic [11:0] sample_counter;
    logic sample_tick;

    logic [7:0] uart_data;
    logic uart_start;
    logic uart_busy;

    typedef enum logic [2:0] {
        WAIT_SAMPLE,
        START_HIGH,
        WAIT_HIGH_BUSY,
        WAIT_HIGH_DONE,
        START_LOW,
        WAIT_LOW_BUSY,
        WAIT_LOW_DONE
    } state_t;

    state_t state;

    always_ff @(posedge clk) begin
        if (power_on_count != 8'd255)
            power_on_count <= power_on_count + 1'b1;
    end

    assign system_reset = (power_on_count != 8'd255);

    // Header-accessible diagnostics for the oscilloscope.
    assign uart_probe_pin = uart_tx_pin;
    assign heartbeat_pin  = heartbeat_counter[23];

    always_ff @(posedge clk) begin
        heartbeat_counter <= heartbeat_counter + 1'b1;
    end

    // 27 MHz / 3375 = exactly 8 kHz.
    always_ff @(posedge clk) begin
        if (system_reset) begin
            sample_counter <= 12'd0;
        end else if (sample_counter == CLOCKS_PER_SAMPLE - 1) begin
            sample_counter <= 12'd0;
        end else begin
            sample_counter <= sample_counter + 1'b1;
        end
    end

    assign sample_tick =
        (sample_counter == CLOCKS_PER_SAMPLE - 1);

    uart_tx #(
        .CLK_FREQ(27_000_000),
        .BAUD(230_400)
    ) uart_sender (
        .clk(clk),
        .reset(system_reset),
        .data_in(uart_data),
        .start(uart_start),
        .tx(uart_tx_pin),
        .busy(uart_busy)
    );

    // Send 0xA8 followed by 0x01 once every 125 microseconds.
    always_ff @(posedge clk) begin
        if (system_reset) begin
            state      <= WAIT_SAMPLE;
            uart_data  <= 8'd0;
            uart_start <= 1'b0;
        end else begin
            uart_start <= 1'b0;

            case (state)
                WAIT_SAMPLE: begin
                    if (sample_tick)
                        state <= START_HIGH;
                end

                START_HIGH: begin
                    if (!uart_busy) begin
                        uart_data  <= 8'hA8;
                        uart_start <= 1'b1;
                        state      <= WAIT_HIGH_BUSY;
                    end
                end

                WAIT_HIGH_BUSY: begin
                    if (uart_busy)
                        state <= WAIT_HIGH_DONE;
                end

                WAIT_HIGH_DONE: begin
                    if (!uart_busy)
                        state <= START_LOW;
                end

                START_LOW: begin
                    if (!uart_busy) begin
                        uart_data  <= 8'h01;
                        uart_start <= 1'b1;
                        state      <= WAIT_LOW_BUSY;
                    end
                end

                WAIT_LOW_BUSY: begin
                    if (uart_busy)
                        state <= WAIT_LOW_DONE;
                end

                WAIT_LOW_DONE: begin
                    if (!uart_busy)
                        state <= WAIT_SAMPLE;
                end

                default: begin
                    state <= WAIT_SAMPLE;
                end
            endcase
        end
    end

endmodule
