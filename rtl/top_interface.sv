module top_interface(
    input logic clk,
    input logic reset,

    input logic spi_sclk,
    input logic spi_cs_n,
    input logic spi_mosi,

    output logic uart_tx_pin
);

logic [15:0] spi_data; 
logic spi_data_valid;  

spi_rx spi_reciever (
    .clk(clk),
    .reset(reset),
    .spi_cs_n(spi_cs_n),
    .spi_sck(spi_sclk),
    .spi_mosi(spi_mosi),
    .data_out(spi_data),
    .data_valid(spi_data_valid)
); 

logic [11:0] adc_sample; 

always_ff @(posedge clk) begin
    if(reset)begin
        adc_sample <= 12'b0;
    end
    else if (spi_data_valid && spi_data[15:12] == 4'hA) begin
        adc_sample <= spi_data[11:0]; 
    end
end


logic [7:0] uart_data; 
logic uart_start; 
logic uart_busy; 

logic overrun; //probably bufferable, set up tomorrow

always_ff @(posedge clk) begin
    if(reset)begin
        overrun <= 1'b0; 
    end
    else if(uart_busy && sample_data_valid)begin
        overrun <= 1'b1; 
    end
end



uart_tx #(
    .CLK_FREQ(27_000_000),
    .BAUD(460_800)
) uart_sender(
    .clk(clk),
    .reset(reset),
    .data_in(uart_data),
    .start(uart_start),
    .tx(uart_tx_pin),
    .busy(uart_busy)
);

//uart state machine

typedef enum logic[2:0] {
    IDLE,
    SEND_HIGH, //send upper bye 
    WAIT_HIGH,
    SEND_LOW, // lower
    WAIT_LOW
} state_t; 

state_t state; 

logic [15:0] recieved_word; 

//uart transmission logic 
always_ff @(posedge clk) begin
    if(reset)begin
        state          <= IDLE;
        recieved_word <= 16'b0;
        uart_data      <= 8'b0;
        uart_start     <= 1'b0;
    end
    
    else begin
        uart_start <= 1'b0; 

    case(state)
    
        IDLE: begin
            if(spi_data_valid) begin
                if(spi_data[15:12] == 4'hA)begin // only allow compelte transmissions through
                recieved_word <= spi_data; 
                state <= SEND_HIGH;
                end
            end
        end

        SEND_HIGH:begin
            
            if(!uart_busy)begin // send upper byte 
                uart_data <= recieved_word[15:8]; 
                uart_start <= 1'b1; 
                state <= WAIT_HIGH; 
            end
        end

        WAIT_HIGH: begin
            if(!uart_busy) begin
                state <= SEND_LOW;
            end
        end

        SEND_LOW: begin
            if(!uart_busy) begin
                uart_data <= recieved_word[7:0]; 
                uart_start <= 1'b1;
                state <= WAIT_LOW;
            end
        end

        WAIT_LOW: begin
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