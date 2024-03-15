module cl_tb ();
    logic clk;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    default clocking tb_clk @(posedge clk); endclocking

    logic we = 0;
    logic reset = 0;
    logic next = 0;
    logic [31:0] addr_i = 0;
    logic [31:0] data_i = 0;
    
    logic [31:0] addr_o;
    logic [31:0] data_o;
    logic full;

    CacheLineAdapter DUT (
        .clk            (clk),
        .clr            (reset),
        .addr_i         (addr_i),
        .data_i         (data_i),
        .we             (we),
        .next           (next),
        .addr_o         (addr_o),
        .data_o         (data_o),
        .full           (full)
    );

    task reset_cl();
        reset = 1;
        ##(2);
        reset = 0;
    endtask : reset_cl


    task fill_CL();
        logic [2:0] s_clk = 0;  
        int i = 0;
        while (i < 8) begin
            we = 1;
            addr_i = i;
            data_i = 32'hffff_ffff - i;
            if (s_clk[2] == 1) begin
                $display("Writing %x to %x", data_i, addr_i);
                next = 1;
                i += 1;
                s_clk = 0;
            end
            else
                next = 0;
            @(posedge clk);
            s_clk += 1;
        end

        assert (full == 1) else $display("Error: CacheLineAdapter is not full");
        data_i = 32'hdead_beef;
        we = 0;
    endtask : fill_CL

    initial begin
        reset_cl();

        $display("Starting test...");
        fill_CL();


        ##(3);
        $display("Test finished");
        $finish;
    end


endmodule