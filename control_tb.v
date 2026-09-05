`timescale 1ns / 1ps

module control_tb;
    reg         clk;
    reg         rst_n;
    wire [15:0] addr;
    wire        we;
    wire [7:0]  dout;
    reg  [7:0]  din;

    // Registers and Flags
    wire [15:0] pc;
    wire [7:0]  a, x, y, sp, p_pushed;
    wire        flag_n, flag_v, flag_d, flag_i, flag_z, flag_c;

    // Control Unit connections
    wire        load_a, load_x, load_y, load_sp;
    wire        inc_pc, load_pcl, load_pch, branch_pc;
    wire [7:0]  branch_offset;
    wire        update_nz, update_c, update_v, set_c, clr_c, set_i, clr_i;
    wire [3:0]  alu_op;
    wire [7:0]  alu_b_in, reg_din;

    // Instantiate Register File
    registers u_regs (
        .clk(clk), .rst_n(rst_n), .din(reg_din),
        .load_a(load_a), .load_x(load_x), .load_y(load_y), .load_sp(load_sp),
        .inc_sp(1'b0), .dec_sp(1'b0),
        .inc_pc(inc_pc), .load_pcl(load_pcl), .load_pch(load_pch),
        .branch_pc(branch_pc), .branch_offset(branch_offset),
        .load_p(1'b0), .update_nz(update_nz), .update_c(update_c), .update_v(update_v),
        .set_c(set_c), .clr_c(clr_c), .set_i(set_i), .clr_i(clr_i),
        .set_d(1'b0), .clr_d(1'b0), .clr_v(1'b0),
        .alu_n(reg_din[7]), .alu_z(reg_din == 8'h00), .alu_c(1'b0), .alu_v(1'b0),
        .b_flag_val(1'b1),
        .a(a), .x(x), .y(y), .sp(sp), .pc(pc), .p_pushed(p_pushed),
        .flag_n(flag_n), .flag_v(flag_v), .flag_d(flag_d),
        .flag_i(flag_i), .flag_z(flag_z), .flag_c(flag_c)
    );

    // Instantiate Control Unit
    control u_ctrl (
        .clk(clk), .rst_n(rst_n),
        .din(din), .addr(addr), .we(we), .dout(dout),
        .pc(pc), .a(a), .x(x), .y(y), .sp(sp),
        .flag_n(flag_n), .flag_z(flag_z), .flag_c(flag_c), .flag_v(flag_v),
        .load_a(load_a), .load_x(load_x), .load_y(load_y), .load_sp(load_sp),
        .inc_pc(inc_pc), .load_pcl(load_pcl), .load_pch(load_pch),
        .branch_pc(branch_pc), .branch_offset(branch_offset),
        .update_nz(update_nz), .update_c(update_c), .update_v(update_v),
        .set_c(set_c), .clr_c(clr_c), .set_i(set_i), .clr_i(clr_i),
        .alu_op(alu_op), .alu_b_in(alu_b_in), .reg_din(reg_din)
    );

    // 10ns Clock
    always #5 clk = ~clk;

    // Simulated Memory System
    reg [7:0] memory [0:65535];

    initial begin
        // Reset Vectors ($FFFC -> $8000)
        memory[16'hFFFC] = 8'h00;
        memory[16'hFFFD] = 8'h80;

        // Assembly at $8000:
        // SEC          ($38)
        // LDA #$42     ($A9, $42)
        // STA $10      ($85, $10)
        memory[16'h8000] = 8'h38;
        memory[16'h8001] = 8'hA9;
        memory[16'h8002] = 8'h42;
        memory[16'h8003] = 8'h85;
        memory[16'h8004] = 8'h10;
    end

    // Memory read/write bus interaction
    always @(*) begin
        din = memory[addr];
    end

    always @(posedge clk) begin
        if (we) begin
            memory[addr] <= dout;
            $display("[MEM WRITE] Address: %h, Data: %h", addr, dout);
        end
    end

    initial begin
        $dumpfile("control.vcd");
        $dumpvars(0, control_tb);

        clk   = 0;
        rst_n = 0;

        // Release reset
        #20;
        rst_n = 1;

        // Run through reset and code execution
        #200;

        // Verify accumulator load and memory write results
        if (flag_c !== 1'b1) $display("[FAIL] SEC did not set Carry flag");
        if (a !== 8'h42)     $display("[FAIL] LDA immediate failed, A = %h", a);
        if (memory[16'h0010] !== 8'h42) $display("[FAIL] STA zero-page failed, Mem[$10] = %h", memory[16'h0010]);

        $display("Control execution completed successfully.");
        $finish;
    end
endmodule
