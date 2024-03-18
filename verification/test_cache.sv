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


    logic [31:0] din2 = 0, dout2 = 0;
    logic [31:0] addr2;
    logic read_en2 = 0;
    logic we2 = 0;
    logic memValid2;
    logic sign = 0;
    logic [1:0] size = 0;


    Memory #(.DELAY_BITS(3)) DUT (
        .MEM_CLK        (clk),
        .RST            (reset),
        .MEM_RDEN1      (read_en1),        
        .MEM_RDEN2      (read_en2),        
        .MEM_WE2        (we2),        
        .MEM_ADDR1      (addr1[15:2]),        
        .MEM_ADDR2      (addr2),        
        .MEM_DIN2       (din2),        
        .MEM_SIZE       (size),        
        .MEM_SIGN       (sign),        
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
        @(posedge clk);
    endtask : reset_cache

    task read_instr_addr(logic [15:0] base_addr, logic [2:0] word_offset);
        addr1 = {base_addr[15:5], word_offset, 2'b00};
        read_en1 = 1;
        @(posedge clk iff memValid1);
        read_en1 = 0;
    endtask : read_instr_addr

    task read_lines();
        int TEST_RUNS = 100;
        int WORDS_IN_LINE = 8;

        int word_addr;
        for (int i=0; i<TEST_RUNS; i++) begin
            word_addr = $urandom_range(0, 16'h6000);
            for (int word_offset = 0; word_offset < WORDS_IN_LINE; word_offset++) begin
                read_instr_addr(word_addr[15:0], word_offset[2:0], 2'b00);
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


    // this tests lw 
    task read_entire_Dmem();
        int max_addr = (2 ** 16) >> 2;         // 64KB of memory for total memory
        int instr_mem_size = 1024 * 6; // 6KB of memory for Imem
        sign = 0;
        size = 2'b10;

        $display("reading from %x to %x", instr_mem_size, max_addr);
        for (int i=instr_mem_size; i < max_addr; i++) begin
            addr2 = i << 2;
            read_en2 = 1;
            @(posedge clk iff memValid2);
            assert (dout2 == expected_memory[i]) else $fatal("Memory read error at addr2 %x in dec %d, expected %x, got %x", addr2, addr2 >> 2, expected_memory[i], dout2);
        end
    endtask : read_entire_Dmem

    // lb, lbu, lh, lhu
    task read_diff_size();
        int instr_mem_size = 1024 * 6;

        logic [31:0] word;
        logic [15:0] half_word;
        logic [7:0] bytes;

        logic [31:0] expected;

        // lb
        read_en2 = 1;
        sign = 0;
        size = 2'b00;
        for (int i=0; i<200; i++) begin
            if (i % 4 == 0) word = expected_memory[instr_mem_size + (i >> 2)];
            addr2 = (instr_mem_size << 2) + i;
            bytes = word[(i % 4) * 8 +: 8];
            expected = {{24{bytes[7]}}, bytes};
            @(posedge clk iff memValid2);
            assert (dout2 == expected) else $fatal("Memory read error at addr2 %x, expected %x, got %x", addr2, expected, dout2);
        end

        read_en2 = 0;
        ##(3);

        // lh
        read_en2 = 1;
        sign = 0;
        size = 2'b01;
        for (int i=0; i<200; i++) begin
            if (i % 2 == 0) word = expected_memory[instr_mem_size + (i >> 1)];
            addr2 = (instr_mem_size << 2) + (i << 1);
            half_word = word[(i % 2) * 16 +: 16];
            expected = {{16{half_word[15]}}, half_word};
            @(posedge clk iff memValid2);
            assert (dout2 == expected) else $fatal("Memory read error at addr2 %x, expected %x, got %x", addr2, expected, dout2);
        end

        read_en2 = 0;
        ##(3);

        // lbu
        read_en2 = 1;
        sign = 1;
        size = 2'b00;
        for (int i=0; i<200; i++) begin
            if (i % 4 == 0) word = expected_memory[instr_mem_size + (i >> 2)];
            addr2 = (instr_mem_size << 2) + i;
            bytes = word[(i % 4) * 8 +: 8];
            expected = {24'b0, bytes};
            @(posedge clk iff memValid2);
            assert (dout2 == expected) else $fatal("Memory read error at addr2 %x, expected %x, got %x", addr2, expected, dout2);
        end

        read_en2 = 0;
        ##(3);

        // lhu
        read_en2 = 1;
        sign = 1;
        size = 2'b01;
        for (int i=0; i<200; i++) begin
            if (i % 2 == 0) word = expected_memory[instr_mem_size + (i >> 1)];
            addr2 = (instr_mem_size << 2) + (i << 1);
            half_word = word[(i % 2) * 16 +: 16];
            expected = {16'b0, half_word};
            @(posedge clk iff memValid2);
            assert (dout2 == expected) else $fatal("Memory read error at addr2 %x, expected %x, got %x", addr2, expected, dout2);
        end
    endtask : read_diff_size


    task writeback();
        logic [1:0] byte_offset = 0;
        logic [2:0] word_offset = 0;
        logic [4:0] index_offset = 0;
        logic [21:0] tag = 0;
        logic [21:0] data_tag = 'h18;

        sign = 0;
        size = 2;
        @(posedge clk);

        // cold start
        we2 = 1;
        tag = 0;
        for (int i=0; i<8; i++) begin
            addr2 = {tag + data_tag, index_offset, i[2:0], byte_offset};
            din2 = i + 1;
            @(posedge clk iff memValid2);
        end
        we2 = 0;

        // fill 2nd set
        @(posedge clk);
        we2 = 1;
        tag = 1;
        for (int i=0; i<8; i++) begin
            addr2 = {tag + data_tag, index_offset, i[2:0], byte_offset};
            din2 = i * 2 + 1;

            @(posedge clk iff memValid2);
        end
        @(posedge clk iff memValid2);
        we2 = 0;

        // overwrite 1st set        
        @(posedge clk);
        we2 = 1;
        tag = 2;
        for (int i=0; i<8; i++) begin
            addr2 = {tag + data_tag, index_offset, i[2:0], byte_offset};
            din2 = i * 3 + 1;
            @(posedge clk iff memValid2);
        end
        we2 = 0;

        // check if data was written back by bringing back the 1st set
        @(posedge clk);
        din2 = 32'hdead_beef;
        tag = 0;
        for (int i=0; i<8; i++) begin
            addr2 = {tag + data_tag, index_offset, i[2:0], byte_offset};
            read_en2 = 1;
            @(posedge clk iff memValid2);
            assert (dout2 == i + 1) else $fatal("Memory read error at addr2 %x, expected %x, got %x", addr2, i * 2 + 1, dout2);
        end
        @(posedge clk iff memValid2);

    endtask : writeback
    
    // read imem and dmem at same time

    // imem miss and dmem hit

    // imem hit and dmem miss

    // imem miss and dmem miss


    initial begin
        reset_cache();
        $display("Starting test...");
 
         read_lines();
         $display("line by line read test passed");

        //  ##(3);
        //  read_random_addr();
        //  $display("random addr1 test passed");

        //  ##(3);
        //  read_entire_Imem();
        //  $display("Entire Imem read test passed");


        // read_entire_Dmem();      

        // read_diff_size();  

        // writeback();


        ##(3);
        $display("Test finished");
        $finish;
    end


endmodule