`timescale 1ns / 1ps

module cpu_6502_tb;

    reg         clk;
    reg         rst_n;
    wire [15:0] addr;
    wire [7:0]  dout;
    wire        we;
    reg  [7:0]  din;

    // 64 KB Unified RAM/ROM Memory Space
    reg [7:0] memory [0:65535];

    // Command-line parameter storage
    reg [1023:0] hex_file;

    // Simulation metrics & watchdog counters
    reg [63:0] cycle_count;
    reg [15:0] last_fetch_pc;
    integer    loop_detect_count;

    // -------------------------------------------------------------------------
    // Core Instantiation
    // -------------------------------------------------------------------------
    cpu_6502 dut (
        .clk   (clk),
        .rst_n (rst_n),
        .addr  (addr),
        .din   (din),
        .dout  (dout),
        .we    (we)
    );

    // 100 MHz Clock Generation (10ns Period)
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Asynchronous Memory Read & IO Handling
    // -------------------------------------------------------------------------
    always @(*) begin
        if (addr == 16'h5001) begin
            din = 8'b0000_0010; // Bit 1 = Tx Ready
        end else if (addr == 16'h5000) begin
            din = 8'h00;
        end else begin
            din = memory[addr];
        end
    end

    // -------------------------------------------------------------------------
    // Synchronous Memory Write & Character Output Trap
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (we) begin
            if (addr == 16'h5000) begin
                $write("%c", dout);
                $fflush();
            end else begin
                memory[addr] <= dout;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Diagnostic State Dump
    // -------------------------------------------------------------------------
    task print_cpu_state;
        begin
            $display("\n--------------------------------------------------");
            $display(" Final CPU State Dump");
            $display("--------------------------------------------------");
            $display(" PC  : $%04h", dut.u_registers.pc);
            $display(" SP  : $%02h   (Stack: $01%02h)", dut.u_registers.sp, dut.u_registers.sp);
            $display(" A   : $%02h", dut.u_registers.a);
            $display(" X   : $%02h", dut.u_registers.x);
            $display(" Y   : $%02h", dut.u_registers.y);
            $display(" Fib : $%02h (%0d)", memory[16'h0001], memory[16'h0001]);
            $display(" Total Cycles : %0d", cycle_count);
            $display(" Sim Duration : %0t ns", $time);
            $display("--------------------------------------------------\n");
        end
    endtask

    // -------------------------------------------------------------------------
    // Execution Watchdog & Loop Detector
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count       <= 0;
            last_fetch_pc     <= 16'hFFFF;
            loop_detect_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            // Timeout threshold
            if (cycle_count >= 1000000) begin
                $display("\n[SIMULATION TIMEOUT]");
                print_cpu_state();
                $finish;
            end

            // Only monitor loops when out of reset and executing opcode fetch (step 0)
            if (!dut.u_control.in_reset && (dut.u_control.step == 3'd0)) begin
                if (addr == last_fetch_pc) begin
                    loop_detect_count <= loop_detect_count + 1;
                end else begin
                    loop_detect_count <= 0;
                    last_fetch_pc     <= addr;
                end

                // Trap target spin-loop
                if (loop_detect_count >= 3) begin
                    $display("\n[HALT] Target loop trapped at PC: $%04h.", addr);
                    print_cpu_state();
                    $finish;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Test Initialization
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("cpu_6502.vcd");
        $dumpvars(0, cpu_6502_tb);

        // Pre-fill memory space with NOP ($EA) with zero delay
        for (integer i = 0; i < 65536; i = i + 1) begin
            memory[i] = 8'hEA;
        end

        // Dynamically load hex file passed by CLI (+HEX=...) into ROM ($8000 - $FFFF)
        if ($value$plusargs("HEX=%s", hex_file)) begin
            $display("Loading binary image: %0s", hex_file);
            $readmemh(hex_file, memory, 16'h8000, 16'hFFFF);
        end else begin
            $display("Loading default binary: main.hex");
            $readmemh("main.hex", memory, 16'h8000, 16'hFFFF);
        end

        clk   = 0;
        rst_n = 0;

        #20;
        rst_n = 1;
    end

endmodule
