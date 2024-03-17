module MainMemory #(
    parameter DELAY_BITS = 4
    ) (
    input MEM_CLK,
    input RST,
    input MEM_RDEN1,                // read enable Instruction
    input MEM_RDEN2,                // read enable data
    input MEM_WE2,                  // write enable.
    input [13:0] MEM_ADDR1,         // Instruction Memory word Addr (Connect to PC[15:2])
    input [29:0] MEM_ADDR2,         // Data Memory Addr
    input [31:0] MEM_DIN2,          // Data to save
    output logic [31:0] MEM_DOUT1,  // Instruction
    output logic [31:0] MEM_DOUT2,  // Data
    output logic memValid1
    ); 

    clk_2n_div #(.n(DELAY_BITS)) MM_DIV (
        .clockin        (MEM_CLK), 
        .rst            (RST),          
        .clockout       (memValid1)   
    );
    
    logic [31:0] _MEM_DOUT1, _MEM_DOUT2;
       
    (* rom_style="{distributed | block}" *)
    (* ram_decomp = "power" *) logic [31:0] memory [0:16383];
    
    initial begin
//        $readmemh("otter_memory.mem", memory, 0, 16383);
        $readmemh("otter_mem.mem", memory, 0, 16383);
    end
    

    always_ff @(posedge MEM_CLK) begin
        if (MEM_WE2)                          // Write word to memory
            memory[MEM_ADDR2] <= MEM_DIN2;
        if(MEM_RDEN2)                         // Read word from memory
            _MEM_DOUT2 <= memory[MEM_ADDR2];
        if(MEM_RDEN1)                         // Read word from memory
            _MEM_DOUT1 <= memory[MEM_ADDR1];
    end
        
    always_comb begin
        MEM_DOUT1 = memValid1 ? _MEM_DOUT1 : 32'hdeadbeef;
        MEM_DOUT2 = memValid1 ? _MEM_DOUT2 : 32'hdeadbeef;
        
    end
        
 endmodule