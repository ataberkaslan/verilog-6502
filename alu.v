`timescale 1ns / 1ps

module alu (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       cin,
    input  wire       decimal,
    input  wire [3:0] op,
    output reg  [7:0] out,
    output reg        cout,
    output reg        overflow,
    output wire       zero,
    output wire       negative
);

    localparam OP_ORA  = 4'd0;
    localparam OP_AND  = 4'd1;
    localparam OP_EOR  = 4'd2;
    localparam OP_ADC  = 4'd3;
    localparam OP_SBC  = 4'd4;
    localparam OP_CMP  = 4'd5;
    localparam OP_ASL  = 4'd6;
    localparam OP_LSR  = 4'd7;
    localparam OP_ROL  = 4'd8;
    localparam OP_ROR  = 4'd9;
    localparam OP_PASS = 4'd10;
    localparam OP_DEC  = 4'd11;
    localparam OP_INC  = 4'd12;

    wire [7:0] b_inv = ~b;

    wire [8:0] sum_bin  = a + b + cin;
    wire [8:0] diff_bin = a + b_inv + cin;

    wire adc_v = (a[7] == b[7]) && (sum_bin[7] != a[7]);
    wire sbc_v = (a[7] != b[7]) && (diff_bin[7] != a[7]);

    // NMOS Decimal Mode
    wire [4:0] adc_lo = a[3:0] + b[3:0] + cin;
    wire       adc_lo_adj = (adc_lo > 4'd9);
    wire [3:0] adc_lo_nib = adc_lo_adj ? (adc_lo[3:0] + 4'd6) : adc_lo[3:0];

    wire [4:0] adc_hi = a[7:4] + b[7:4] + (adc_lo_adj ? 1'b1 : adc_lo[4]);
    wire       adc_hi_adj = (adc_hi > 4'd9);
    wire [3:0] adc_hi_nib = adc_hi_adj ? (adc_hi[3:0] + 4'd6) : adc_hi[3:0];

    wire [4:0] sbc_lo = a[3:0] - b[3:0] - (~cin);
    wire       sbc_lo_adj = sbc_lo[4];
    wire [3:0] sbc_lo_nib = sbc_lo_adj ? (sbc_lo[3:0] - 4'd6) : sbc_lo[3:0];

    wire [4:0] sbc_hi = a[7:4] - b[7:4] - (sbc_lo_adj ? 1'b1 : 1'b0);
    wire       sbc_hi_adj = sbc_hi[4];
    wire [3:0] sbc_hi_nib = sbc_hi_adj ? (sbc_hi[3:0] - 4'd6) : sbc_hi[3:0];

    always @(*) begin
        out      = 8'h00;
        cout     = cin;
        overflow = 1'b0;

        case (op)
            OP_ORA:  out = a | b;
            OP_AND:  out = a & b;
            OP_EOR:  out = a ^ b;

            OP_ADC: begin
                overflow = adc_v;
                if (decimal) begin
                    out  = {adc_hi_nib, adc_lo_nib};
                    cout = adc_hi_adj;
                end else begin
                    out  = sum_bin[7:0];
                    cout = sum_bin[8];
                end
            end

            OP_SBC, OP_CMP: begin
                overflow = sbc_v;
                if (decimal && (op == OP_SBC)) begin
                    out  = {sbc_hi_nib, sbc_lo_nib};
                    cout = ~sbc_hi_adj;
                end else begin
                    out  = diff_bin[7:0];
                    cout = diff_bin[8];
                end
            end

            // Unary shifts, rotates, increments, and decrements operate on b
            OP_ASL: begin
                out  = {b[6:0], 1'b0};
                cout = b[7];
            end

            OP_LSR: begin
                out  = {1'b0, b[7:1]};
                cout = b[0];
            end

            OP_ROL: begin
                out  = {b[6:0], cin};
                cout = b[7];
            end

            OP_ROR: begin
                out  = {cin, b[7:1]};
                cout = b[0];
            end

            OP_PASS: out = b;
            OP_DEC:  out = b - 1'b1;
            OP_INC:  out = b + 1'b1;

            default: ;
        endcase
    end

    assign zero     = (out == 8'h00);
    assign negative = out[7];

endmodule
