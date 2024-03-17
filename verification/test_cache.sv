module cache_tb ();
    logic clk;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    default clocking tb_clk @(posedge clk); endclocking


    logic reset = 0;

    logic we1 = 0;
    logic read_en1 = 0;
    logic [15:0] addr1 = 0;
    logic [31:0] dout1;
    logic memValid1;


    logic [31:0] din2, dout2;
    logic [31:0] addr2;
    logic read_en2;
    logic we2;
    logic memValid2;


    Memory #(.DELAY_BITS(3)) DUT (
        .MEM_CLK        (clk),
        .RST            (reset),
        .MEM_RDEN1      (read_en1),        
        .MEM_RDEN2      (read_en2),        
        .MEM_WE2        (we2),        
        .MEM_ADDR1      (addr1[15:2]),        
        .MEM_ADDR2      (addr2),        
        .MEM_DIN2       (din2),        
        .MEM_SIZE       (0),        
        .MEM_SIGN       (0),        
        .MEM_DOUT1      (dout1),        
        .MEM_DOUT2      (dout2),        
        .memValid1      (memValid1),
        .memValid2      (memValid2)
    );

    (* rom_style="{distributed | block}" *)
    (* ram_decomp = "power" *) logic [31:0] expected_memory [0:16383];
    
    initial begin
        $readmemh("otter_mem.mem", expected_memory, 0, 16383);
    end

    task reset_cache();
        reset = 1;
        ##(2);
        reset = 0;
    endtask : reset_cache

    task read_addr(logic [15:0] base_addr, logic [2:0] word_offset, logic [1:0] byte_offset);
        addr1 = {base_addr[15:5], word_offset, byte_offset};
        read_en1 = 1;
        @(posedge clk iff memValid1);
        read_en1 = 0;
    endtask : read_addr

    task read_lines();
        int TEST_RUNS = 100;
        int WORDS_IN_LINE = 8;

        int word_addr;
        for (int i=0; i<TEST_RUNS; i++) begin
            word_addr = $urandom_range(0, 16'h6000);
            for (int word_offset = 0; word_offset < WORDS_IN_LINE; word_offset++) begin
                read_addr(word_addr[15:0], word_offset[2:0], 2'b00);
                assert (dout1 == expected_memory[addr1 / 4]) else $fatal("Memory read error at addr1 %x, expected %x, got %x", addr1, expected_memory[addr1 / 4], dout1);
            end
        end

        read_en1 = 0;
        addr1 = 16'h0;
    endtask : read_lines

    task read_random_addr();
        int TEST_RUNS = 100;
        int instr_addr;
        for (int i=0; i<TEST_RUNS; i++) begin
            instr_addr = $urandom_range(0, 16'h6000);
            read_addr(instr_addr, instr_addr[2:0], 0);
            assert (dout1 == expected_memory[addr1 / 4]) else $fatal("Memory read error at addr1 %x, expected %x, got %x", addr1, expected_memory[addr1 / 4], dout1);
        end
        read_en1 = 0;
        addr1 = 16'h0;
    endtask : read_random_addr

    task read_entire_Imem();
        int max_addr = 1024 * 6; // 6KB of memory for Imem
        for (int i=0; i < max_addr; i++) begin
            addr1 = i << 2;
            read_en1 = 1;
            @(posedge clk iff memValid1);
            assert (dout1 == expected_memory[i]) else $fatal("Memory read error at addr1 %x, expected %x, got %x", addr1, expected_memory[i], dout1);
        end
        
        read_en1 = 0;
        addr1 = 16'h0;
    endtask : read_entire_Imem


    task read_entire_Dmem();
        int max_addr = 2 ** 16;         // 64KB of memory for total memory
        int instr_mem_size = 1024 * 6; // 6KB of memory for Imem
        int data_mem_size = max_addr - instr_mem_size;  // 58KB of memory for Dmem

        for (int i=instr_mem_size; i < max_addr; i++) begin
            addr2 = i;
            read_en2 = 1;
            @(posedge clk iff memValid2);
            assert (dout2 == expected_memory[i]) else $fatal("Memory read error at addr2 %x, expected %x, got %x", addr2, expected_memory[i], dout2);
        end


    endtask : read_entire_Dmem


    initial begin
        reset_cache();
        $display("Starting test...");

        read_lines();
        $display("line by line read test passed");

        ##(3);
        read_random_addr();
        $display("random addr1 test passed");

        ##(3);
        read_entire_Imem();
        $display("Entire Imem read test passed");


        // read_entire_Dmem();        


        ##(3);
        $display("Test finished");
        $finish;
    end


endmodule