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

    task read();
        for (int i = 0; i < 8; i++) begin
            read_addr(addr);
            for (int j = 0; j < 8; j++) begin
                read_en = 1;
                addr += 4;
                $display("Read %x from %x", dout, addr);
                @(posedge clk);
            end
        end

        read_en = 0;
        addr = 32'hdead_beef;
    endtask : read

    initial begin
        reset_cache();

        $display("Starting test...");
        read();

        ##(3);
        $display("Test finished");
        $finish;
    end


endmodule