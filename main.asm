; ==============================================================================
; 32 KB ROM Image ($8000 - $FFFF)
; ==============================================================================
        .org $8000

reset:
        ; 1. Initialize Stack Pointer to $FF
        LDX #$FF
        TXS

        ; 2. Stream string to console via memory-mapped IO ($5000)
        LDX #$00
print_str:
        LDA msg,X
        BEQ run_math         ; Null terminator ($00) exits string loop
        STA $5000            ; Write character to testbench console
        INX
        BNE print_str

run_math:
        ; 3. Generate Fibonacci numbers: F(0)=1, F(1)=1
        LDA #$01
        STA $00              ; Mem[$00] = Fib n-1
        STA $01              ; Mem[$01] = Fib n
        LDX #10              ; Run 10 iterations

fib_loop:
        CLC
        LDA $00
        ADC $01              ; A = Fib(n-1) + Fib(n)
        LDY $01
        STY $00              ; Shift: Fib(n-1) <= Fib(n)
        STA $01              ; Shift: Fib(n)   <= A
        DEX
        BNE fib_loop

halt:
        ; 4. Terminal spin-loop trapped by testbench watchdog
        JMP halt

msg:
        .byte "DIRECT GENERATION PIPELINE OK!", $0A, $00

; ==============================================================================
; Hardware Vectors
; ==============================================================================
        .org $FFFA
        .word halt           ; NMI Vector
        .word reset          ; RESET Vector ($8000)
        .word halt           ; IRQ / BRK Vector
