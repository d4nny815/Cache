module cache_tb ();
    logic clk;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    default clocking tb_clk @(posedge clk); endclocking



    logic we = 0;
    logic reset = 0;
    logic read_en = 0;
    logic [15:0] addr = 0;
    logic [31:0] dout;
    logic memValid;

    Memory #(.DELAY_BITS(3)) DUT (
        .MEM_CLK        (clk),
        .RST            (reset),
        .MEM_RDEN1      (read_en),        
        .MEM_RDEN2      (),        
        .MEM_WE2        (),        
        .MEM_ADDR1      (addr[15:2]),        
        .MEM_ADDR2      (),        
        .MEM_DIN2       (),        
        .MEM_SIZE       (),        
        .MEM_SIGN       (),        
        .MEM_DOUT1      (dout),        
        .MEM_DOUT2      (),        
        .memValid1      (memValid)
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

    task read_addr(logic [10:0] base_addr, logic [2:0] word_offset);
        addr = {base_addr, word_offset, 2'b0};
        read_en = 1;
        @(posedge clk iff memValid);
        read_en = 0;
    endtask : read_addr

    task read_lines();
        int TEST_RUNS = 100;
        int WORDS_IN_LINE = 8;

        logic [10:0] word_addr;
        for (int i=0; i<TEST_RUNS; i++) begin
            word_addr = $random;
            for (int word_offset = 0; word_offset < WORDS_IN_LINE; word_offset++) begin
                read_addr(word_addr, word_offset[2:0]);
                assert (dout == expected_memory[addr / 4]) else $fatal("Memory read error at addr %x, expected %x, got %x", addr, expected_memory[addr / 4], dout);
            end
        end

        read_en = 0;
        addr = 16'hbeef;
    endtask : read_lines

    task read_random_addr();
        int TEST_RUNS = 100;
        for (int i=0; i<TEST_RUNS; i++) begin
            read_addr($random, $random % 8);
            assert (dout == expected_memory[addr / 4]) else $fatal("Memory read error at addr %x, expected %x, got %x", addr, expected_memory[addr / 4], dout);
        end
        read_en = 0;
        addr = 16'hbeef;
    endtask : read_random_addr

    task read_entire_Imem();
        int addr_lines = 14;
        for (int i=0; i < 2 ** addr_lines; i++) begin
            addr = i << 2;
            read_en = 1;
            @(posedge clk iff memValid);
            assert (dout == expected_memory[i]) else $fatal("Memory read error at addr %x, expected %x, got %x", addr, expected_memory[i], dout);
        end
        
        read_en = 0;
        addr = 16'hbeef;
    endtask : read_entire_Imem


    initial begin
        reset_cache();
        $display("Starting test...");

        read_lines();
        $display("line by line read test passed");

        ##(3);
        read_random_addr();
        $display("random addr test passed");

        ##(3);
        read_entire_Imem();
        $display("Entire Imem read test passed");

        ##(3);
        $display("Test finished");
        $finish;
    end


endmodule