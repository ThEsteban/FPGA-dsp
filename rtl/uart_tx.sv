module uart_tx #(
    parameter CLK_FREQ = 27_000_000,
    parameter BAUD     = 115_200
)(
    input  logic       clk,
    input  logic       reset,

    input  logic [7:0] data_in,
    input  logic       start,

    output logic       tx,
    output logic       busy
);

localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD;

logic [15:0] clk_count;
logic [3:0]  bit_index;
logic [9:0]  frame;


always_ff @(posedge clk) begin

    if (reset) begin

        tx        <= 1'b1;
        busy      <= 1'b0;

        clk_count <= 0;
        bit_index <= 0;

        frame <= 10'b1111111111;

    end else begin

        // Begin a new UART transmission
        if (start && !busy) begin

            frame <= {
                1'b1,       // stop bit
                data_in,    // 8 data bits
                1'b0        // start bit
            };

            busy      <= 1'b1;
            clk_count <= 0;
            bit_index <= 0;

            // Immediately place start bit on wire
            tx <= 1'b0;

        end

        else if (busy) begin
            if (clk_count == CLKS_PER_BIT - 1) begin

                clk_count <= 0;

                // Finished stop bit
                if (bit_index == 9) begin

                    busy <= 1'b0; 
                    tx   <= 1'b1; // on same clock end send

                end else begin

                    bit_index <= bit_index + 1;
                    tx <= frame[bit_index + 1]; // not reading start/end

                end

            end else begin

                clk_count <= clk_count + 1;

            end
        end
    end
end

endmodule