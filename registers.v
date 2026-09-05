`timescale 1ns / 1ps

module registers (
    input  wire        clk,
    input  wire        rst_n,

    // Common Data Input
    input  wire [7:0]  din,

    // Register Load & Counter Controls
    input  wire        load_a,
    input  wire        load_x,
    input  wire        load_y,
    input  wire        load_sp,
    input  wire        inc_sp,
    input  wire        dec_sp,
    input  wire        inc_x,
    input  wire        dec_x,
    input  wire        inc_y,
    input  wire        dec_y,

    // Program Counter Controls
    input  wire        inc_pc,
    input  wire        load_pcl,
    input  wire        load_pch,
    input  wire        branch_pc,
    input  wire [7:0]  branch_offset,

    // Status Register (P) Individual Controls
    input  wire        load_p,
    input  wire        update_nz,
    input  wire        update_c,
    input  wire        update_v,
    input  wire        set_c, clr_c,
    input  wire        set_i, clr_i,
    input  wire        set_d, clr_d,
    input  wire        clr_v,
    input  wire        load_bit_flags, // Specialized latch for BIT instruction

    // ALU Flag Inputs
    input  wire        alu_n,
    input  wire        alu_z,
    input  wire        alu_c,
    input  wire        alu_v,

    // B-Flag Value for stack push
    input  wire        b_flag_val,

    // Register Outputs
    output reg  [7:0]  a,
    output reg  [7:0]  x,
    output reg  [7:0]  y,
    output reg  [7:0]  sp,
    output reg  [15:0] pc,
    output wire [7:0]  p_pushed,
    
    // Direct Flag Outputs
    output wire        flag_n,
    output wire        flag_v,
    output wire        flag_d,
    output wire        flag_i,
    output wire        flag_z,
    output wire        flag_c
);

    reg n_reg, v_reg, d_reg, i_reg, z_reg, c_reg;

    assign flag_n = n_reg;
    assign flag_v = v_reg;
    assign flag_d = d_reg;
    assign flag_i = i_reg;
    assign flag_z = z_reg;
    assign flag_c = c_reg;

    assign p_pushed = {n_reg, v_reg, 1'b1, b_flag_val, d_reg, i_reg, z_reg, c_reg};

    // -------------------------------------------------------------------------
    // Accumulator, X, Y, and SP
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a  <= 8'h00;
            x  <= 8'h00;
            y  <= 8'h00;
            sp <= 8'hFD;
        end else begin
            if (load_a) a <= din;

            if (load_x)      x <= din;
            else if (inc_x)  x <= x + 1'b1;
            else if (dec_x)  x <= x - 1'b1;

            if (load_y)      y <= din;
            else if (inc_y)  y <= y + 1'b1;
            else if (dec_y)  y <= y - 1'b1;

            if (load_sp)     sp <= din;
            else if (inc_sp) sp <= sp + 1'b1;
            else if (dec_sp) sp <= sp - 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // Program Counter
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 16'h0000;
        end else begin
            if (load_pcl) begin
                pc[7:0] <= din;
            end else if (load_pch) begin
                pc[15:8] <= din;
            end else if (branch_pc) begin
                pc <= pc + 16'd1 + {{8{branch_offset[7]}}, branch_offset};
            end else if (inc_pc) begin
                pc <= pc + 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Status Register (P) Logic
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            n_reg <= 1'b0;
            v_reg <= 1'b0;
            d_reg <= 1'b0;
            i_reg <= 1'b1;
            z_reg <= 1'b0;
            c_reg <= 1'b0;
        end else if (load_p) begin
            n_reg <= din[7];
            v_reg <= din[6];
            d_reg <= din[3];
            i_reg <= din[2];
            z_reg <= din[1];
            c_reg <= din[0];
        end else if (load_bit_flags) begin
            // BIT instruction: N=mem[7], V=mem[6], Z=(A & mem == 0)
            n_reg <= din[7];
            v_reg <= din[6];
            z_reg <= ((a & din) == 8'h00);
        end else begin
            // N and Z update rules
            if (update_nz) begin
                n_reg <= alu_n;
                z_reg <= alu_z;
            end else if (inc_x) begin
                n_reg <= (x + 1'b1) >= 8'h80;
                z_reg <= (x + 1'b1) == 8'h00;
            end else if (dec_x) begin
                n_reg <= (x - 1'b1) >= 8'h80;
                z_reg <= (x - 1'b1) == 8'h00;
            end else if (inc_y) begin
                n_reg <= (y + 1'b1) >= 8'h80;
                z_reg <= (y + 1'b1) == 8'h00;
            end else if (dec_y) begin
                n_reg <= (y - 1'b1) >= 8'h80;
                z_reg <= (y - 1'b1) == 8'h00;
            end

            // Carry Flag (C)
            if (set_c)         c_reg <= 1'b1;
            else if (clr_c)    c_reg <= 1'b0;
            else if (update_c) c_reg <= alu_c;

            // Overflow Flag (V)
            if (clr_v)         v_reg <= 1'b0;
            else if (update_v) v_reg <= alu_v;

            // Interrupt Flag (I)
            if (set_i)         i_reg <= 1'b1;
            else if (clr_i)    i_reg <= 1'b0;

            // Decimal Flag (D)
            if (set_d)         d_reg <= 1'b1;
            else if (clr_d)    d_reg <= 1'b0;
        end
    end

endmodule
