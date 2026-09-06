`timescale 1ns / 1ps

module cpu_6502 (
    input  wire        clk,
    input  wire        rst_n,

    // External Memory & Bus Interface
    output wire [15:0] addr,
    input  wire [7:0]  din,
    output wire [7:0]  dout,
    output wire        we
);

    wire [15:0] pc;
    wire [7:0]  reg_a, reg_x, reg_y, reg_sp, p_pushed;
    wire        flag_n, flag_v, flag_d, flag_i, flag_z, flag_c;

    wire        load_a, load_x, load_y, load_sp;
    wire        inc_sp, dec_sp, inc_x, dec_x, inc_y, dec_y;
    wire        inc_pc, load_pcl, load_pch, branch_pc;
    wire [7:0]  branch_offset;

    wire        load_p, update_nz, update_c, update_v;
    wire        set_c, clr_c, set_i, clr_i, set_d, clr_d, clr_v, load_bit_flags;
    wire [15:0] ctrl_pc_din16;
    wire        ctrl_load_pc16;
    wire [3:0]  alu_op;
    wire [7:0]  alu_b_in;
    wire [7:0]  ctrl_reg_din;
    wire [7:0]  alu_a_in;
    wire [7:0]  alu_out;
    wire        alu_cout, alu_overflow, alu_zero, alu_negative;

    wire [7:0]  reg_din = (load_pcl || load_pch) ? ctrl_reg_din : alu_out;

    alu u_alu (
        .a        (alu_a_in),
        .b        (alu_b_in),
        .cin      (flag_c),
        .decimal  (flag_d),
        .op       (alu_op),
        .out      (alu_out),
        .cout     (alu_cout),
        .overflow (alu_overflow),
        .zero     (alu_zero),
        .negative (alu_negative)
    );

    registers u_registers (
        .clk            (clk),
        .rst_n          (rst_n),
        .din            (reg_din),
        .pc_din16       (ctrl_pc_din16),
        .load_pc16      (ctrl_load_pc16),
        .load_a         (load_a),
        .load_x         (load_x),
        .load_y         (load_y),
        .load_sp        (load_sp),
        .inc_sp         (inc_sp),
        .dec_sp         (dec_sp),
        .inc_x          (inc_x),
        .dec_x          (dec_x),
        .inc_y          (inc_y),
        .dec_y          (dec_y),
        .inc_pc         (inc_pc),
        .load_pcl       (load_pcl),
        .load_pch       (load_pch),
        .branch_pc      (branch_pc),
        .branch_offset  (branch_offset),
        .load_p         (load_p),
        .update_nz      (update_nz),
        .update_c       (update_c),
        .update_v       (update_v),
        .set_c          (set_c),
        .clr_c          (clr_c),
        .set_i          (set_i),
        .clr_i          (clr_i),
        .set_d          (set_d),
        .clr_d          (clr_d),
        .clr_v          (clr_v),
        .load_bit_flags (load_bit_flags),
        .alu_n          (alu_negative),
        .alu_z          (alu_zero),
        .alu_c          (alu_cout),
        .alu_v          (alu_overflow),
        .a              (reg_a),
        .x              (reg_x),
        .y              (reg_y),
        .sp             (reg_sp),
        .pc             (pc),
        .p_pushed       (p_pushed),
        .flag_n         (flag_n),
        .flag_v         (flag_v),
        .flag_d         (flag_d),
        .flag_i         (flag_i),
        .flag_z         (flag_z),
        .flag_c         (flag_c)
    );

    control u_control (
        .clk            (clk),
        .alu_a_in       (alu_a_in),
        .rst_n          (rst_n),
        .pc_din16       (ctrl_pc_din16),
        .load_pc16      (ctrl_load_pc16),
        .din            (din),
        .addr           (addr),
        .we             (we),
        .dout           (dout),
        .pc             (pc),
        .a              (reg_a),
        .x              (reg_x),
        .y              (reg_y),
        .sp             (reg_sp),
        .p_pushed       (p_pushed),
        .flag_n         (flag_n),
        .flag_z         (flag_z),
        .flag_c         (flag_c),
        .flag_v         (flag_v),
        .alu_out        (alu_out),        // RMW data bus feed
        .load_a         (load_a),
        .load_x         (load_x),
        .load_y         (load_y),
        .load_sp        (load_sp),
        .inc_sp         (inc_sp),
        .dec_sp         (dec_sp),
        .inc_x          (inc_x),
        .dec_x          (dec_x),
        .inc_y          (inc_y),
        .dec_y          (dec_y),
        .inc_pc         (inc_pc),
        .load_pcl       (load_pcl),
        .load_pch       (load_pch),
        .branch_pc      (branch_pc),
        .branch_offset  (branch_offset),
        .load_p         (load_p),
        .update_nz      (update_nz),
        .update_c       (update_c),
        .update_v       (update_v),
        .set_c          (set_c),
        .clr_c          (clr_c),
        .set_i          (set_i),
        .clr_i          (clr_i),
        .set_d          (set_d),
        .clr_d          (clr_d),
        .clr_v          (clr_v),
        .load_bit_flags (load_bit_flags),
        .alu_op         (alu_op),
        .alu_b_in       (alu_b_in),
        .reg_din        (ctrl_reg_din)
    );

endmodule
