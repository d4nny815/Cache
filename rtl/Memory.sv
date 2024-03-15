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
    logic [31:0] instr_data;

    // Cache Line wires
    logic full_cl;
    logic [31:0] line_in_buffer, instr;
    logic [31:0] line_buffer, line_addr;


    // control logic
    logic we_imem, we_cl, next_cl, re_mm, re_imem, hit;


    InstrL1 instr_mem (
        .clk            (MEM_CLK),
        .reset          (clr),
        .we             (we_imem),
        .addr           (we_imem ? line_addr[15:2] : MEM_ADDR1),
        .data           (line_buffer),
        .dout           (instr_data),
        .hit            (imem_hit)
    );

    // always_comb begin
    //     line_in_buffer = 
    // end

    CacheLineAdapter cache_line_adapter (
        .clk            (MEM_CLK),
        .clr            (clr),
        .addr_i         ({16'd0, MEM_ADDR1, 2'd0}),
        .data_i         (instr),
        .we             (we_cl),
        .next           (next_cl),
        .addr_o         (line_addr),
        .data_o         (line_buffer),
        .full           (full_cl)
    );

    MainMemory #(.DELAY_BITS(3)) main_memory (
        .MEM_CLK        (MEM_CLK),
        .RST            (clr),
        .MEM_RDEN1      (re_mm),        // read enable Instruction
        .MEM_RDEN2      (0),            // read enable data
        .MEM_WE2        (0),            // write enable.
        .MEM_ADDR1      (line_addr[15:2]),    // Instruction Memory word Addr (Connect to PC[15:2])
        .MEM_ADDR2      (0),            // Data Memory Addr
        .MEM_DIN2       (0),            // Data to save
        .MEM_SIZE       (0),            // 0-Byte, 1-Half, 2-Word
        .MEM_SIGN       (0),            // 1-unsigned 0-signed
        .MEM_DOUT1      (instr),        // Instruction
        .MEM_DOUT2      (),             // Data
        .memValid1      (mem_valid_mm)
    );

    CacheController cache_controller (
        .clk            (MEM_CLK),
        .reset          (RST),
        .re_imem        (MEM_RDEN1),
        .hit_imem       (imem_hit),
        .full_cl        (full_cl),
        .mem_valid_mm   (mem_valid_mm),
        .clr            (clr),
        .memValid1      (memValid1),
        .we_imem        (we_imem),
        .we_cl          (we_cl),
        .next_cl        (next_cl),
        .re_mm          (re_mm)
    );

    always_comb begin
        MEM_DOUT1 = imem_hit ? instr_data : 32'hdead_beef;
    end




endmodule