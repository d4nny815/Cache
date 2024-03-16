module MainMemory #(
    parameter DELAY_BITS = 4
    ) (
    input MEM_CLK,
    input RST,
    input MEM_RDEN1,        // read enable Instruction
    input MEM_RDEN2,        // read enable data
    input MEM_WE2,          // write enable.
    input [13:0] MEM_ADDR1, // Instruction Memory word Addr (Connect to PC[15:2])
    input [31:0] MEM_ADDR2, // Data Memory Addr
    input [31:0] MEM_DIN2,  // Data to save
    input [1:0] MEM_SIZE,   // 0-Byte, 1-Half, 2-Word
    input MEM_SIGN,         // 1-unsigned 0-signed
    output logic [31:0] MEM_DOUT1,  // Instruction
    output logic [31:0] MEM_DOUT2,   // Data
    output logic memValid1
    ); 

    clk_2n_div #(.n(DELAY_BITS)) MM_DIV (
        .clockin        (MEM_CLK), 
        .rst            (RST),          
        .clockout       (memValid1)   
    );
    
    logic [13:0] wordAddr1, wordAddr2;
    logic [31:0] memReadWord, memReadSized, _MEM_DOUT1;
    logic [1:0] byteOffset;
    logic weAddrValid;      // active when saving (WE) to valid memory address
       
    (* rom_style="{distributed | block}" *)
    (* ram_decomp = "power" *) logic [31:0] memory [0:16383];
    
    initial begin
//        $readmemh("otter_memory.mem", memory, 0, 16383);
        $readmemh("otter_mem.mem", memory, 0, 16383);
    end
    
    assign wordAddr2 = MEM_ADDR2[15:2];
    assign byteOffset = MEM_ADDR2[1:0];     // byte offset of memory address
    
    // BRAM requires all reads and writes to occur synchronously
    always_ff @(negedge MEM_CLK) begin
        // save data (WD) to memory (ADDR2)
        if (weAddrValid == 1) begin  //(MEM_WE == 1) && (MEM_ADDR2 < 16'hFFFD)) begin   // write enable and valid address space
            case({MEM_SIZE,byteOffset})
                4'b0000: memory[wordAddr2][7:0]   <= MEM_DIN2[7:0];     // sb at byte offsets
                4'b0001: memory[wordAddr2][15:8]  <= MEM_DIN2[7:0];
                4'b0010: memory[wordAddr2][23:16] <= MEM_DIN2[7:0];
                4'b0011: memory[wordAddr2][31:24] <= MEM_DIN2[7:0];
                4'b0100: memory[wordAddr2][15:0]  <= MEM_DIN2[15:0];    // sh at byte offsets
                4'b0101: memory[wordAddr2][23:8]  <= MEM_DIN2[15:0];
                4'b0110: memory[wordAddr2][31:16] <= MEM_DIN2[15:0];
                4'b1000: memory[wordAddr2]        <= MEM_DIN2;          // sw
			
			    // default: memory[wordAddr2] <= 32'b0  // unsupported size, byte offset combination
			    // removed to avoid mistakes causing memory to be zeroed.
            endcase
        end
        if(MEM_RDEN2)                         // Read word from memory
            memReadWord <= memory[wordAddr2];
    end

    always_ff @(posedge MEM_CLK) begin
        if(MEM_RDEN1)                         // Read word from memory
            _MEM_DOUT1 <= memory[MEM_ADDR1];
    end
       
    // Change the data word into sized bytes and sign extend 
    always_comb begin
        case({MEM_SIGN,MEM_SIZE,byteOffset})
            5'b00011: memReadSized = {{24{memReadWord[31]}},memReadWord[31:24]};    // signed byte
            5'b00010: memReadSized = {{24{memReadWord[23]}},memReadWord[23:16]};
            5'b00001: memReadSized = {{24{memReadWord[15]}},memReadWord[15:8]};
            5'b00000: memReadSized = {{24{memReadWord[7]}},memReadWord[7:0]};
                                    
            5'b00110: memReadSized = {{16{memReadWord[31]}},memReadWord[31:16]};    // signed half
            5'b00101: memReadSized = {{16{memReadWord[23]}},memReadWord[23:8]};
            5'b00100: memReadSized = {{16{memReadWord[15]}},memReadWord[15:0]};
            
            5'b01000: memReadSized = memReadWord;                   // word
               
            5'b10011: memReadSized = {24'd0,memReadWord[31:24]};    // unsigned byte
            5'b10010: memReadSized = {24'd0,memReadWord[23:16]};
            5'b10001: memReadSized = {24'd0,memReadWord[15:8]};
            5'b10000: memReadSized = {24'd0,memReadWord[7:0]};
               
            5'b10110: memReadSized = {16'd0,memReadWord[31:16]};    // unsigned half
            5'b10101: memReadSized = {16'd0,memReadWord[23:8]};
            5'b10100: memReadSized = {16'd0,memReadWord[15:0]};
            
            default:  memReadSized = 32'b0;     // unsupported size, byte offset combination 
        endcase
    end
 
    // Memory Mapped IO 
    always_comb begin
        MEM_DOUT1 = memValid1 ? _MEM_DOUT1 : 32'hdeadbeef;
        MEM_DOUT2 = memReadSized;   // output sized and sign extended data
    end
        
 endmodule