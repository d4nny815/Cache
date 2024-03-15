// instanciate this module in the top level module
/*
    
CacheController cacheController (
    .clk            (clk),
    .reset          (reset),
    .re_imem        (re_imem),
    .hit_imem       (hit_imem),
    .full_cl        (full_cl),
    .mem_valid_mm   (mem_valid_mm),
    .clr            (clr),
    .we_imem        (we_imem),
    .we_cl          (we_cl),
    .next_cl        (next_cl),
    .re_mm          (re_mm)
);

*/


module CacheController (
    input logic clk,
    input logic reset,
    
    // * INPUTS
    input logic re_imem,
    input logic hit_imem,
    
    input logic full_cl,

    input logic mem_valid_mm,
    
    // * OUTPUTS
    output logic clr,
    output logic memValid1,

    output logic we_imem,
    
    output logic we_cl,
    output logic next_cl,

    output logic re_mm
    );

    typedef enum logic [2:0] {
        INIT,
        CHECK_L1,
        FETCH_IMEM,
        FILL_IMEM
    } state_t;

    state_t state, next_state;


    always_ff @(posedge clk) begin
        if (reset == 1) begin
            state <= INIT;
        end
        else
            state <= next_state;
    end

    always_comb begin
        clr = 1'b0; we_imem = 1'b0; we_cl = 1'b0; next_cl = 1'b0; re_mm = 1'b0; 
        memValid1 = 1'b0;

        case (state)
            INIT: begin
                clr = 1'b1;
                next_state = CHECK_L1;
            end

            CHECK_L1: begin
                if (re_imem == 1) begin
                    if (hit_imem == 1) begin
                        memValid1 = 1;
                        next_state = CHECK_L1;
                    end 
                    else
                        next_state = FETCH_IMEM;
                end
                else
                    next_state = CHECK_L1;
            end

            FETCH_IMEM: begin
                re_mm = 1;
                we_cl = mem_valid_mm;
                next_cl = mem_valid_mm;
                if (full_cl & mem_valid_mm) begin
                    next_state = FILL_IMEM;
                end
                else begin
                    next_state = FETCH_IMEM;
                end
            end

            FILL_IMEM: begin
                we_imem = 1;
                next_cl = 1;
                if (full_cl == 1)
                    next_state = CHECK_L1;
                else
                    next_state = FILL_IMEM;
            end



        default: next_state = INIT;
        endcase
    end


endmodule