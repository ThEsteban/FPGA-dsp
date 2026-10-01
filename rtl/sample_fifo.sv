module sample_fifo (
    input  logic        clk,
    input  logic        reset,

    input  logic        write_en,
    input  logic [15:0] write_data,

    input  logic        read_en,
    output logic [15:0] read_data,

    output logic        empty,
    output logic        full,
    output logic [3:0]  level,
    output logic        overflow
);

    // Eight 16-bit samples.
    logic [15:0] memory [0:7];

    logic [2:0] write_ptr;
    logic [2:0] read_ptr;
    logic [3:0] count;

    logic write_accepted;
    logic read_accepted;

    assign empty = (count == 0);
    assign full  = (count == 8);
    assign level = count;

    // The word currently at the front of the FIFO.
    assign read_data = memory[read_ptr];

    assign read_accepted =
        read_en && !empty;

    // If a read and write happen while full, the departing word
    // makes room for the arriving word.
    assign write_accepted =
        write_en && (!full || read_accepted);

    always_ff @(posedge clk) begin
        if (reset) begin
            write_ptr <= 3'd0;
            read_ptr  <= 3'd0;
            count     <= 4'd0;
            overflow  <= 1'b0;
        end else begin
            if (write_accepted) begin
                memory[write_ptr] <= write_data;
                write_ptr <= write_ptr + 1'b1;
            end

            if (read_accepted) begin
                read_ptr <= read_ptr + 1'b1;
            end

            // Update the number of stored samples.
            case ({write_accepted, read_accepted})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase

            // Sticky overflow flag.
            if (write_en && full && !read_accepted)
                overflow <= 1'b1;
        end
    end

endmodule