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
    logic [31:0] addr2 = 16'h6000;
    logic read_en2 = 0;
    logic we2 = 0;
    logic memValid2;
    logic sign = 0;
    logic [1:0] size = 0;

    localparam int MEM_SIZE = 2 ** 16;
    localparam int DATA_MEM_START = 'h6000;
    localparam int INSTR_MEM_SIZE = 1024 * 6; // 6KB of memory for Imem
    localparam int TEST_RUNS = 100;
    localparam int WORDS_IN_LINE = 8;
    localparam int WORD_OFFSET_BITS = $clog2(WORDS_IN_LINE);
    localparam int LINES_PER_SET = 32;
    localparam int INDEX_BITS = $clog2(LINES_PER_SET);
    localparam int BYTE_OFFSET_BITS = 2;


    Memory #(.DELAY_CYCLES(10)) DUT (
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

    task read_instr_addr(logic [15:0] base_addr, logic [WORD_OFFSET_BITS-1:0] word_offset);
        addr1 = {base_addr[15:WORD_OFFSET_BITS], word_offset, 2'b00};
        read_en1 = 1;
        @(posedge clk iff memValid1);
        read_en1 = 0;
    endtask : read_instr_addr

    task read_instr_lines();
        int word_addr;
        for (int i=0; i<TEST_RUNS; i++) begin
            word_addr = $urandom_range(0, INSTR_MEM_SIZE);
            for (int word_offset = 0; word_offset < WORDS_IN_LINE; word_offset++) begin
                read_instr_addr(word_addr[15:0], word_offset[WORD_OFFSET_BITS-1:0]);
                assert (dout1 == expected_memory[addr1 / 4]) else $fatal("TB: Memory read error at addr1 %x, expected %x, got %x", addr1, expected_memory[addr1 / 4], dout1);
            end
        end

        read_en1 = 0;
        addr1 = 16'h0;
    endtask : read_instr_lines

    task read_data_addr(logic [31:0] addr, logic [1:0] size_i = 2'b10, logic sign_i = 0);
        addr2 = addr;
        read_en2 = 1;
        size = size_i;
        sign = sign_i;
        @(posedge clk iff memValid2);
        read_en2 = 0;
    endtask : read_data_addr

    task write_data_addr(logic [31:0] addr, logic [1:0] size_i = 2'b10, logic sign_i = 0, logic [31:0] data);
        addr2 = addr;
        we2 = 1;
        din2 = data;
        size = size_i;
        sign = sign_i;
        @(posedge clk iff memValid2);
        read_en2 = 0;
    endtask : write_data_addr


    task read_data_lines();
        int data_addr;
        
        for (int i=0; i<TEST_RUNS; i++) begin
            data_addr = $urandom_range(DATA_MEM_START, MEM_SIZE);
            data_addr = data_addr & 16'hFFFC;
            read_data_addr(data_addr);
            assert (dout2 == expected_memory[addr2 / 4]) else $fatal("TB: Memory read error at addr2 %x, expected1 %x, got %x", addr2, expected_memory[addr2 / 4], dout2);
        end

    endtask : read_data_lines

    task read_entire_Imem();
        for (int i=0; i<INSTR_MEM_SIZE; i++) begin
            for (int j=0; j<WORDS_IN_LINE; j++) begin
                read_instr_addr(i, j[WORD_OFFSET_BITS-1:0]);
                assert (dout1 == expected_memory[addr1 / 4]) else $fatal("Memory read error at addr1 %x in dec %d, expected2 %x, got %x", addr1, addr1 / 4, expected_memory[addr1 / 4], dout1);
            end
        end
        read_en1 = 0;
        addr1 = 16'h0;
    endtask : read_entire_Imem


    // this tests lw 
    task read_entire_Dmem();
        for (int i=INSTR_MEM_SIZE; i < MEM_SIZE >> 2; i++) begin
            for (int j=0; j<4; j++) begin
                read_data_addr(i << 2, 2'b10, 0);
                assert (dout2 == expected_memory[i]) else $fatal("Memory read error at addr2 %x, expected3 %x, got %x", addr2, expected_memory[i], dout2);
            end
        end
        read_en2 = 0;
    endtask : read_entire_Dmem

    // lb, lbu, lh, lhu
    task read_diff_size();

        logic [31:0] expected_word;
        logic [15:0] expected_half_word;
        logic [7:0] expected_byte;

        // lb
        for (int i=0; i<200; i++) begin
            if (i % 4 == 0) expected_word = expected_memory[INSTR_MEM_SIZE + (i >> 2)];
            expected_byte = expected_word[(i % 4) * 8 +: 8];
            read_data_addr((INSTR_MEM_SIZE << 2) + i, 2'b00, 0);
            assert (dout2[7:0] == expected_byte) else $fatal("TB: LB failed Memory read error at addr2 %x, expected_byte %x, got %x", addr2, expected_byte, dout2[7:0]);
        end

        read_en2 = 0;
        ##(3);

        // lh
        for (int i=0; i<200; i++) begin
            if (i % 2 == 0) expected_word = expected_memory[INSTR_MEM_SIZE + (i >> 1)];
            expected_half_word = expected_word[(i % 2) * 16 +: 16];
            read_data_addr((INSTR_MEM_SIZE << 2) + (i << 1), 2'b01, 0);
            assert (dout2[15:0] == expected_half_word) else $fatal("TB: LH failed Memory read error at addr2 %x, expected_half_word %x, got %x", addr2, expected_half_word, dout2[15:0]);
        end

        read_en2 = 0;
        ##(3);

       // lbu
        for (int i=0; i<200; i++) begin
            if (i % 4 == 0) expected_word = expected_memory[INSTR_MEM_SIZE + (i >> 2)];
            read_data_addr((INSTR_MEM_SIZE << 2) + i, 2'b00, 1);
            expected_byte = expected_word[(i % 4) * 8 +: 8];
            assert (dout2[7:0] == expected_byte) else $fatal("TB: LBU failed Memory read error at addr2 %x, expected_byte %x, got %x", addr2, expected_byte, dout2);
        end

        read_en2 = 0;
       ##(3);

       // lhu
        for (int i=0; i<200; i++) begin
            if (i % 2 == 0) expected_word = expected_memory[INSTR_MEM_SIZE + (i >> 1)];
            read_data_addr((INSTR_MEM_SIZE << 2) + (i << 1), 2'b01, 1);
            expected_half_word = expected_word[(i % 2) * 16 +: 16];
            assert (dout2[15:0] == expected_half_word) else $fatal("TB: LBU failed Memory read error at addr2 %x, expected_half_word %x, got %x", addr2, expected_half_word, dout2[15:0]);
        end

        read_en2 = 0;
    endtask : read_diff_size


    task writeback();
        logic [BYTE_OFFSET_BITS-1:0] byte_offset = 0;
        logic [WORD_OFFSET_BITS-1:0] word_offset = 0;
        logic [INDEX_BITS-1:0] index_offset = 0;
        localparam tag_bits = 32 - INDEX_BITS - WORD_OFFSET_BITS - BYTE_OFFSET_BITS;
        logic [tag_bits-1:0] tag = 0;
        logic [tag_bits-1:0] data_tag_start = 'h18;
        logic [31:0] expected_data;

        // cold start
        tag = 0;
        for (int i=0; i<WORDS_IN_LINE; i++) begin
            write_data_addr({tag + data_tag_start, index_offset, i[WORD_OFFSET_BITS-1:0], byte_offset}, 2'b10, 0, i + 1);
        end
        we2 = 0;

        // fill 2nd set
        @(posedge clk);
        tag = 1;
        for (int i=0; i<WORDS_IN_LINE; i++) begin
            write_data_addr({tag + data_tag_start, index_offset, i[WORD_OFFSET_BITS-1:0], byte_offset}, 2'b10, 0, i * 2 + 1);
        end
        we2 = 0;

        // overwrite 1st set        
        @(posedge clk);
        tag = 2;
        for (int i=0; i<WORDS_IN_LINE; i++) begin
            write_data_addr({tag + data_tag_start, index_offset, i[WORD_OFFSET_BITS-1:0], byte_offset}, 2'b10, 0, i * 3 + 1);
        end
        we2 = 0;

        // check if data was written back by bringing back the 1st set
        @(posedge clk);
        din2 = 32'hdead_beef;
        tag = 0;
        
        for (int j=0; j<WORDS_IN_LINE; j++) begin
            read_data_addr({tag + data_tag_start, index_offset, j[WORD_OFFSET_BITS-1:0], byte_offset}, 2'b10, 0);
            expected_data = j + 1;
            assert (dout2 == expected_data) else $fatal("TB: Writeback failed Memory read error at addr2 %x, expected_data %x, got %x", addr2, expected_data, dout2);
        end

    endtask : writeback
    
    // read imem and dmem at same time
    task read_both_mem();
        logic [31:0] expected_data, expected_instr;

        for (int i=0; i<TEST_RUNS; i++) begin
            read_instr_addr(i, i[WORD_OFFSET_BITS-1:0]);
            read_data_addr((INSTR_MEM_SIZE + i) << 2, 2'b10, 0);
            read_en1 = 1;
            read_en2 = 1;
            @(posedge clk iff memValid1 && memValid2);
            expected_instr = expected_memory[i];
            expected_data = expected_memory[INSTR_MEM_SIZE + i];
            assert (dout1 == expected_instr) else $fatal("TB: Memory read error at addr1 %x, expected_instr %x, got %x", addr1, expected_instr, dout1);
            assert (dout2 == expected_data) else $fatal("TB: Memory read error at addr2 %x, expected_data %x, got %x", addr2, expected_data, dout2);
        end

        read_en1 = 0;
        read_en2 = 0;
    endtask : read_both_mem

    initial begin
        reset_cache();
        $display("Starting test...");
 
        read_instr_lines();
        $display("INSTR line by line read test passed");

        ##(3);
        reset_cache();
        read_data_lines();
        $display("DATA line by line read test passed");
        
        ##(3);
        reset_cache();
        read_entire_Imem();
        $display("Entire Imem read test passed");

        ##(3);
        reset_cache();
        read_entire_Dmem();      
        $display("Entire Dmem read test passed");

        ##(3);
        reset_cache();
        read_diff_size();
        $display("Different size read test passed");

        ##(3);
        reset_cache();
        read_both_mem();
        $display("Read both mem test passed");

        ##(3);
        reset_cache();
        writeback();
        $display("Writeback test passed");

        ##(3);
        $display("Test finished");
        $finish;
    end


endmodule