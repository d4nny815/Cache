/*
    instaniate MainMemory
    MainMemory #(
        .DELAY_CYCLES(10),
        .BURST_WIDTH(8)
    ) myMemory (
        .MEM_CLK        (),
        .RST            (),
        .MEM_RE         (),        
        .MEM_WE         (),        
        .MEM_DATA_IN    (),        
        .MEM_ADDR       (),        
        .MEM_DOUT       (),        
        .memValid       ()
    );
*/
 

module MainMemory #(
    parameter DELAY_CYCLES = 10,
    parameter BURST_WIDTH = 8
    ) (
    input MEM_CLK,
    // input RST,
    input MEM_RE,                // read enable Instruction
    input MEM_WE,
    input [31:0] MEM_DATA_IN,          // Data to save
    input [29:0] MEM_ADDR,         // Data Memory Addr
    output logic [31:0] MEM_DOUT,  // Instruction
    output logic memValid
    ); 

    typedef enum logic [1:0] {
        IDLE,
        DELAY,
        BURST
    } state_t;

    state_t state, next_state;

    logic up, rst;

    localparam max_count = $clog2(DELAY_CYCLES) > $clog2(BURST_WIDTH) ? $clog2(DELAY_CYCLES) -1 : $clog2(BURST_WIDTH) - 1;
    logic [max_count:0] count = 0;

    (* rom_style="{distributed | block}" *)
    (* ram_decomp = "power" *) logic [31:0] memory [0:16383];

    initial begin
        $readmemh("otter_mem.mem", memory, 0, 16383);
    end

    always_ff @(posedge MEM_CLK) begin
        if (up)
            count <= count + 1;
        else
            count <= 0;
    end

    always_ff @(posedge MEM_CLK) begin
        state <= next_state;
    end

    always_comb begin
        memValid = 0; up = 0; rst = 0;
        case (state)
            IDLE: begin
                if (MEM_WE | MEM_RE)
                    next_state = DELAY;
            end
            DELAY: begin
                up = MEM_RE | MEM_WE;
                if (!up)
                    next_state = IDLE;
                else if (count == DELAY_CYCLES - 1)
                    next_state = BURST;
                else 
                    next_state = DELAY;
            end
            BURST: begin
                up = 1;
                memValid = 1;
                if (count == BURST_WIDTH - 1)
                    next_state = IDLE;
                else 
                    next_state = BURST;
            end
            default: next_state = IDLE;
        endcase
    end

    always_comb begin
        MEM_DOUT = memValid & MEM_RE ? memory[MEM_ADDR] : 32'hdead_beef;
    end

    always_ff @(negedge MEM_CLK) begin
        if (MEM_WE & memValid)
            memory[MEM_ADDR] <= MEM_DATA_IN;
    end
        
 endmodule