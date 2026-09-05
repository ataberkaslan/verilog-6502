`timescale 1ns / 1ps

module registers_tb;
    reg        clk;
    reg        rst_n;
    reg  [7:0] din;
    reg        load_a, load_x, load_y, load_sp, inc_sp, dec_sp;
    reg        inc_pc, load_pcl, load_pch, branch_pc;
    reg  [7:0] branch_offset;
    reg        load_p, update_nz, update_c, update_v;
    reg        set_c, clr_c, set_i, clr_i, set_d, clr_d, clr_v;
    reg        alu_n, alu_z, alu_c, alu_v;
    reg        b_flag_val;

    wire [7:0]  a, x, y, sp, p_pushed;
    wire [15:0] pc;
    wire        flag_n, flag_v, flag_d, flag_i, flag_z, flag_c;

    registers dut (
        .clk(clk), .rst_n(rst_n), .din(din),
        .load_a(load_a), .load_x(load_x), .load_y(load_y),
        .load_sp(load_sp), .inc_sp(inc_sp), .dec_sp(dec_sp),
        .inc_pc(inc_pc), .load_pcl(load_pcl), .load_pch(load_pch),
        .branch_pc(branch_pc), .branch_offset(branch_offset),
        .load_p(load_p), .update_nz(update_nz), .update_c(update_c), .update_v(update_v),
        .set_c(set_c), .clr_c(clr_c), .set_i(set_i), .clr_i(clr_i),
        .set_d(set_d), .clr_d(clr_d), .clr_v(clr_v),
        .alu_n(alu_n), .alu_z(alu_z), .alu_c(alu_c), .alu_v(alu_v),
        .b_flag_val(b_flag_val),
        .a(a), .x(x), .y(y), .sp(sp), .pc(pc), .p_pushed(p_pushed),
        .flag_n(flag_n), .flag_v(flag_v), .flag_d(flag_d),
        .flag_i(flag_i), .flag_z(flag_z), .flag_c(flag_c)
    );

    // 10ns clock generator (100 MHz)
    always #5 clk = ~clk;

    initial begin
        $dumpfile("registers.vcd");
        $dumpvars(0, registers_tb);

        clk = 0;
        rst_n = 0;
        din = 8'h00;
        load_a = 0; load_x = 0; load_y = 0; load_sp = 0; inc_sp = 0; dec_sp = 0;
        inc_pc = 0; load_pcl = 0; load_pch = 0; branch_pc = 0; branch_offset = 8'h00;
        load_p = 0; update_nz = 0; update_c = 0; update_v = 0;
        set_c = 0; clr_c = 0; set_i = 0; clr_i = 0; set_d = 0; clr_d = 0; clr_v = 0;
        alu_n = 0; alu_z = 0; alu_c = 0; alu_v = 0;
        b_flag_val = 1;

        // Apply Reset
        #15;
        rst_n = 1;
        #10;
        if (sp !== 8'hFD || flag_i !== 1'b1 || pc !== 16'h0000)
            $display("[FAIL] Reset initialization incorrect");

        // Test 1: Load Accumulator, X, and Y
        din = 8'h42; load_a = 1; #10; load_a = 0;
        din = 8'hA5; load_x = 1; #10; load_x = 0;
        din = 8'h5A; load_y = 1; #10; load_y = 0;
        if (a !== 8'h42 || x !== 8'hA5 || y !== 8'h5A)
            $display("[FAIL] Register load failed");

        // Test 2: Stack Pointer Push/Pull modifications
        dec_sp = 1; #10; dec_sp = 0; // Simulate push
        if (sp !== 8'hFC) $display("[FAIL] SP decrement failed");
        inc_sp = 1; #10; inc_sp = 0; // Simulate pull
        if (sp !== 8'hFD) $display("[FAIL] SP increment failed");

        // Test 3: Program Counter Vector Load ($FFFC -> $8000)
        din = 8'h00; load_pcl = 1; #10; load_pcl = 0;
        din = 8'h80; load_pch = 1; #10; load_pch = 0;
        if (pc !== 16'h8000) $display("[FAIL] PC load failed");

        // Test 4: Program Counter Increment
        inc_pc = 1; #10; inc_pc = 0;
        if (pc !== 16'h8001) $display("[FAIL] PC increment failed");

        // Test 5: Relative Branching (-4 bytes displacement)
        branch_offset = -8'd4; // 8'hFC
        branch_pc = 1; #10; branch_pc = 0;
        if (pc !== 16'h7FFD) $display("[FAIL] PC backward branch failed. Expected 7FFD, got %h", pc);

        // Test 6: Flag latches and Stack Representation
        alu_n = 1; alu_z = 0; update_nz = 1;
        set_c = 1;
        #10;
        update_nz = 0; set_c = 0;
        if (flag_n !== 1'b1 || flag_c !== 1'b1) $display("[FAIL] Flag latch failed");
        // Check p_pushed: N=1, V=0, U=1, B=1, D=0, I=1, Z=0, C=1 -> 8'b10110101 (8'hB5)
        if (p_pushed !== 8'hB5) $display("[FAIL] P pushed byte incorrect. Expected B5, got %h", p_pushed);

        $display("Registers test complete.");
        $finish;
    end
endmodule
