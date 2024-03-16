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
        $readmemh("otter_memory.mem", expected_memory, 0, 16383);
    end

    task reset_cache();
        reset = 1;
        ##(2);
        reset = 0;
    endtask : reset_cache

    task read_addr(logic [13:0] addr_i);
        addr = addr_i;
        read_en = 1;
        @(posedge memValid);
    endtask : read_addr

    task test_cache();
        int SETS = 2;
        int TOTAL_LINES = 32;
        int WORDS_IN_LINE = 8;
        int SET_SIZE = WORDS_IN_LINE * TOTAL_LINES;
        
        int start_addr, end_addr;

        for (int fills = 0; fills < 4; fills++) begin
            start_addr = fills * SET_SIZE * SETS;
            end_addr = (fills + 1) * SET_SIZE * SETS;
            for (int i = start_addr / WORDS_IN_LINE; i < end_addr / WORDS_IN_LINE; i++) begin
                addr = i * 4 * 8;
                read_addr(addr);
                for (int j = 0; j < WORDS_IN_LINE; j++) begin
                    read_en = 1;
                    @(posedge clk);
                    addr += 4;
                end
            end

            read_en = 0;
            ##(2);
            
            for (int i = start_addr; i < end_addr ; i++) begin
                read_en = 1;
                addr = i * 4;
                @(posedge clk);
                assert (dout == expected_memory[i]) else $fatal("Memory read error at addr %x, expected %x, got %x", addr, expected_memory[i], dout);
            end
            ##(2);
        end

        read_en = 0;
        addr = 32'hdead_beef;
    endtask : test_cache

    initial begin
        reset_cache();

        $display("Starting test...");
        test_cache();

        ##(3);
        $display("Test finished");
        $finish;
    end


endmodule