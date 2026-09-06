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
    output reg        zero,
    output reg        negative
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

    wire [7:0] b_inv   = ~b;
    wire       cmp_cin = (op == OP_CMP) ? 1'b1 : cin;

    // -------------------------------------------------------------------------
    // Binary Arithmetic & Flags
    // -------------------------------------------------------------------------
    wire [8:0] sum_bin  = a + b + cin;
    wire [8:0] diff_bin = a + b_inv + cmp_cin;

    wire adc_v = (a[7] == b[7]) && (sum_bin[7] != a[7]);
    wire sbc_v = (a[7] != b[7]) && (diff_bin[7] != a[7]);

    // -------------------------------------------------------------------------
    // NMOS 6502 Decimal Mode Logic (Bruce Clark Specification)
    // -------------------------------------------------------------------------
    // Decimal ADC
    wire [4:0] adc_al     = a[3:0] + b[3:0] + cin;
    wire       adc_al_adj = (adc_al > 4'd9);
    wire [3:0] adc_al_dec = adc_al_adj ? (adc_al[3:0] + 4'd6) : adc_al[3:0];

    wire [4:0] adc_ah     = a[7:4] + b[7:4] + adc_al_adj;
    wire       adc_ah_adj = (adc_ah > 4'd9);
    wire [3:0] adc_ah_dec = adc_ah_adj ? (adc_ah[3:0] + 4'd6) : adc_ah[3:0];

    // Decimal SBC
    // Low nibble subtraction with borrow detection on bit 4
    wire [4:0] sbc_al     = a[3:0] - b[3:0] - (!cin);
    wire       sbc_al_bor = sbc_al[4];
    wire [3:0] sbc_al_dec = sbc_al_bor ? (sbc_al[3:0] - 4'd6) : sbc_al[3:0];

    // High nibble subtraction taking low nibble borrow
    wire [4:0] sbc_ah     = a[7:4] - b[7:4] - sbc_al_bor;
    wire       sbc_ah_bor = sbc_ah[4];
    wire [3:0] sbc_ah_dec = sbc_ah_bor ? (sbc_ah[3:0] - 4'd6) : sbc_ah[3:0];

    always @(*) begin
        out      = 8'h00;
        cout     = cin;
        overflow = 1'b0;
        negative = 1'b0;
        zero     = 1'b0;

        case (op)
            OP_ORA: begin
                out      = a | b;
                negative = out[7];
                zero     = (out == 8'h00);
            end

            OP_AND: begin
                out      = a & b;
                negative = out[7];
                zero     = (out == 8'h00);
            end

            OP_EOR: begin
                out      = a ^ b;
                negative = out[7];
                zero     = (out == 8'h00);
            end

            OP_ADC: begin
                if (decimal) begin
                    out      = {adc_ah_dec, adc_al_dec};
                    cout     = adc_ah_adj;
                    overflow = (a[7] == b[7]) && (a[7] != adc_ah[3]);
                    negative = adc_ah[3];
                    zero     = (sum_bin[7:0] == 8'h00);
                end else begin
                    out      = sum_bin[7:0];
                    cout     = sum_bin[8];
                    overflow = adc_v;
                    negative = sum_bin[7];
                    zero     = (sum_bin[7:0] == 8'h00);
                end
            end

            OP_SBC: begin
                if (decimal) begin
                    out      = {sbc_ah_dec, sbc_al_dec};
                    cout     = diff_bin[8]; // NMOS: Flags remain purely binary
                    overflow = sbc_v;
                    negative = diff_bin[7];
                    zero     = (diff_bin[7:0] == 8'h00);
                end else begin
                    out      = diff_bin[7:0];
                    cout     = diff_bin[8];
                    overflow = sbc_v;
                    negative = diff_bin[7];
                    zero     = (diff_bin[7:0] == 8'h00);
                end
            end

            OP_CMP: begin
                out      = diff_bin[7:0];
                cout     = diff_bin[8];
                overflow = sbc_v;
                negative = diff_bin[7];
                zero     = (diff_bin[7:0] == 8'h00);
            end

            OP_ASL: begin
                out      = {b[6:0], 1'b0};
                cout     = b[7];
                negative = out[7];
                zero     = (out == 8'h00);
            end

            OP_LSR: begin
                out      = {1'b0, b[7:1]};
                cout     = b[0];
                negative = out[7];
                zero     = (out == 8'h00);
            end

            OP_ROL: begin
                out      = {b[6:0], cin};
                cout     = b[7];
                negative = out[7];
                zero     = (out == 8'h00);
            end

            OP_ROR: begin
                out      = {cin, b[7:1]};
                cout     = b[0];
                negative = out[7];
                zero     = (out == 8'h00);
            end

            OP_PASS: begin
                out      = b;
                negative = out[7];
                zero     = (out == 8'h00);
            end

            OP_DEC: begin
                out      = b - 1'b1;
                negative = out[7];
                zero     = (out == 8'h00);
            end

            OP_INC: begin
                out      = b + 1'b1;
                negative = out[7];
                zero     = (out == 8'h00);
            end

            default: ;
        endcase
    end

endmodule
