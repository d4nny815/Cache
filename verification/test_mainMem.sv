module mm_tb ();
    logic clk;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    default clocking tb_clk @(posedge clk); endclocking

    logic we = 0;
    logic reset = 0;
    logic [13:0] addr = 0;
    logic [31:0] instr;
    logic [31:0] instr_buffer [7:0];
    logic memValid;


    MainMemory #(.DELAY_BITS(3)) DUT (
        .RST                (reset),
        .MEM_CLK            (clk),
        .MEM_RDEN1          (1'b1),     // read enable Instruction
        .MEM_RDEN2          (0),     // read enable data
        .MEM_WE2            (0),     // write enable.
        .MEM_ADDR1          (addr),     // Instruction Memory word Addr (Connect to PC[15:2])
        .MEM_ADDR2          (0),     // Data Memory Addr
        .MEM_DIN2           (0),     // Data to save
        .MEM_SIZE           (0),     // 0-Byte, 1-Half, 2-Word
        .MEM_SIGN           (0),     // 1-unsigned 0-signed
        .MEM_DOUT1          (instr),     // Instruction
        .MEM_DOUT2          (),     // Data
        .memValid1          (memValid)
    );

    task reset_l1();
        reset = 1;
        ##(2);
        reset = 0;
    endtask : reset_l1


    task read_line();
        for (int i = 0; i < 8; i++) begin
            addr = i;
            @(posedge memValid);
            instr_buffer[i] = instr;
        end
    endtask : read_line

    initial begin
        reset_l1();

        $display("Starting test...");
        read_line();

        ##(3);
        $display("Checking lines...");
        // check_lines();


        ##(3);
        $display("Test finished");
        $finish;
    end


endmodule