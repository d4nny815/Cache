module cache_tb ();
    logic clk;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    default clocking tb_clk @(posedge clk); endclocking

    logic we = 0;
    logic reset = 0;
    logic [13:0] addr = 0;
    logic [31:0] data = 0;
    logic [31:0] dout;


    InstrL1 DUT (
        .clk            (clk),
        .reset          (reset),
        .we             (we),
        .addr           (addr),
        .data           (data),
        .dout           (dout),
        .hit            ()
    );

    task reset_l1();
        reset = 1;
        ##(2);
        reset = 0;
    endtask : reset_l1


    task fill_lines();
        int k;
        for (int i = 0; i < 2 * 32 * 8; i++) begin
            we = 1;
            for (int j = 0; j < 8; j++) begin
                k = i * 377;
                addr = {k[8:0], j[4:0]};
                data = 32'hffff_ffff - (i + 1) * j;
                @(posedge clk);
                // $display("TB: Writing %x to %x with %d, %d, %d", data, addr, i, j, k);
            end
        end
        data = 32'hdead_beef;
        we = 0;
    endtask : fill_lines

    task check_lines();
        for (int i = 0; i < 32; i++) begin
            addr = i;
            assert (dout == 32'hffff_ffff - i) 
            else   $display("Error: Expected %x, got %x @ addr: %x", 32'hffff_ffff - i , dout, addr);
            @(posedge clk);
        end
    endtask : check_lines

    initial begin
        reset_l1();

        $display("Starting test...");
        fill_lines();

        ##(3);
        $display("Checking lines...");
        // check_lines();


        ##(3);
        $display("Test finished");
        $finish;
    end


endmodule