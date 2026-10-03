`default_nettype none

module spi_rx (
    input  logic        clk,
    input  logic        reset,

    input  logic        spi_sck,
    input  logic        spi_mosi,
    input  logic        spi_cs_n,

    output logic [15:0] data_out,
    output logic        data_valid
);

    (* async_reg = "true" *) logic [1:0] sck_sync;
    (* async_reg = "true" *) logic [1:0] cs_sync;
    (* async_reg = "true" *) logic [1:0] mosi_sync;

    logic sck_previous;
    logic [15:0] shift_register;
    logic [4:0] bit_count;

    logic sck_rising;

    assign sck_rising = !sck_previous && sck_sync[1];

    always_ff @(posedge clk) begin
        if (reset) begin
            sck_sync  <= 2'b00;
            cs_sync   <= 2'b11;
            mosi_sync <= 2'b00;
        end else begin
            sck_sync  <= {sck_sync[0], spi_sck};
            cs_sync   <= {cs_sync[0], spi_cs_n};
            mosi_sync <= {mosi_sync[0], spi_mosi};
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            sck_previous   <= 1'b0;
            shift_register <= 16'd0;
            bit_count      <= 5'd0;
            data_out       <= 16'd0;
            data_valid     <= 1'b0;
        end else begin
            sck_previous <= sck_sync[1];
            data_valid   <= 1'b0;

            // Keep the partial-word state reset for the entire time CS is
            // inactive. This gives CS priority over SCK edge processing.
            if (cs_sync[1]) begin
                shift_register <= 16'd0;
                bit_count      <= 5'd0;
            end else if (sck_rising) begin
                shift_register <= {
                    shift_register[14:0],
                    mosi_sync[1]
                };

                if (bit_count == 5'd15) begin
                    data_out <= {
                        shift_register[14:0],
                        mosi_sync[1]
                    };
                    data_valid <= 1'b1;
                    bit_count  <= 5'd0;
                end else begin
                    bit_count <= bit_count + 1'b1;
                end
            end
        end
    end

endmodule

`default_nettype wire
