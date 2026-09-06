`timescale 1ns / 1ps

module control (
    input  wire        clk,
    input  wire        rst_n,

    // Memory Bus
    input  wire [7:0]  din,
    output reg  [15:0] addr,
    output reg         we,
    output reg  [7:0]  dout,

    // Datapath Status
    input  wire [15:0] pc,
    input  wire [7:0]  a,
    input  wire [7:0]  x,
    input  wire [7:0]  y,
    input  wire [7:0]  sp,
    input  wire [7:0]  p_pushed,
    input  wire        flag_n,
    input  wire        flag_z,
    input  wire        flag_c,
    input  wire        flag_v,

    input  wire [7:0]  alu_out,

    // Datapath Controls
    output reg         load_a,
    output reg         load_x,
    output reg         load_y,
    output reg         load_sp,
    output reg         inc_sp,
    output reg         dec_sp,
    output reg         inc_x,
    output reg         dec_x,
    output reg         inc_y,
    output reg         dec_y,

    output reg         inc_pc,
    output reg         load_pcl,
    output reg         load_pch,
    output reg         branch_pc,
    output reg  [7:0]  branch_offset,
    output reg  [15:0] pc_din16,
    output reg         load_pc16,

    output reg         load_p,
    output reg         update_nz,
    output reg         update_c,
    output reg         update_v,
    output reg         set_c, clr_c,
    output reg         set_i, clr_i,
    output reg         set_d, clr_d,
    output reg         clr_v,
    output reg         load_bit_flags,

    output reg  [7:0]  alu_a_in,
    output reg  [3:0]  alu_op,
    output reg  [7:0]  alu_b_in,
    output reg  [7:0]  reg_din
);

    // ALU Operations
    localparam ALU_ORA  = 4'd0;
    localparam ALU_AND  = 4'd1;
    localparam ALU_EOR  = 4'd2;
    localparam ALU_ADC  = 4'd3;
    localparam ALU_SBC  = 4'd4;
    localparam ALU_CMP  = 4'd5;
    localparam ALU_ASL  = 4'd6;
    localparam ALU_LSR  = 4'd7;
    localparam ALU_ROL  = 4'd8;
    localparam ALU_ROR  = 4'd9;
    localparam ALU_PASS = 4'd10;
    localparam ALU_DEC  = 4'd11;
    localparam ALU_INC  = 4'd12;

    // Opcodes
    localparam OP_BRK  = 8'h00; localparam OP_RTI  = 8'h40;
    localparam OP_NOP  = 8'hEA;
    localparam OP_CLC  = 8'h18; localparam OP_SEC  = 8'h38;
    localparam OP_CLI  = 8'h58; localparam OP_SEI  = 8'h78;
    localparam OP_CLD  = 8'hD8; localparam OP_SED  = 8'hF8;
    localparam OP_CLV  = 8'hB8;
    localparam OP_TAX  = 8'hAA; localparam OP_TXA  = 8'h8A;
    localparam OP_TAY  = 8'hA8; localparam OP_TYA  = 8'h98;
    localparam OP_TSX  = 8'hBA; localparam OP_TXS  = 8'h9A;
    localparam OP_INX  = 8'hE8; localparam OP_DEX  = 8'hCA;
    localparam OP_INY  = 8'hC8; localparam OP_DEY  = 8'h88;

    localparam OP_ASL_A = 8'h0A; localparam OP_LSR_A = 8'h4A;
    localparam OP_ROL_A = 8'h2A; localparam OP_ROR_A = 8'h6A;

    localparam OP_PHP  = 8'h08; localparam OP_PLP  = 8'h28;
    localparam OP_PHA  = 8'h48; localparam OP_PLA  = 8'h68;
    localparam OP_JSR  = 8'h20; localparam OP_RTS  = 8'h60;
    localparam OP_JMP  = 8'h4C; localparam OP_JMP_IND = 8'h6C;

    localparam OP_LDA_IMM = 8'hA9; localparam OP_LDX_IMM = 8'hA2; localparam OP_LDY_IMM = 8'hA0;
    localparam OP_ADC_IMM = 8'h69; localparam OP_SBC_IMM = 8'hE9;
    localparam OP_AND_IMM = 8'h29; localparam OP_ORA_IMM = 8'h09; localparam OP_EOR_IMM = 8'h49;
    localparam OP_CMP_IMM = 8'hC9; localparam OP_CPX_IMM = 8'hE0; localparam OP_CPY_IMM = 8'hC0;

    localparam OP_LDA_ZP  = 8'hA5; localparam OP_LDX_ZP  = 8'hA6; localparam OP_LDY_ZP  = 8'hA4;
    localparam OP_STA_ZP  = 8'h85; localparam OP_STX_ZP  = 8'h86; localparam OP_STY_ZP  = 8'h84;
    localparam OP_ADC_ZP  = 8'h65; localparam OP_SBC_ZP  = 8'hE5;
    localparam OP_AND_ZP  = 8'h25; localparam OP_ORA_ZP  = 8'h05; localparam OP_EOR_ZP  = 8'h45;
    localparam OP_CMP_ZP  = 8'hC5; localparam OP_CPX_ZP  = 8'hE4; localparam OP_CPY_ZP  = 8'hC4;
    localparam OP_BIT_ZP  = 8'h24;

    localparam OP_INC_ZP  = 8'hE6; localparam OP_DEC_ZP  = 8'hC6;
    localparam OP_ASL_ZP  = 8'h06; localparam OP_LSR_ZP  = 8'h46;
    localparam OP_ROL_ZP  = 8'h26; localparam OP_ROR_ZP  = 8'h66;

    localparam OP_LDA_ZPX = 8'hB5; localparam OP_STA_ZPX = 8'h95;
    localparam OP_LDY_ZPX = 8'hB4; localparam OP_STY_ZPX = 8'h94;
    localparam OP_LDX_ZPY = 8'hB6; localparam OP_STX_ZPY = 8'h96;
    localparam OP_ADC_ZPX = 8'h75; localparam OP_SBC_ZPX = 8'hF5;
    localparam OP_AND_ZPX = 8'h35; localparam OP_ORA_ZPX = 8'h15; localparam OP_EOR_ZPX = 8'h55;
    localparam OP_CMP_ZPX = 8'hD5;

    localparam OP_LDA_INDY = 8'hB1; localparam OP_STA_INDY = 8'h91;
    localparam OP_ADC_INDY = 8'h71; localparam OP_SBC_INDY = 8'hF1;
    localparam OP_AND_INDY = 8'h31; localparam OP_ORA_INDY = 8'h11; localparam OP_EOR_INDY = 8'h51;
    localparam OP_CMP_INDY = 8'hD1;

    localparam OP_LDA_INDX = 8'hA1; localparam OP_STA_INDX = 8'h81;
    localparam OP_ADC_INDX = 8'h61; localparam OP_SBC_INDX = 8'hE1;
    localparam OP_AND_INDX = 8'h21; localparam OP_ORA_INDX = 8'h01; localparam OP_EOR_INDX = 8'h41;
    localparam OP_CMP_INDX = 8'hC1;

    localparam OP_LDA_ABS = 8'hAD; localparam OP_STA_ABS = 8'h8D;
    localparam OP_LDX_ABS = 8'hAE; localparam OP_STX_ABS = 8'h8E;
    localparam OP_LDY_ABS = 8'hAC; localparam OP_STY_ABS = 8'h8C;
    localparam OP_ADC_ABS = 8'h6D; localparam OP_SBC_ABS = 8'hED;
    localparam OP_AND_ABS = 8'h2D; localparam OP_ORA_ABS = 8'h0D; localparam OP_EOR_ABS = 8'h4D;
    localparam OP_CMP_ABS = 8'hCD; localparam OP_CPX_ABS = 8'hEC; localparam OP_CPY_ABS = 8'hCC;
    localparam OP_BIT_ABS = 8'h2C;

    localparam OP_LDA_ABX = 8'hBD; localparam OP_STA_ABX = 8'h9D; localparam OP_LDY_ABX = 8'hBC;
    localparam OP_ADC_ABX = 8'h7D; localparam OP_SBC_ABX = 8'hFD;
    localparam OP_AND_ABX = 8'h3D; localparam OP_ORA_ABX = 8'h1D; localparam OP_EOR_ABX = 8'h5D;
    localparam OP_CMP_ABX = 8'hDD;

    localparam OP_LDA_ABY = 8'hB9; localparam OP_STA_ABY = 8'h99; localparam OP_LDX_ABY = 8'hBE;
    localparam OP_ADC_ABY = 8'h79; localparam OP_SBC_ABY = 8'hF9;
    localparam OP_AND_ABY = 8'h39; localparam OP_ORA_ABY = 8'h19; localparam OP_EOR_ABY = 8'h59;
    localparam OP_CMP_ABY = 8'hD9;

    localparam OP_INC_ABS = 8'hEE; localparam OP_DEC_ABS = 8'hCE;
    localparam OP_ASL_ABS = 8'h0E; localparam OP_LSR_ABS = 8'h4E;
    localparam OP_ROL_ABS = 8'h2E; localparam OP_ROR_ABS = 8'h6E;

    // Registers & Sequencer
    reg [7:0] ir;
    reg [2:0] step;
    reg [2:0] rst_step;
    reg       in_reset;
    reg       end_of_instruction;

    reg [7:0] addr_low;
    reg [7:0] addr_high;
    reg [7:0] ptr_low;
    reg [7:0] ptr_high;
    reg [7:0] rmw_data;

    wire is_branch = (ir[4:0] == 5'b10000);
    reg  branch_cond_met;
    always @(*) begin
        case (ir[7:6])
            2'b00: branch_cond_met = (flag_n == ir[5]);
            2'b01: branch_cond_met = (flag_v == ir[5]);
            2'b10: branch_cond_met = (flag_c == ir[5]);
            2'b11: branch_cond_met = (flag_z == ir[5]);
        endcase
    end

    reg [3:0] rmw_alu_op;
    always @(*) begin
        case (ir)
            OP_INC_ZP, OP_INC_ABS:           rmw_alu_op = ALU_INC;
            OP_DEC_ZP, OP_DEC_ABS:           rmw_alu_op = ALU_DEC;
            OP_ASL_ZP, OP_ASL_ABS, OP_ASL_A: rmw_alu_op = ALU_ASL;
            OP_LSR_ZP, OP_LSR_ABS, OP_LSR_A: rmw_alu_op = ALU_LSR;
            OP_ROL_ZP, OP_ROL_ABS, OP_ROL_A: rmw_alu_op = ALU_ROL;
            OP_ROR_ZP, OP_ROR_ABS, OP_ROR_A: rmw_alu_op = ALU_ROR;
            default:                         rmw_alu_op = ALU_PASS;
        endcase
    end

    wire is_shift_rot = (ir == OP_ASL_ZP || ir == OP_ASL_ABS || ir == OP_ASL_A ||
                         ir == OP_LSR_ZP || ir == OP_LSR_ABS || ir == OP_LSR_A ||
                         ir == OP_ROL_ZP || ir == OP_ROL_ABS || ir == OP_ROL_A ||
                         ir == OP_ROR_ZP || ir == OP_ROR_ABS || ir == OP_ROR_A);

    // Sequential Bus Capture & Step Advancement
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_reset  <= 1'b1;
            rst_step  <= 3'd0;
            step      <= 3'd0;
            ir        <= OP_NOP;
            addr_low  <= 8'h00;
            addr_high <= 8'h00;
            ptr_low   <= 8'h00;
            ptr_high  <= 8'h00;
            rmw_data  <= 8'h00;
        end else if (in_reset) begin
            if (rst_step == 3'd7) begin
                in_reset <= 1'b0;
                step     <= 3'd0;
            end else begin
                rst_step <= rst_step + 1'b1;
            end
        end else begin
            if (step == 3'd0) begin
                ir   <= din;
                step <= 3'd1;
            end else if (end_of_instruction) begin
                step <= 3'd0;
            end else begin
                step <= step + 1'b1;
            end

            case (step)
                3'd1: addr_low <= din;
                3'd2: begin
                    addr_high <= din;
                    ptr_low   <= din;
                    rmw_data  <= din;
                end
                3'd3: begin
                    ptr_high <= din;
                    rmw_data <= din;
                end
                3'd4: begin
                    if (ir == OP_JSR) addr_high <= din;
                end
                default: ;
            endcase
        end
    end

    // Combinational Decoding
    always @(*) begin
        addr               = pc;
        we                 = 1'b0;
        dout               = 8'h00;
        load_a             = 1'b0;
        load_x             = 1'b0;
        load_y             = 1'b0;
        load_sp            = 1'b0;
        inc_sp             = 1'b0;
        dec_sp             = 1'b0;
        inc_x              = 1'b0;
        dec_x              = 1'b0;
        inc_y              = 1'b0;
        dec_y              = 1'b0;
        inc_pc             = 1'b0;
        load_pcl           = 1'b0;
        load_pch           = 1'b0;
        branch_pc          = 1'b0;
        branch_offset      = 8'h00;
        pc_din16           = 16'h0000;
        load_pc16          = 1'b0;
        load_p             = 1'b0;
        update_nz          = 1'b0;
        update_c           = 1'b0;
        update_v           = 1'b0;
        set_c              = 1'b0; clr_c = 1'b0;
        set_i              = 1'b0; clr_i = 1'b0;
        set_d              = 1'b0; clr_d = 1'b0;
        clr_v              = 1'b0;
        load_bit_flags     = 1'b0;
        alu_a_in           = a;
        alu_op             = ALU_PASS;
        alu_b_in           = din;
        reg_din            = din;
        end_of_instruction = 1'b0;

        if (in_reset) begin
            case (rst_step)
                3'd0, 3'd1, 3'd2, 3'd3, 3'd4: addr = 16'h0100 | sp;
                3'd5: begin addr = 16'hFFFC; load_pcl = 1'b1; end
                3'd6: begin addr = 16'hFFFD; load_pch = 1'b1; end
                default: ;
            endcase
        end else begin
            case (step)
                // -------------------------------------------------------------
                // T0: Instruction Fetch
                // -------------------------------------------------------------
                3'd0: begin
                    addr   = pc;
                    inc_pc = 1'b1;
                end

                // -------------------------------------------------------------
                // T1: Decode / Immediate / Operand Low Fetch
                // -------------------------------------------------------------
                3'd1: begin
                    if (is_branch) begin
                        addr          = pc;
                        branch_offset = din;
                        inc_pc        = 1'b1;
                        if (branch_cond_met) branch_pc = 1'b1;
                        end_of_instruction = 1'b1;
                    end else begin
                        case (ir)
                            OP_NOP: end_of_instruction = 1'b1;
                            OP_CLC: begin clr_c = 1'b1; end_of_instruction = 1'b1; end
                            OP_SEC: begin set_c = 1'b1; end_of_instruction = 1'b1; end
                            OP_CLI: begin clr_i = 1'b1; end_of_instruction = 1'b1; end
                            OP_SEI: begin set_i = 1'b1; end_of_instruction = 1'b1; end
                            OP_CLD: begin clr_d = 1'b1; end_of_instruction = 1'b1; end
                            OP_SED: begin set_d = 1'b1; end_of_instruction = 1'b1; end
                            OP_CLV: begin clr_v = 1'b1; end_of_instruction = 1'b1; end

                            OP_TAX: begin reg_din = a;  load_x  = 1'b1; update_nz = 1'b1; alu_b_in = a;  end_of_instruction = 1'b1; end
                            OP_TXA: begin reg_din = x;  load_a  = 1'b1; update_nz = 1'b1; alu_b_in = x;  end_of_instruction = 1'b1; end
                            OP_TAY: begin reg_din = a;  load_y  = 1'b1; update_nz = 1'b1; alu_b_in = a;  end_of_instruction = 1'b1; end
                            OP_TYA: begin reg_din = y;  load_a  = 1'b1; update_nz = 1'b1; alu_b_in = y;  end_of_instruction = 1'b1; end
                            OP_TSX: begin reg_din = sp; load_x  = 1'b1; update_nz = 1'b1; alu_b_in = sp; end_of_instruction = 1'b1; end
                            OP_TXS: begin reg_din = x;  load_sp = 1'b1; alu_b_in = x;                     end_of_instruction = 1'b1; end

                            OP_INX: begin inc_x = 1'b1; end_of_instruction = 1'b1; end
                            OP_DEX: begin dec_x = 1'b1; end_of_instruction = 1'b1; end
                            OP_INY: begin inc_y = 1'b1; end_of_instruction = 1'b1; end
                            OP_DEY: begin dec_y = 1'b1; end_of_instruction = 1'b1; end

                            OP_ASL_A, OP_LSR_A, OP_ROL_A, OP_ROR_A: begin
                                alu_op             = rmw_alu_op;
                                alu_b_in           = a;
                                load_a             = 1'b1;
                                update_nz          = 1'b1;
                                update_c           = 1'b1;
                                end_of_instruction = 1'b1;
                            end

                            OP_LDA_IMM: begin addr = pc; reg_din = din; load_a = 1'b1; update_nz = 1'b1; inc_pc = 1'b1; end_of_instruction = 1'b1; end
                            OP_LDX_IMM: begin addr = pc; reg_din = din; load_x = 1'b1; update_nz = 1'b1; inc_pc = 1'b1; end_of_instruction = 1'b1; end
                            OP_LDY_IMM: begin addr = pc; reg_din = din; load_y = 1'b1; update_nz = 1'b1; inc_pc = 1'b1; end_of_instruction = 1'b1; end
                            OP_ADC_IMM: begin addr = pc; alu_op = ALU_ADC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; inc_pc = 1'b1; end_of_instruction = 1'b1; end
                            OP_SBC_IMM: begin addr = pc; alu_op = ALU_SBC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; inc_pc = 1'b1; end_of_instruction = 1'b1; end
                            OP_AND_IMM: begin addr = pc; alu_op = ALU_AND; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; inc_pc = 1'b1; end_of_instruction = 1'b1; end
                            OP_ORA_IMM: begin addr = pc; alu_op = ALU_ORA; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; inc_pc = 1'b1; end_of_instruction = 1'b1; end
                            OP_EOR_IMM: begin addr = pc; alu_op = ALU_EOR; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; inc_pc = 1'b1; end_of_instruction = 1'b1; end
                            OP_CMP_IMM: begin addr = pc; alu_op = ALU_CMP; alu_a_in = a; alu_b_in = din; update_nz = 1'b1; update_c = 1'b1; inc_pc = 1'b1; end_of_instruction = 1'b1; end
                            OP_CPX_IMM: begin addr = pc; alu_op = ALU_CMP; alu_a_in = x; alu_b_in = din; update_nz = 1'b1; update_c = 1'b1; inc_pc = 1'b1; end_of_instruction = 1'b1; end
                            OP_CPY_IMM: begin addr = pc; alu_op = ALU_CMP; alu_a_in = y; alu_b_in = din; update_nz = 1'b1; update_c = 1'b1; inc_pc = 1'b1; end_of_instruction = 1'b1; end

                            OP_LDA_ZP, OP_LDX_ZP, OP_LDY_ZP, OP_STA_ZP, OP_STX_ZP, OP_STY_ZP,
                            OP_ADC_ZP, OP_SBC_ZP, OP_AND_ZP, OP_ORA_ZP, OP_EOR_ZP, OP_BIT_ZP,
                            OP_CMP_ZP, OP_CPX_ZP, OP_CPY_ZP,
                            OP_INC_ZP, OP_DEC_ZP, OP_ASL_ZP, OP_LSR_ZP, OP_ROL_ZP, OP_ROR_ZP,
                            OP_LDA_ZPX, OP_STA_ZPX, OP_LDY_ZPX, OP_STY_ZPX, OP_LDX_ZPY, OP_STX_ZPY,
                            OP_ADC_ZPX, OP_SBC_ZPX, OP_AND_ZPX, OP_ORA_ZPX, OP_EOR_ZPX, OP_CMP_ZPX,
                            OP_LDA_INDY, OP_STA_INDY, OP_ADC_INDY, OP_SBC_INDY, OP_AND_INDY, OP_ORA_INDY, OP_EOR_INDY, OP_CMP_INDY,
                            OP_LDA_INDX, OP_STA_INDX, OP_ADC_INDX, OP_SBC_INDX, OP_AND_INDX, OP_ORA_INDX, OP_EOR_INDX, OP_CMP_INDX,
                            OP_JMP, OP_JMP_IND, OP_LDA_ABS, OP_STA_ABS, OP_LDX_ABS, OP_STX_ABS, OP_LDY_ABS, OP_STY_ABS,
                            OP_ADC_ABS, OP_SBC_ABS, OP_AND_ABS, OP_ORA_ABS, OP_EOR_ABS, OP_CMP_ABS, OP_CPX_ABS, OP_CPY_ABS, OP_BIT_ABS,
                            OP_LDA_ABX, OP_STA_ABX, OP_LDY_ABX, OP_ADC_ABX, OP_SBC_ABX, OP_AND_ABX, OP_ORA_ABX, OP_EOR_ABX, OP_CMP_ABX,
                            OP_LDA_ABY, OP_STA_ABY, OP_LDX_ABY, OP_ADC_ABY, OP_SBC_ABY, OP_AND_ABY, OP_ORA_ABY, OP_EOR_ABY, OP_CMP_ABY,
                            OP_INC_ABS, OP_DEC_ABS, OP_ASL_ABS, OP_LSR_ABS, OP_ROL_ABS, OP_ROR_ABS: begin
                                addr   = pc;
                                inc_pc = 1'b1;
                            end

                            OP_PHA: begin addr = 16'h0100 | sp; dout = a;        we = 1'b1; dec_sp = 1'b1; end_of_instruction = 1'b1; end
                            OP_PHP: begin addr = 16'h0100 | sp; dout = p_pushed; we = 1'b1; dec_sp = 1'b1; end_of_instruction = 1'b1; end
                            OP_PLA, OP_PLP, OP_RTS, OP_RTI: inc_sp = 1'b1;
                            OP_JSR, OP_BRK: begin addr = pc; inc_pc = 1'b1; end

                            default: end_of_instruction = 1'b1;
                        endcase
                    end
                end

                // -------------------------------------------------------------
                // T2: Zero Page Exec / Stack Pops / Addr High Fetch
                // -------------------------------------------------------------
                3'd2: begin
                    case (ir)
                        OP_LDA_ZP: begin addr = {8'h00, addr_low}; reg_din = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_LDX_ZP: begin addr = {8'h00, addr_low}; reg_din = din; load_x = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_LDY_ZP: begin addr = {8'h00, addr_low}; reg_din = din; load_y = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_ADC_ZP: begin addr = {8'h00, addr_low}; alu_op = ALU_ADC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; end_of_instruction = 1'b1; end
                        OP_SBC_ZP: begin addr = {8'h00, addr_low}; alu_op = ALU_SBC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; end_of_instruction = 1'b1; end
                        OP_AND_ZP: begin addr = {8'h00, addr_low}; alu_op = ALU_AND; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_ORA_ZP: begin addr = {8'h00, addr_low}; alu_op = ALU_ORA; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_EOR_ZP: begin addr = {8'h00, addr_low}; alu_op = ALU_EOR; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_CMP_ZP: begin addr = {8'h00, addr_low}; alu_op = ALU_CMP; alu_a_in = a; alu_b_in = din; update_nz = 1'b1; update_c = 1'b1; end_of_instruction = 1'b1; end
                        OP_CPX_ZP: begin addr = {8'h00, addr_low}; alu_op = ALU_CMP; alu_a_in = x; alu_b_in = din; update_nz = 1'b1; update_c = 1'b1; end_of_instruction = 1'b1; end
                        OP_CPY_ZP: begin addr = {8'h00, addr_low}; alu_op = ALU_CMP; alu_a_in = y; alu_b_in = din; update_nz = 1'b1; update_c = 1'b1; end_of_instruction = 1'b1; end
                        OP_BIT_ZP: begin addr = {8'h00, addr_low}; load_bit_flags = 1'b1; end_of_instruction = 1'b1; end

                        OP_STA_ZP: begin addr = {8'h00, addr_low}; we = 1'b1; dout = a; end_of_instruction = 1'b1; end
                        OP_STX_ZP: begin addr = {8'h00, addr_low}; we = 1'b1; dout = x; end_of_instruction = 1'b1; end
                        OP_STY_ZP: begin addr = {8'h00, addr_low}; we = 1'b1; dout = y; end_of_instruction = 1'b1; end

                        OP_INC_ZP, OP_DEC_ZP, OP_ASL_ZP, OP_LSR_ZP, OP_ROL_ZP, OP_ROR_ZP: begin
                            addr = {8'h00, addr_low};
                        end

                        OP_LDA_ZPX: begin addr = {8'h00, addr_low + x}; reg_din = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_STA_ZPX: begin addr = {8'h00, addr_low + x}; we = 1'b1; dout = a; end_of_instruction = 1'b1; end
                        OP_LDY_ZPX: begin addr = {8'h00, addr_low + x}; reg_din = din; load_y = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_STY_ZPX: begin addr = {8'h00, addr_low + x}; we = 1'b1; dout = y; end_of_instruction = 1'b1; end
                        OP_ADC_ZPX: begin addr = {8'h00, addr_low + x}; alu_op = ALU_ADC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; end_of_instruction = 1'b1; end
                        OP_SBC_ZPX: begin addr = {8'h00, addr_low + x}; alu_op = ALU_SBC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; end_of_instruction = 1'b1; end
                        OP_AND_ZPX: begin addr = {8'h00, addr_low + x}; alu_op = ALU_AND; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_ORA_ZPX: begin addr = {8'h00, addr_low + x}; alu_op = ALU_ORA; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_EOR_ZPX: begin addr = {8'h00, addr_low + x}; alu_op = ALU_EOR; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_CMP_ZPX: begin addr = {8'h00, addr_low + x}; alu_op = ALU_CMP; alu_a_in = a; alu_b_in = din; update_nz = 1'b1; update_c = 1'b1; end_of_instruction = 1'b1; end

                        OP_LDX_ZPY: begin addr = {8'h00, addr_low + y}; reg_din = din; load_x = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_STX_ZPY: begin addr = {8'h00, addr_low + y}; we = 1'b1; dout = x; end_of_instruction = 1'b1; end

                        OP_LDA_INDY, OP_STA_INDY, OP_ADC_INDY, OP_SBC_INDY, OP_AND_INDY, OP_ORA_INDY, OP_EOR_INDY, OP_CMP_INDY: begin
                            addr = {8'h00, addr_low};
                        end
                        OP_LDA_INDX, OP_STA_INDX, OP_ADC_INDX, OP_SBC_INDX, OP_AND_INDX, OP_ORA_INDX, OP_EOR_INDX, OP_CMP_INDX: begin
                            addr = {8'h00, addr_low + x};
                        end

                        OP_JMP, OP_JMP_IND, OP_LDA_ABS, OP_STA_ABS, OP_LDX_ABS, OP_STX_ABS, OP_LDY_ABS, OP_STY_ABS,
                        OP_ADC_ABS, OP_SBC_ABS, OP_AND_ABS, OP_ORA_ABS, OP_EOR_ABS, OP_CMP_ABS, OP_CPX_ABS, OP_CPY_ABS, OP_BIT_ABS,
                        OP_LDA_ABX, OP_STA_ABX, OP_LDY_ABX, OP_ADC_ABX, OP_SBC_ABX, OP_AND_ABX, OP_ORA_ABX, OP_EOR_ABX, OP_CMP_ABX,
                        OP_LDA_ABY, OP_STA_ABY, OP_LDX_ABY, OP_ADC_ABY, OP_SBC_ABY, OP_AND_ABY, OP_ORA_ABY, OP_EOR_ABY, OP_CMP_ABY,
                        OP_INC_ABS, OP_DEC_ABS, OP_ASL_ABS, OP_LSR_ABS, OP_ROL_ABS, OP_ROR_ABS: begin
                            addr   = pc;
                            inc_pc = 1'b1;
                        end

                        // Stack Pulls (Execute directly in T2 while addressing the stack)
                        OP_PLA: begin
                            addr               = 16'h0100 | sp;
                            reg_din            = din;
                            load_a             = 1'b1;
                            alu_op             = ALU_PASS;
                            alu_b_in           = din;
                            update_nz          = 1'b1;
                            end_of_instruction = 1'b1;
                        end

                        OP_PLP: begin
                            addr               = 16'h0100 | sp;
                            reg_din            = din;
                            load_p             = 1'b1;
                            end_of_instruction = 1'b1;
                        end

                        // RTS: Latch PCL, advance SP to point to PCH
                        OP_RTS: begin
                            addr     = 16'h0100 | sp;
                            reg_din  = din;
                            load_pcl = 1'b1;
                            inc_sp   = 1'b1;
                        end

                        // RTI: Latch P, advance SP to point to PCL
                        OP_RTI: begin
                            addr     = 16'h0100 | sp;
                            reg_din  = din;
                            load_p   = 1'b1;
                            inc_sp   = 1'b1;
                        end

                        // JSR & BRK: Push PCH to stack
                        OP_JSR, OP_BRK: begin
                            addr   = 16'h0100 | sp;
                            dout   = pc[15:8];
                            we     = 1'b1;
                            dec_sp = 1'b1;
                        end

                        default: end_of_instruction = 1'b1;
                    endcase
                end

                // -------------------------------------------------------------
                // T3: Absolute Exec / Subroutine Push PCL / Latch PCH
                // -------------------------------------------------------------
                3'd3: begin
                    case (ir)
                        OP_JMP: begin
                            pc_din16           = {addr_high, addr_low};
                            load_pc16          = 1'b1;
                            end_of_instruction = 1'b1;
                        end

                        OP_JMP_IND: begin
                            addr = {addr_high, addr_low};
                        end

                        OP_LDA_ABS: begin addr = {addr_high, addr_low}; reg_din = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_LDX_ABS: begin addr = {addr_high, addr_low}; reg_din = din; load_x = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_LDY_ABS: begin addr = {addr_high, addr_low}; reg_din = din; load_y = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_STA_ABS: begin addr = {addr_high, addr_low}; we = 1'b1; dout = a; end_of_instruction = 1'b1; end
                        OP_STX_ABS: begin addr = {addr_high, addr_low}; we = 1'b1; dout = x; end_of_instruction = 1'b1; end
                        OP_STY_ABS: begin addr = {addr_high, addr_low}; we = 1'b1; dout = y; end_of_instruction = 1'b1; end
                        OP_ADC_ABS: begin addr = {addr_high, addr_low}; alu_op = ALU_ADC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; end_of_instruction = 1'b1; end
                        OP_SBC_ABS: begin addr = {addr_high, addr_low}; alu_op = ALU_SBC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; end_of_instruction = 1'b1; end
                        OP_AND_ABS: begin addr = {addr_high, addr_low}; alu_op = ALU_AND; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_ORA_ABS: begin addr = {addr_high, addr_low}; alu_op = ALU_ORA; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_EOR_ABS: begin addr = {addr_high, addr_low}; alu_op = ALU_EOR; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_CMP_ABS: begin addr = {addr_high, addr_low}; alu_op = ALU_CMP; alu_a_in = a; alu_b_in = din; update_nz = 1'b1; update_c = 1'b1; end_of_instruction = 1'b1; end
                        OP_CPX_ABS: begin addr = {addr_high, addr_low}; alu_op = ALU_CMP; alu_a_in = x; alu_b_in = din; update_nz = 1'b1; update_c = 1'b1; end_of_instruction = 1'b1; end
                        OP_CPY_ABS: begin addr = {addr_high, addr_low}; alu_op = ALU_CMP; alu_a_in = y; alu_b_in = din; update_nz = 1'b1; update_c = 1'b1; end_of_instruction = 1'b1; end
                        OP_BIT_ABS: begin addr = {addr_high, addr_low}; load_bit_flags = 1'b1; end_of_instruction = 1'b1; end

                        OP_LDA_ABX: begin addr = {addr_high, addr_low} + x; reg_din = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_STA_ABX: begin addr = {addr_high, addr_low} + x; we = 1'b1; dout = a; end_of_instruction = 1'b1; end
                        OP_LDY_ABX: begin addr = {addr_high, addr_low} + x; reg_din = din; load_y = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_ADC_ABX: begin addr = {addr_high, addr_low} + x; alu_op = ALU_ADC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; end_of_instruction = 1'b1; end
                        OP_SBC_ABX: begin addr = {addr_high, addr_low} + x; alu_op = ALU_SBC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; end_of_instruction = 1'b1; end
                        OP_AND_ABX: begin addr = {addr_high, addr_low} + x; alu_op = ALU_AND; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_ORA_ABX: begin addr = {addr_high, addr_low} + x; alu_op = ALU_ORA; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_EOR_ABX: begin addr = {addr_high, addr_low} + x; alu_op = ALU_EOR; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_CMP_ABX: begin addr = {addr_high, addr_low} + x; alu_op = ALU_CMP; alu_a_in = a; alu_b_in = din; update_nz = 1'b1; update_c = 1'b1; end_of_instruction = 1'b1; end

                        OP_LDA_ABY: begin addr = {addr_high, addr_low} + y; reg_din = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_STA_ABY: begin addr = {addr_high, addr_low} + y; we = 1'b1; dout = a; end_of_instruction = 1'b1; end
                        OP_LDX_ABY: begin addr = {addr_high, addr_low} + y; reg_din = din; load_x = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_ADC_ABY: begin addr = {addr_high, addr_low} + y; alu_op = ALU_ADC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; end_of_instruction = 1'b1; end
                        OP_SBC_ABY: begin addr = {addr_high, addr_low} + y; alu_op = ALU_SBC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; end_of_instruction = 1'b1; end
                        OP_AND_ABY: begin addr = {addr_high, addr_low} + y; alu_op = ALU_AND; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_ORA_ABY: begin addr = {addr_high, addr_low} + y; alu_op = ALU_ORA; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_EOR_ABY: begin addr = {addr_high, addr_low} + y; alu_op = ALU_EOR; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_CMP_ABY: begin addr = {addr_high, addr_low} + y; alu_op = ALU_CMP; alu_a_in = a; alu_b_in = din; update_nz = 1'b1; update_c = 1'b1; end_of_instruction = 1'b1; end

                        OP_INC_ABS, OP_DEC_ABS, OP_ASL_ABS, OP_LSR_ABS, OP_ROL_ABS, OP_ROR_ABS: begin
                            addr = {addr_high, addr_low};
                        end

                        OP_INC_ZP, OP_DEC_ZP, OP_ASL_ZP, OP_LSR_ZP, OP_ROL_ZP, OP_ROR_ZP: begin
                            addr = {8'h00, addr_low};
                            we   = 1'b1;
                            dout = rmw_data;
                        end

                        OP_LDA_INDY, OP_STA_INDY, OP_ADC_INDY, OP_SBC_INDY, OP_AND_INDY, OP_ORA_INDY, OP_EOR_INDY, OP_CMP_INDY: begin
                            addr = {8'h00, addr_low + 8'd1};
                        end
                        OP_LDA_INDX, OP_STA_INDX, OP_ADC_INDX, OP_SBC_INDX, OP_AND_INDX, OP_ORA_INDX, OP_EOR_INDX, OP_CMP_INDX: begin
                            addr = {8'h00, addr_low + x + 8'd1};
                        end

                        // JSR & BRK: Push PCL to stack
                        OP_JSR, OP_BRK: begin
                            addr   = 16'h0100 | sp;
                            dout   = pc[7:0];
                            we     = 1'b1;
                            dec_sp = 1'b1;
                        end

                        // RTS: Latch PCH directly from stack
                        OP_RTS: begin
                            addr     = 16'h0100 | sp;
                            reg_din  = din;
                            load_pch = 1'b1;
                        end

                        // RTI: Latch PCL, advance SP to point to PCH
                        OP_RTI: begin
                            addr     = 16'h0100 | sp;
                            reg_din  = din;
                            load_pcl = 1'b1;
                            inc_sp   = 1'b1;
                        end

                        default: end_of_instruction = 1'b1;
                    endcase
                end

                // -------------------------------------------------------------
                // T4: RMW Writeback / JSR Addr High Fetch / BRK Push P
                // -------------------------------------------------------------
                3'd4: begin
                    case (ir)
                        OP_INC_ZP, OP_DEC_ZP, OP_ASL_ZP, OP_LSR_ZP, OP_ROL_ZP, OP_ROR_ZP: begin
                            addr               = {8'h00, addr_low};
                            we                 = 1'b1;
                            dout               = alu_out;
                            alu_op             = rmw_alu_op;
                            alu_b_in           = rmw_data;
                            update_nz          = 1'b1;
                            if (is_shift_rot) update_c = 1'b1;
                            end_of_instruction = 1'b1;
                        end

                        OP_INC_ABS, OP_DEC_ABS, OP_ASL_ABS, OP_LSR_ABS, OP_ROL_ABS, OP_ROR_ABS: begin
                            addr = {addr_high, addr_low};
                            we   = 1'b1;
                            dout = rmw_data;
                        end

                        OP_JMP_IND: begin
                            reg_din  = din;
                            load_pcl = 1'b1;
                            addr     = {addr_high, addr_low + 8'd1};
                        end

                        OP_LDA_INDY: begin addr = {ptr_high, ptr_low} + y; reg_din = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_STA_INDY: begin addr = {ptr_high, ptr_low} + y; we = 1'b1; dout = a; end_of_instruction = 1'b1; end
                        OP_ADC_INDY: begin addr = {ptr_high, ptr_low} + y; alu_op = ALU_ADC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; end_of_instruction = 1'b1; end
                        OP_SBC_INDY: begin addr = {ptr_high, ptr_low} + y; alu_op = ALU_SBC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; end_of_instruction = 1'b1; end
                        OP_AND_INDY: begin addr = {ptr_high, ptr_low} + y; alu_op = ALU_AND; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_ORA_INDY: begin addr = {ptr_high, ptr_low} + y; alu_op = ALU_ORA; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_EOR_INDY: begin addr = {ptr_high, ptr_low} + y; alu_op = ALU_EOR; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_CMP_INDY: begin addr = {ptr_high, ptr_low} + y; alu_op = ALU_CMP; alu_a_in = a; alu_b_in = din; update_nz = 1'b1; update_c = 1'b1; end_of_instruction = 1'b1; end

                        OP_LDA_INDX: begin addr = {ptr_high, ptr_low}; reg_din = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_STA_INDX: begin addr = {ptr_high, ptr_low}; we = 1'b1; dout = a; end_of_instruction = 1'b1; end
                        OP_ADC_INDX: begin addr = {ptr_high, ptr_low}; alu_op = ALU_ADC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; end_of_instruction = 1'b1; end
                        OP_SBC_INDX: begin addr = {ptr_high, ptr_low}; alu_op = ALU_SBC; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; update_c = 1'b1; update_v = 1'b1; end_of_instruction = 1'b1; end
                        OP_AND_INDX: begin addr = {ptr_high, ptr_low}; alu_op = ALU_AND; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_ORA_INDX: begin addr = {ptr_high, ptr_low}; alu_op = ALU_ORA; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_EOR_INDX: begin addr = {ptr_high, ptr_low}; alu_op = ALU_EOR; alu_a_in = a; alu_b_in = din; load_a = 1'b1; update_nz = 1'b1; end_of_instruction = 1'b1; end
                        OP_CMP_INDX: begin addr = {ptr_high, ptr_low}; alu_op = ALU_CMP; alu_a_in = a; alu_b_in = din; update_nz = 1'b1; update_c = 1'b1; end_of_instruction = 1'b1; end

                        // JSR: Fetch destination high byte
                        OP_JSR: addr = pc;

                        // RTS: Increment return address by 1 (NMOS standard)
                        OP_RTS: begin
                            inc_pc             = 1'b1;
                            end_of_instruction = 1'b1;
                        end

                        // RTI: Latch PCH directly from stack
                        OP_RTI: begin
                            addr               = 16'h0100 | sp;
                            reg_din            = din;
                            load_pch           = 1'b1;
                            end_of_instruction = 1'b1;
                        end

                        // BRK: Push P register to stack
                        OP_BRK: begin
                            addr   = 16'h0100 | sp;
                            dout   = p_pushed;
                            we     = 1'b1;
                            dec_sp = 1'b1;
                            set_i  = 1'b1;
                        end

                        default: end_of_instruction = 1'b1;
                    endcase
                end

                // -------------------------------------------------------------
                // T5: JSR Vector Jump / Absolute RMW Writeback
                // -------------------------------------------------------------
                3'd5: begin
                    case (ir)
                        OP_INC_ABS, OP_DEC_ABS, OP_ASL_ABS, OP_LSR_ABS, OP_ROL_ABS, OP_ROR_ABS: begin
                            addr               = {addr_high, addr_low};
                            we                 = 1'b1;
                            dout               = alu_out;
                            alu_op             = rmw_alu_op;
                            alu_b_in           = rmw_data;
                            update_nz          = 1'b1;
                            if (is_shift_rot) update_c = 1'b1;
                            end_of_instruction = 1'b1;
                        end

                        OP_JMP_IND: begin
                            reg_din            = din;
                            load_pch           = 1'b1;
                            end_of_instruction = 1'b1;
                        end

                        OP_JSR: begin
                            pc_din16           = {addr_high, addr_low};
                            load_pc16          = 1'b1;
                            end_of_instruction = 1'b1;
                        end

                        // BRK: Read PCL from $FFFE
                        OP_BRK: begin
                            addr     = 16'hFFFE;
                            load_pcl = 1'b1;
                        end

                        default: end_of_instruction = 1'b1;
                    endcase
                end

                // -------------------------------------------------------------
                // T6: BRK Vector High Fetch
                // -------------------------------------------------------------
                3'd6: begin
                    case (ir)
                        OP_BRK: begin
                            addr               = 16'hFFFF;
                            load_pch           = 1'b1;
                            end_of_instruction = 1'b1;
                        end
                        default: end_of_instruction = 1'b1;
                    endcase
                end

                default: end_of_instruction = 1'b1;
            endcase
        end
    end

endmodule
