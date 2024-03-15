module CacheLineAdapter (
    input clk,
    input clr,
    input [31:0] addr_i,
    input [31:0] data_i,
    input we,
    input next,
    output logic [31:0] addr_o,
    output logic [31:0] data_o,
    output logic full
    );

    parameter WORD_SIZE = 32;
    parameter WORDS_PER_LINE = 8;
    parameter LINE_BITS = $clog2(WORDS_PER_LINE);
    parameter BYTE_BITS = 2;

    // addr_gen
    logic [LINE_BITS - 1:0] counter;
    always_ff @(negedge clk) begin
        if (clr == 1) begin
            counter <= 0;
        end
        else if (next == 1)
            counter <= counter + 1;
    end


    logic [WORD_SIZE - 1:0] line_buffer [WORDS_PER_LINE - 1:0];

    always_comb begin
        full = (counter == WORDS_PER_LINE - 1);
        addr_o = {addr_i[31: LINE_BITS + BYTE_BITS], 5'd0} + counter << BYTE_BITS;
        data_o = line_buffer[counter]; 
    end

    always_ff @(negedge clk) begin
        if (we == 1) 
            line_buffer[counter] <= data_i;
    end



endmodule