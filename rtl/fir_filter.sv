//hamming window 
module fir_filter (
    input logic clk, 
    input logic reset, 
    input logic signed[11:0] sample_in, 
    input logic sample_valid, //align filtering with sample time, figure out sample time later
                                //depends on adc
    output logic signed [15:0] sample_out,
    output logic output_valid
); 

//in q1.15 fixed representation for more accuracy, 
//determined by scipy firwin, 1.4khz cutoff, 8khz sampling frequency

function automatic signed [15:0] coeff(input integer idx);
    begin
        case (idx)
            0:  coeff =  16'sd102;
            1:  coeff =  16'sd146;
            2:  coeff = -16'sd102;
            3:  coeff = -16'sd893;
            4:  coeff = -16'sd1133;
            5:  coeff =  16'sd1224;
            6:  coeff =  16'sd6296;
            7:  coeff =  16'sd10744;
            8:  coeff =  16'sd10744;
            9:  coeff =  16'sd6296;
            10: coeff =  16'sd1224;
            11: coeff = -16'sd1133;
            12: coeff = -16'sd893;
            13: coeff = -16'sd102;
            14: coeff =  16'sd146;
            15: coeff =  16'sd102;
            default: coeff = 16'sd0;
        endcase
    end
endfunction

logic signed [11:0] samples[0:15]; 
logic [3:0] tap_index; 
logic busy; 
logic signed [31:0] accumulator; // 12 + 16  + log2(16) = 32 bits for safety.  

logic signed [31:0] current_product;
logic signed [15:0] current_coeff; 
logic signed [31:0] mac_sum;
logic signed [31:0] rounded_result;
logic signed [15:0] saturated_result;


always_ff @( posedge clk ) begin : delay_update 
    if(reset)begin
        for(int i = 0; i < 16; i = i + 1)begin
            samples[i] <= 0; 
        end
        sample_out <= 0; 
        output_valid <= 0; 
        busy <= 0; 
        tap_index <= 0; 
        accumulator <= 0; 
    end
    else begin 
        output_valid <= 0; 
        if(sample_valid && (!busy)) begin //125 microseconds before next reading sampling at 8khz
            for(int i = 15 ; i > 0 ; i = i - 1) begin
                samples[i] <= samples[i-1]; 
            end
            samples[0]<= sample_in; 
            accumulator <= 0; 
            tap_index <= 0; 
            busy <=1; 
        end
        else if(busy) begin
            if(tap_index == 15) begin // finished accumulating 
                sample_out <= saturated_result; 
                busy<= 0 ;
                output_valid <=1; 
            end
            else begin
                accumulator <= mac_sum; 
                tap_index <= tap_index + 1; 
            end
        end
    end
end 

always_comb begin
    current_coeff   = coeff(tap_index);

    // Debug: force every sample to 1000.
    // 32'sd1000 guarantees at least 32-bit signed multiplication.
    current_product = $signed(samples[tap_index]) * $signed(current_coeff);

    mac_sum = accumulator + current_product;

    if (mac_sum >= 0) begin
        rounded_result = (mac_sum + 32'sd16384) >>> 15;
    end
    else begin
        rounded_result = (mac_sum + 32'sd16383) >>> 15;
    end

    if (rounded_result > 32767)
        saturated_result = 16'sd32767;
    else if (rounded_result < -32768)
        saturated_result = -16'sd32768;
    else
        saturated_result = $signed(rounded_result);
end


/* parallel multipliers 
always_comb begin : MAC // on sample comes in, fir will calculate result that same clock cycle 
    accumulator = coeff(0) * sample_in ;
    for (int i = 0; i <15 ; i = i +1) begin
        accumulator = accumulator + coeff(i + 1) * samples[i]; 
    end

    if (accumulator >= 0)begin// rounding, 15 fractional bits so this adds 2^14, round to nearest, right shift then floors
        rounded_result = (accumulator + 32'sd16384) >>> 15; 
    end
    else begin  
        rounded_result = (accumulator + 32'sd16383) >>> 15; //2^x-1 for .5 case, round to nearest instead of zero
    end

    //saturates if accumulator filled
    if(rounded_result > 32767) begin
        saturated_result = 16'sd32767; 
    end
    else if(rounded_result < -32768) begin
        saturated_result = -16'sd32768; 
    end
    else begin
        saturated_result = $signed(rounded_result); 
    end
end
*/

endmodule