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

    input logic re_dmem,
    input logic we_in_dmem,
    input logic hit_dmem,
    input logic dirty_dmem,
    
    input logic full_cl,

    input logic mem_valid_mm,
    
    // * OUTPUTS
    output logic clr,
    output logic memValid1,
    output logic memValid2,
    output logic [1:0] cl_dir_sel,

    output logic we_imem,

    output logic we_dmem,
    
    output logic we_cl,
    output logic next_cl,

    output logic re_mm,
    output logic we_data_mm,   
    output logic reset_mm
    );

    typedef enum logic [2:0] {
        INIT,
        CHECK_L1,
        FETCH_IMEM,
        FILL_IMEM,
        WB_DMEM,
        FILL_MM,
        FETCH_DMEM,
        FILL_DMEM
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
        clr = 1'b0; memValid1 = 1'b0; memValid2 = 1'b0; cl_dir_sel = 2'b00; 
        we_imem = 1'b0; we_dmem = 1'b0; we_cl = 1'b0; next_cl = 1'b0; re_mm = 1'b0; 
        we_data_mm = 1'b0; reset_mm = 1'b0;

        case (state)
            INIT: begin
                clr = 1'b1;
                next_state = CHECK_L1;
            end

            CHECK_L1: begin
                if (re_imem == 1 && hit_imem == 1) begin
                    memValid1 = 1;
                    next_state = CHECK_L1;
                end
                else if (re_imem == 1 && hit_imem == 0) begin
                    reset_mm = 1;
                    next_state = FETCH_IMEM;
                end
                else if (re_dmem == 1 && hit_dmem == 1) begin
                    memValid2 = 1;
                    next_state = CHECK_L1;
                end
                else if (re_dmem == 1 && hit_dmem == 0 && dirty_dmem == 1) begin
                    reset_mm = 1;
                    next_state = WB_DMEM;
                end
                else if (re_dmem == 1 && hit_dmem == 0 && dirty_dmem == 0) begin
                    reset_mm = 1;
                    next_state = FETCH_DMEM;
                end
                else if (we_in_dmem == 1 && hit_dmem == 0 && dirty_dmem == 1) begin
                    reset_mm = 1;
                    next_state = WB_DMEM;
                end
                else if (we_in_dmem == 1 && hit_dmem == 0 && dirty_dmem == 0) begin
                    reset_mm = 1;
                    next_state = FETCH_DMEM;
                end
                else if (we_in_dmem == 1 && hit_dmem == 1) begin
                    next_state = CHECK_L1;
                    memValid2 = 1;
                end
                else
                    next_state = CHECK_L1;
            end

            FETCH_IMEM: begin
                cl_dir_sel = 2'b00;
                re_mm = 1;
                we_cl = mem_valid_mm;
                next_cl = mem_valid_mm;
                if (full_cl & mem_valid_mm) begin
                    reset_mm = 1;
                    next_state = FILL_IMEM;
                end
                else begin
                    next_state = FETCH_IMEM;
                end
            end

            FILL_IMEM: begin
                we_imem = 1;
                next_cl = 1;
                if (full_cl == 1) begin
                    next_state = CHECK_L1;
                    reset_mm = 1;
                end
                else
                    next_state = FILL_IMEM;
            end

            WB_DMEM: begin
                cl_dir_sel = 2'b11;
                we_cl = 1;
                next_cl = 1;
                if (full_cl == 1) begin
                    reset_mm = 1;
                    next_state = FILL_MM;
                    
                end
                else
                    next_state = WB_DMEM;
            end

            FILL_MM: begin
                cl_dir_sel = 2'b01;
                we_data_mm = 1;
                next_cl = 1;
                if (full_cl == 1) begin
                    reset_mm = 1;
                    next_state = FETCH_DMEM;
                end
                else
                    next_state = FILL_MM;
            end

            FETCH_DMEM: begin
                cl_dir_sel = 2'b10;
                re_mm = 1;
                we_cl = mem_valid_mm;
                next_cl = mem_valid_mm;
                if (full_cl & mem_valid_mm) begin
                    reset_mm = 1;
                    next_state = FILL_DMEM;
                end
                else
                    next_state = FETCH_DMEM;
            end

            FILL_DMEM: begin
                we_dmem = 1;
                next_cl = 1;
                cl_dir_sel = 2'b10;
                if (full_cl == 1) begin
                    next_state = CHECK_L1;
                    reset_mm = 1;
                end
                else
                    next_state = FILL_DMEM;
            end


        default: next_state = INIT;
        endcase
    end


endmodule