
module InstrL1 (
    input logic clk,
    input logic reset,
    input logic we,
    input logic [13:0] addr,
    input logic [31:0] data,
    output logic [31:0] dout,
    output logic hit
    );


    // parameter SETS = 2;
    parameter ADDR_SIZE = 14;
    parameter WORD_SIZE = 32;
    parameter LINES_PER_SET = 32;
    parameter WORDS_PER_LINE = 8;
    parameter SET_LINE_BITS = $clog2(LINES_PER_SET);
    parameter WORD_OFFSET_BITS = $clog2(WORDS_PER_LINE);
    parameter TAG_BITS = ADDR_SIZE - SET_LINE_BITS - WORD_OFFSET_BITS;
    parameter SET_SIZE = WORDS_PER_LINE * LINES_PER_SET;

    logic [SET_SIZE - 1:0] set0 [LINES_PER_SET - 1:0];
    logic [SET_SIZE - 1:0] set1 [LINES_PER_SET - 1:0];
    logic [TAG_BITS - 1:0] tag0 [LINES_PER_SET - 1:0];
    logic [TAG_BITS - 1:0] tag1 [LINES_PER_SET - 1:0];
    logic [LINES_PER_SET - 1:0] valid0, valid1;
    logic [LINES_PER_SET - 1:0] lru_bits;

    logic [WORD_SIZE * WORDS_PER_LINE - 1:0] line_buffer;
    logic [WORD_OFFSET_BITS - 1:0] word_offset;
    logic [SET_LINE_BITS - 1:0] set_index;
    logic [TAG_BITS:0] tag;



    always_comb begin
        word_offset = addr[WORD_OFFSET_BITS - 1:0];
        set_index = addr[SET_LINE_BITS + WORD_OFFSET_BITS - 1:WORD_OFFSET_BITS];
        tag = addr[ADDR_SIZE - 1:SET_LINE_BITS + WORD_OFFSET_BITS];
        
    end

    // async read
        always_comb begin
            if (valid0[set_index] && tag0[set_index] == tag) begin
                hit = 1'b1;
                line_buffer = set0[set_index];
            end else if (valid1[set_index] && tag1[set_index] == tag) begin
                hit = 1'b1;
                line_buffer = set1[set_index];
            end else begin
                hit = 1'b0;
                line_buffer = -1;
            end
    
            case (word_offset)
                0: dout = line_buffer[WORD_SIZE - 1:0];
                1: dout = line_buffer[WORD_SIZE * 2 - 1 -: WORD_SIZE];
                2: dout = line_buffer[WORD_SIZE * 3 - 1 -: WORD_SIZE];
                3: dout = line_buffer[WORD_SIZE * 4 - 1 -: WORD_SIZE];
                4: dout = line_buffer[WORD_SIZE * 5 - 1 -: WORD_SIZE];
                5: dout = line_buffer[WORD_SIZE * 6 - 1 -: WORD_SIZE];
                6: dout = line_buffer[WORD_SIZE * 7 - 1 -: WORD_SIZE];
                7: dout = line_buffer[WORD_SIZE * 8 - 1 -: WORD_SIZE];
            endcase

        end
    

        // sync write
        always_ff @( negedge clk ) begin
            if (reset) begin
                for (int i = 0; i < LINES_PER_SET; i++) begin
                    valid0[i] <= 0;
                    valid1[i] <= 0;
                    lru_bits[i] <= 0;
                end
                end
            else
    
            if (we) begin
                $display("DEV: Writing D:%x to A:%x with T:%d, SI:%d, WO:%d", data, addr, tag, set_index, word_offset);
                if (lru_bits[set_index] == 0) begin
                    $display("DEV: Writing to set0");
                    valid0[set_index] <= 1;                
                    tag0[set_index] <= tag;
    
                    case(word_offset)
                        0: set0[set_index][WORD_SIZE * 0 +: WORD_SIZE] <= data;
                        1: set0[set_index][WORD_SIZE * 1 +: WORD_SIZE] <= data;
                        2: set0[set_index][WORD_SIZE * 2 +: WORD_SIZE] <= data;
                        3: set0[set_index][WORD_SIZE * 3 +: WORD_SIZE] <= data;
                        4: set0[set_index][WORD_SIZE * 4 +: WORD_SIZE] <= data;
                        5: set0[set_index][WORD_SIZE * 5 +: WORD_SIZE] <= data;
                        6: set0[set_index][WORD_SIZE * 6 +: WORD_SIZE] <= data;
                        7: begin
                            lru_bits[set_index] <= 1;
                            set0[set_index][WORD_SIZE * 7 +: WORD_SIZE] <= data;
                        end
                    endcase
                end
                
                else begin
                    $display("DEV: Writing to set1");
                    valid1[set_index] <= 1;
                    tag1[set_index] <= tag;
    
                    case(word_offset)
                        0: set1[set_index][WORD_SIZE * 0 +: WORD_SIZE] <= data;
                        1: set1[set_index][WORD_SIZE * 1 +: WORD_SIZE] <= data;
                        2: set1[set_index][WORD_SIZE * 2 +: WORD_SIZE] <= data;
                        3: set1[set_index][WORD_SIZE * 3 +: WORD_SIZE] <= data;
                        4: set1[set_index][WORD_SIZE * 4 +: WORD_SIZE] <= data;
                        5: set1[set_index][WORD_SIZE * 5 +: WORD_SIZE] <= data;
                        6: set1[set_index][WORD_SIZE * 6 +: WORD_SIZE] <= data;
                        7: begin
                            lru_bits[set_index] <= 0;
                            set1[set_index][WORD_SIZE * 7 +: WORD_SIZE] <= data;
                        end
                    endcase
                end
            end
        end
endmodule