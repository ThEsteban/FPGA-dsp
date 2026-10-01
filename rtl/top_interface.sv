module top_interface(
    input logic clk,
    input logic reset_button,

    input logic spi_sclk,
    input logic spi_cs_n,
    input logic spi_mosi,

    output logic uart_tx_pin
);

logic [15:0] spi_data; 
logic spi_data_valid;  


logic        fifo_write;
logic        fifo_read;
logic [15:0] fifo_read_data;
logic        fifo_empty;
logic        fifo_full;
logic [3:0]  fifo_level;
logic        fifo_overflow;

logic [15:0] current_word; 

logic [11:0] adc_sample; 

logic [7:0] uart_data; 
logic uart_start; 
logic uart_busy; 

//power on reset
logic [7:0] power_on_count = 8'd0;
logic [1:0] reset_button_sync = 2'b00;
logic       system_reset;

always_ff @(posedge clk) begin
        // Synchronize the asynchronous button input.
    reset_button_sync <= {reset_button_sync[0], reset_button
        };

        // Hold reset for the first 256 clock cycles.
        if (!(&power_on_count))
            power_on_count <= power_on_count + 1'b1;
    end

assign system_reset = !(&power_on_count) || reset_button_sync[1];


//uart state machine 
typedef enum logic[2:0] {
    IDLE,
    START_HIGH, //send upper bye 
    WAIT_HIGH_BUSY,
    WAIT_HIGH_DONE,
    START_LOW, // lower
    WAIT_LOW_BUSY,
    WAIT_LOW_DONE
} state_t; 

state_t state; 

spi_rx spi_reciever (
    .clk(clk),
    .reset(system_reset),
    .spi_cs_n(spi_cs_n),
    .spi_sck(spi_sclk),
    .spi_mosi(spi_mosi),
    .data_out(spi_data),
    .data_valid(spi_data_valid)
); 

assign fifo_write = spi_data_valid ; //checking if there's just an issue with datavalid pulses 
assign fifo_read = (state == IDLE) && !fifo_empty; 

sample_fifo adc_fifo (
    .clk        (clk),
    .reset      (system_reset),

    .write_en   (fifo_write),
    .write_data (spi_data),

    .read_en    (fifo_read),
    .read_data  (fifo_read_data),

    .empty      (fifo_empty),
    .full       (fifo_full),
    .level      (fifo_level),
    .overflow   (fifo_overflow)
);

uart_tx #(
    .CLK_FREQ(27_000_000),
    .BAUD(230_400)
) uart_sender(
    .clk(clk),
    .reset(system_reset),
    .data_in(uart_data),
    .start(uart_start),
    .tx(uart_tx_pin),
    .busy(uart_busy)
);


always_ff @(posedge clk) begin
    if(system_reset)begin
        adc_sample <= 12'b0;
    end
    else if (spi_data_valid && spi_data[15:12] == 4'hA) begin // check for that code
        adc_sample <= spi_data[11:0]; 
    end
end

//uart transmission logic 
always_ff @(posedge clk) begin
    if(system_reset)begin
        state          <= IDLE;
        current_word <= 16'b0;
        uart_data      <= 8'b0;
        uart_start     <= 1'b0;
    end
    
    else begin
        uart_start <= 1'b0; //one clock pulse start 

    case(state)
    
        IDLE: begin
            if(!fifo_empty) begin
                current_word <= fifo_read_data; 
                state <= START_HIGH; 
            end
        end

        START_HIGH: begin
            if(!uart_busy)begin // send upper byte 
                uart_data <= current_word[15:8]; 
                uart_start <= 1'b1; 
                state <= WAIT_HIGH_BUSY; 
            end
        end
        
        //confirm that uart module accepted the start pulse
        WAIT_HIGH_BUSY: begin
            if(uart_busy) begin
                state <= WAIT_HIGH_DONE; 
            end
        end

        WAIT_HIGH_DONE: begin
            if(!uart_busy) begin 
                state <= START_LOW;
            end
        end

        START_LOW: begin
            if(!uart_busy) begin
                uart_data <= current_word[7:0]; 
                uart_start <= 1'b1;
                state <= WAIT_LOW_BUSY;
            end
        end
        
        WAIT_LOW_BUSY: begin
            if(uart_busy) begin
                state <= WAIT_LOW_DONE; 
            end
        end
        WAIT_LOW_DONE: begin
            if(!uart_busy)begin
                state <= IDLE; 
            end
        end

        default: begin
            state<= IDLE; 
        end
    endcase
    end
end



endmodule
