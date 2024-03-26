module mm_tb ();
    logic clk;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    default clocking tb_clk @(posedge clk); endclocking

    logic reset = 0;
    logic we, re, memValid;

    logic [31:0] mem_addr;
    logic [31:0] din, dout;

    logic [31:0] expected_mem [0:2**14-1];
    initial $readmemh("otter_mem.mem", expected_mem, 0, 2**14-1);

    MainMemory #(
        .DELAY_CYCLES(10),
        .BURST_WIDTH(8)
    ) DUT (
        .MEM_CLK        (clk),
        .MEM_RE         (re),        
        .MEM_WE         (we),        
        .MEM_DATA_IN    (din),        
        .MEM_ADDR       (mem_addr[31:2]),        
        .MEM_DOUT       (dout),        
        .memValid       (memValid)
    );

    task dead_mode();
        re = 0;
        we = 0;
        mem_addr = -1;
        din = 32'hdead_beef;
        @(posedge clk);
    endtask : dead_mode

    task read_addr(logic [31:0] addr);
        re = 1;
        we = 0;
        mem_addr = addr;
        @(posedge clk iff memValid);
        re = 0;
    endtask : read_addr

    task write_addr(logic [31:0] addr, logic [31:0] data);
        re = 0;
        we = 1;
        mem_addr = addr;
        din = data;
        @(posedge clk iff memValid);
        we = 0;
    endtask : write_addr

    initial begin

        $display("Starting test...");
        for (int i = 0; i < 10; i++) begin
            read_addr(i << 2);
            assert (dout == expected_mem[i]) else $fatal("Error at address %d, expected: %d, got: %d", i, expected_mem[i], dout);
        end
        $display("delay");

        for (int i = 0; i < 10; i++) begin
            write_addr(i << 2, i);
            read_addr(i << 2);
            assert (dout == i) else $fatal("Error at address %d, expected: %d, got: %d", i, i, dout);
        end

        dead_mode();

        ##(3);
        $display("Test finished");
        $finish;
    end


endmodule