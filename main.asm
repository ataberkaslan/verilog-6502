; ==============================================================================
; Full NMOS 6502 Hardware Self-Test Suite
; ==============================================================================
        .org $8000

reset:
        LDX #$FF
        TXS

        ; ----------------------------------------------------------------------
        ; Test 1: Immediate ALU & Condition Flags
        ; ----------------------------------------------------------------------
        ; Test ADC + Carry + Overflow
        CLC
        LDA #$50
        ADC #$50            ; $50 + $50 = $A0 (Negative set, Overflow set, Carry clear)
        BVC test1_fail
        BPL test1_fail
        BCS test1_fail

        ; Test SBC + Borrow
        SEC
        LDA #$10
        SBC #$20            ; $10 - $20 = $F0 (Borrow taken -> Carry clear)
        BCS test1_fail

        ; Test Logic
        LDA #$FF
        AND #$0F
        CMP #$0F
        BNE test1_fail
        ORA #$F0
        CMP #$FF
        BNE test1_fail
        EOR #$FF
        BNE test1_fail      ; Should be $00 (Z=1)

        LDA #<msg_alu_ok
        LDY #>msg_alu_ok
        JSR print_str
        JMP test2

test1_fail:
        LDA #<msg_alu_err
        LDY #>msg_alu_err
        JSR print_str
        JMP halt

        ; ----------------------------------------------------------------------
        ; Test 2: All Conditional Branches
        ; ----------------------------------------------------------------------
test2:
        ; Negative flag
        LDA #$80
        BMI b1_ok
        JMP test2_fail
b1_ok:  BPL test2_fail

        ; Zero flag
        LDA #$00
        BEQ b2_ok
        JMP test2_fail
b2_ok:  BNE test2_fail

        ; Carry flag
        SEC
        BCS b3_ok
        JMP test2_fail
b3_ok:  BCC test2_fail

        ; Overflow flag
        CLV
        BVC b4_ok
        JMP test2_fail
b4_ok:  BVS test2_fail

        LDA #<msg_branch_ok
        LDY #>msg_branch_ok
        JSR print_str
        JMP test3

test2_fail:
        LDA #<msg_branch_err
        LDY #>msg_branch_err
        JSR print_str
        JMP halt

        ; ----------------------------------------------------------------------
        ; Test 3: Indexed & Indirect Memory Modes
        ; ----------------------------------------------------------------------
test3:
        ; Setup Zero Page Pointer: $0040/$0041 -> $0200
        LDA #$00
        STA $40
        LDA #$02
        STA $41

        ; Write to target memory via Absolute
        LDA #$A5
        STA $0205

        ; Test Indirect Indexed: ($40),Y
        LDY #$05
        LDA ($40),Y
        CMP #$A5
        BNE test3_fail

        ; Test Indexed Indirect: ($3E,X) where X=2 -> pointer at $40
        LDX #$02
        LDA ($3E,X)
        CMP #$A5
        BNE test3_fail

        ; Test Zero Page,X
        LDA #$77
        STA $15
        LDX #$05
        LDA $10,X           ; $10 + $05 = $15
        CMP #$77
        BNE test3_fail

        LDA #<msg_mem_ok
        LDY #>msg_mem_ok
        JSR print_str
        JMP test4

test3_fail:
        LDA #<msg_mem_err
        LDY #>msg_mem_err
        JSR print_str
        JMP halt

        ; ----------------------------------------------------------------------
        ; Test 4: Read-Modify-Write (RMW) Engine
        ; ----------------------------------------------------------------------
test4:
        LDA #$01
        STA $50             ; Mem[$50] = $01
        INC $50             ; Mem[$50] = $02
        ASL $50             ; Mem[$50] = $04
        ROL $50             ; Mem[$50] = $08
        DEC $50             ; Mem[$50] = $07
        LSR $50             ; Mem[$50] = $03 (Carry = 1)
        BCC test4_fail
        LDA $50
        CMP #$03
        BNE test4_fail

        LDA #<msg_rmw_ok
        LDY #>msg_rmw_ok
        JSR print_str
        JMP test5

test4_fail:
        LDA #<msg_rmw_err
        LDY #>msg_rmw_err
        JSR print_str
        JMP halt

        ; ----------------------------------------------------------------------
        ; Test 5: Stack, Subroutines & Flags
        ; ----------------------------------------------------------------------
test5:
        ; Test PHP / PLP
        SEC
        SED
        PHP
        CLD
        CLC
        PLP
        BCC test5_fail      ; Carry should be restored to 1
        ; Test JSR / RTS parameter preservation
        LDA #$42
        PHA
        JSR dummy_sub
        PLA
        CMP #$42
        BNE test5_fail
        CPX #$99
        BNE test5_fail

        LDA #<msg_stack_ok
        LDY #>msg_stack_ok
        JSR print_str

        ; ----------------------------------------------------------------------
        ; ALL TESTS PASSED
        ; ----------------------------------------------------------------------
        LDA #<msg_all_pass
        LDY #>msg_all_pass
        JSR print_str
        JMP halt

test5_fail:
        LDA #<msg_stack_err
        LDY #>msg_stack_err
        JSR print_str

halt:
        JMP halt

dummy_sub:
        LDX #$99
        RTS

; ------------------------------------------------------------------------------
; Helper: Stream null-terminated string to $5000 (Ptr in A=Low, Y=High)
; ------------------------------------------------------------------------------
print_str:
        STA $FE
        STY $FF
        LDY #$00
ps_loop:
        LDA ($FE),Y
        BEQ ps_done
        STA $5000
        INY
        BNE ps_loop
ps_done:
        RTS

; ------------------------------------------------------------------------------
; String Table
; ------------------------------------------------------------------------------
msg_alu_ok:    .byte "[PASS] ALU Operations & Flags", $0A, $00
msg_alu_err:   .byte "[FAIL] ALU Operations & Flags", $0A, $00
msg_branch_ok: .byte "[PASS] Conditional Branches", $0A, $00
msg_branch_err:.byte "[FAIL] Conditional Branches", $0A, $00
msg_mem_ok:    .byte "[PASS] Memory & Indirect Modes", $0A, $00
msg_mem_err:   .byte "[FAIL] Memory & Indirect Modes", $0A, $00
msg_rmw_ok:    .byte "[PASS] Read-Modify-Write (RMW)", $0A, $00
msg_rmw_err:   .byte "[FAIL] Read-Modify-Write (RMW)", $0A, $00
msg_stack_ok:  .byte "[PASS] Stack, Subroutine & PHP/PLP", $0A, $00
msg_stack_err: .byte "[FAIL] Stack, Subroutine & PHP/PLP", $0A, $00
msg_all_pass:  .byte $0A, "==================================", $0A, " ALL 6502 TESTS PASSED SUCCESSFULLY", $0A, "==================================", $0A, $00

; ==============================================================================
; Hardware Vectors
; ==============================================================================
        .org $FFFA
        .word halt
        .word reset
        .word halt
