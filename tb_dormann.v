`timescale 1ns / 1ps

module tb_dormann;

    reg         clk;
    reg         rst_n;
    wire [15:0] addr;
    wire [7:0]  dout;
    wire        we;
    reg  [7:0]  din;

    // Full 64 KB RAM space
    reg [7:0] memory [0:65535];

    reg [63:0] cycle_count;
    reg [15:0] last_fetch_pc;
    integer    loop_count;

    cpu_6502 dut (
        .clk   (clk),
        .rst_n (rst_n),
        .addr  (addr),
        .din   (din),
        .dout  (dout),
        .we    (we)
    );

    always #5 clk = ~clk;

    always @(*) din = memory[addr];

    always @(posedge clk) begin
        if (we) memory[addr] <= dout;
    end

    // Monitor Progress and Trap Pass/Fail Loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count   <= 0;
            last_fetch_pc <= 16'hFFFF;
            loop_count    <= 0;
        end else begin
            cycle_count <= cycle_count + 1;

            // Heartbeat ticker every 2,000,000 cycles
            if ((cycle_count % 2000000) == 0) begin
                $display("[%0d cycles] PC at: $%04h (executing...)", cycle_count, dut.u_registers.pc);
            end

            // Detect spin loop on opcode fetch
            if (!dut.u_control.in_reset && (dut.u_control.step == 3'd0)) begin
                if (addr == last_fetch_pc) begin
                    loop_count <= loop_count + 1;
                end else begin
                    loop_count    <= 0;
                    last_fetch_pc <= addr;
                end

                if (loop_count >= 5) begin
                    $display("\n==================================================");
                    if (addr == 16'h3469) begin
                        $display(" >>> KLAUS DORMANN 6502 TEST PASSED! <<<");
                        $display(" Trapped at Success Address: $3469");
                    end else begin
                        $display(" >>> KLAUS DORMANN TEST FAILED! <<<");
                        $display(" Trapped at Failing Subtest PC: $%04h", addr);
                        $display(" (Check 6502_functional_test.lst for address $%04h)", addr);
                    end
                    $display(" Total Cycles: %0d", cycle_count);
                    $display("==================================================\n");
                    $finish;
                end
            end
        end
    end

    initial begin
        // Clear memory
        for (integer i = 0; i < 65536; i = i + 1) begin
            memory[i] = 8'h00;
        end

        // Load 64 KB test image
        $display("Loading 6502_dormann.hex...");
        $readmemh("6502_dormann.hex", memory, 16'h0000, 16'hFFFF);

        // Klaus Dormann tests begin execution at $0400.
        // Set the reset vector ($FFFC/$FFFD) to point to $0400:
        memory[16'hFFFC] = 8'h00;
        memory[16'hFFFD] = 8'h04;

        clk   = 0;
        rst_n = 0;
        #20;
        rst_n = 1;
    end

endmodule
