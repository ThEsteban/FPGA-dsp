module spi_rx (
    input  logic        clk,
    input  logic        reset,

    input  logic        spi_sck,
    input  logic        spi_mosi,
    input  logic        spi_cs_n,

    output logic [15:0] data_out,
    output logic        data_valid
);

    //two synchronization stages.
    // async_reg tells synthesis/place-and-route tools that these
    // registers form synchronizer chains.
    (* async_reg = "true" *) logic [1:0] sck_sync;
    (* async_reg = "true" *) logic [1:0] cs_sync;
    (* async_reg = "true" *) logic [1:0] mosi_sync;

    logic sck_prev;
    logic cs_prev;

    logic [15:0] shift_reg;
    logic [4:0]  bit_count;

    logic sck_rising;
    logic cs_falling;
    logic cs_rising;

    // Edge detection now uses only synchronized signals.
    assign sck_rising = !sck_prev && sck_sync[1];
    assign cs_falling =  cs_prev && !cs_sync[1];
    assign cs_rising  = !cs_prev &&  cs_sync[1];

    always_ff @(posedge clk) begin
        if (reset) begin
            // SPI mode 0 idle values.
            sck_sync  <= 2'b00;
            cs_sync   <= 2'b11;
            mosi_sync <= 2'b00;
        end else begin
            // The raw pin enters bit 0 first.
            // One clock later it reaches bit 1.
            sck_sync  <= {sck_sync[0],  spi_sck};
            cs_sync   <= {cs_sync[0],   spi_cs_n};
            mosi_sync <= {mosi_sync[0], spi_mosi};
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            sck_prev  <= 1'b0;
            cs_prev   <= 1'b1;

            shift_reg <= 16'b0;
            bit_count <= 5'd0;

            data_out   <= 16'b0;
            data_valid <= 1'b0;
        end else begin
            // Save previous synchronized values for edge detection.
            sck_prev <= sck_sync[1];
            cs_prev  <= cs_sync[1];

            //data_valid is a one-clock pulse.
            data_valid <= 1'b0;

            if (cs_falling) begin
                shift_reg <= 16'b0;
                bit_count <= 5'd0;
            end

            //SPI mode 0: sample MOSI on an SCK rising edge.
            if (!cs_sync[1] && sck_rising) begin
                shift_reg <= {shift_reg[14:0], mosi_sync[1]};

                if (bit_count == 5'd15) begin
                    data_out <= {
                        shift_reg[14:0],
                        mosi_sync[1]
                    };

                    data_valid <= 1'b1;
                    bit_count  <= 5'd0;
                end else begin
                    bit_count <= bit_count + 1'b1;
                end
            end

            if (cs_rising) begin
                bit_count <= 5'd0;
            end
        end
    end

endmodule