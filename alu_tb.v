`timescale 1ns / 1ps

module alu_tb;
    reg  [7:0] a, b;
    reg        cin;
    reg  [3:0] op;
    wire [7:0] out;
    wire       cout, overflow, zero, negative;

    alu dut (
        .a(a),
        .b(b),
        .cin(cin),
        .op(op),
        .out(out),
        .cout(cout),
        .overflow(overflow),
        .zero(zero),
        .negative(negative)
    );

    initial begin
        $dumpfile("alu.vcd");
        $dumpvars(0, alu_tb);

        // Test 1: Simple Addition ($20 + $15, Cin = 0)
        a = 8'h20; b = 8'h15; cin = 0; op = 4'd3; #10;
        if (out !== 8'h35 || cout !== 0 || zero !== 0 || negative !== 0 || overflow !== 0)
            $display("[FAIL] ADC simple addition failed");

        // Test 2: Addition with Carry Out ($80 + $90, Cin = 0)
        a = 8'h80; b = 8'h90; cin = 0; op = 4'd3; #10;
        if (out !== 8'h10 || cout !== 1)
            $display("[FAIL] ADC carry-out failed");

        // Test 3: Signed Overflow ($7F + $01 = $80 -> +127 + 1 = -128)
        a = 8'h7F; b = 8'h01; cin = 0; op = 4'd3; #10;
        if (overflow !== 1 || negative !== 1)
            $display("[FAIL] ADC signed overflow (V) flag failed");

        // Test 4: Subtraction No Borrow ($05 - $03, Cin = 1) -> Result $02, Cout = 1
        a = 8'h05; b = 8'h03; cin = 1; op = 4'd4; #10;
        if (out !== 8'h02 || cout !== 1)
            $display("[FAIL] SBC no-borrow failed");

        // Test 5: Subtraction With Borrow ($03 - $05, Cin = 1) -> Result $FE, Cout = 0
        a = 8'h03; b = 8'h05; cin = 1; op = 4'd4; #10;
        if (out !== 8'hFE || cout !== 0 || negative !== 1)
            $display("[FAIL] SBC borrow failed");

        // Test 6: Zero Flag Test ($05 - $05, Cin = 1)
        a = 8'h05; b = 8'h05; cin = 1; op = 4'd4; #10;
        if (out !== 8'h00 || zero !== 1)
            $display("[FAIL] Zero flag failed");

        // Test 7: Shift Left (ASL $81) -> $02, Cout = 1
        a = 8'h81; b = 8'h00; cin = 0; op = 4'd6; #10;
        if (out !== 8'h02 || cout !== 1)
            $display("[FAIL] ASL shift failed");

        $display("All ALU tests executed.");
        $finish;
    end
endmodule
