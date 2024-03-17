// Memory Wrapper

/*
    instaniate MainMemory
    Memory myMemory (
        .MEM_CLK        (),
        .RST            (),
        .MEM_RDEN1      (),        
        .MEM_RDEN2      (),        
        .MEM_WE2        (),        
        .MEM_ADDR1      (),        
        .MEM_ADDR2      (),        
        .MEM_DIN2       (),        
        .MEM_SIZE       (),        
        .MEM_SIGN       (),        
        .MEM_DOUT1      (),        
        .MEM_DOUT2      (),        
        .memValid1      ()
    );
    )
*/

module Memory #(
    parameter DELAY_BITS = 4
    ) (
    input RST,
    input MEM_CLK, 
    input MEM_RDEN1,                // read enable Instruction
    input MEM_RDEN2,                // read enable data
    input MEM_WE2,                  // write enable.
    input [13:0] MEM_ADDR1,         // Instruction Memory word Addr (Connect to PC[15:2])
    input [31:0] MEM_ADDR2,         // Data Memory Addr
    input [31:0] MEM_DIN2,          // Data to save
    input [1:0] MEM_SIZE,           // 0-Byte, 1-Half, 2-Word
    input MEM_SIGN,                 // 1-unsigned 0-signed
//    input [31:0] IO_IN,             // Data from IO     
//    output logic IO_WR,             // IO 1-write 0-read
    output logic [31:0] MEM_DOUT1,  // Instruction
    output logic [31:0] MEM_DOUT2,  // Data
    output logic memValid1,
    output logic memValid2
    );

    logic imem_hit, cl_full, mm_valid;
    logic [31:0] instr_buffer, data_buffer;

    // Cache Line wires
    logic full_cl;
    logic [31:0] instr, data;
    logic [31:0] line_buffer, line_addr, dmem_addr;


    // control logic
    logic clr, we_imem, we_cl, next_cl, re_mm, re_imem, hit, reset_mm, 
        we_dmem, re_dmem, dmem_hit, dmem_dirty, mem_valid_mm, mem_valid1, 
        mem_valid2, we_data_mm, writeback_dmem;
    logic [1:0] cl_dir_sel;

    logic mem_addr_valid1, mem_addr_valid2;

    always_comb begin
        mem_addr_valid1 = MEM_ADDR1 < (16'h6000 >> 2);
        if (!mem_addr_valid1) $error("Invalid Instruction memory address %x", {MEM_ADDR1, 2'b0});
        mem_addr_valid2 = MEM_ADDR2 >= (16'h6000 >> 2) && MEM_ADDR2 < (17'h1_0000);
        if (!mem_addr_valid2) $error("Invalid Data memory address %x", {MEM_ADDR2, 2'b0});
    end

    InstrL1 #(
        .ADDR_SIZE      (14), 
        .WORD_SIZE      (32),
        .LINES_PER_SET  (32),
        .WORDS_PER_LINE (8)
        ) instr_mem (
        .clk            (MEM_CLK),
        .reset          (clr),
        .we             (we_imem),
        .addr           (we_imem ? line_addr[15:2] : MEM_ADDR1),
        .data           (line_buffer),
        .dout           (instr_buffer),
        .hit            (imem_hit)
    );

    DataL1 #(
        .ADDR_SIZE      (32), 
        .WORD_SIZE      (32),
        .LINES_PER_SET  (32),
        .WORDS_PER_LINE (8)
        ) data_mem (
        .clk            (MEM_CLK),
        .reset          (clr),
        .we             (cl_dir_sel[0] ? 1'b0 : MEM_WE2),
        .we_cache       (we_dmem),
        .sign           (cl_dir_sel ? 1'b1 : MEM_SIGN ),
        .size           (cl_dir_sel ? 2'b10 : MEM_SIZE),
        .addr           (we_dmem || cl_dir_sel == 2'b11 ? line_addr : MEM_ADDR2),
        .data           (we_dmem ? line_buffer : MEM_DIN2),
        .aout           (dmem_addr),
        .dout           (data_buffer),
        .hit            (dmem_hit),
        .dirty          (dmem_dirty)
    );

    
    logic [31:0] cl_data_in, cl_addr_in;

    always_comb begin
        case (cl_dir_sel)
            2'b00: begin
                cl_data_in = instr;
                cl_addr_in = {16'd0, MEM_ADDR1, 2'd0};
            end 
            2'b01: begin
                cl_data_in = data_buffer;
                cl_addr_in = dmem_addr;
            end
            2'b10: begin
                cl_data_in = data;
                cl_addr_in = MEM_ADDR2;
            end
            default: begin
                cl_data_in = 32'hdead_beef;
                cl_addr_in = dmem_addr;
            end 
        endcase
    end

    CacheLineAdapter cache_line_adapter (
        .clk            (MEM_CLK),
        .clr            (clr),
        .addr_i         (cl_addr_in),
        .data_i         (cl_data_in),
        .we             (we_cl),
        .next           (next_cl),
        .addr_o         (line_addr),
        .data_o         (line_buffer),
        .full           (full_cl)
    );

    MainMemory #(.DELAY_BITS(3)) main_memory (
        .MEM_CLK        (MEM_CLK),
        .RST            (clr | reset_mm),
        .MEM_RDEN1      (re_mm),          // read enable Instruction
        .MEM_RDEN2      (re_mm),           // read enable data
        .MEM_WE2        (we_data_mm),           // write enable.
        .MEM_ADDR1      (line_addr[15:2]),      // Instruction Memory word Addr (Connect to PC[15:2])
        .MEM_ADDR2      (line_addr[31:2]),            // Data Memory Addr
        .MEM_DIN2       (line_buffer),          // Data to save
        .MEM_DOUT1      (instr),                // Instruction
        .MEM_DOUT2      (data),                 // Data
        .memValid1      (mem_valid_mm)
    );

    CacheController cache_controller (
        .clk            (MEM_CLK),
        .reset          (RST),
        .re_imem        (MEM_RDEN1),
        .hit_imem       (imem_hit),
        .re_dmem        (MEM_RDEN2),
        .we_in_dmem     (MEM_WE2),
        .hit_dmem       (dmem_hit),
        .dirty_dmem     (dmem_dirty),
        .full_cl        (full_cl),
        .mem_valid_mm   (mem_valid_mm),
        .clr            (clr),
        .memValid1      (memValid1),
        .memValid2      (memValid2),
        .cl_dir_sel    (cl_dir_sel),
        .we_imem        (we_imem),
        .we_dmem        (we_dmem),
        .we_cl          (we_cl),
        .next_cl        (next_cl),
        .re_mm          (re_mm),
        .we_data_mm     (we_data_mm),
        .reset_mm       (reset_mm)
    );

    always_comb begin
        MEM_DOUT1 = imem_hit & mem_addr_valid1 ? instr_buffer : 32'hdead_beef;
        MEM_DOUT2 = dmem_hit & mem_addr_valid2 ? data_buffer : 32'hdead_beef;
    end

endmodule