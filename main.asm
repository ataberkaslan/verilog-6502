; ==============================================================================
; Interactive Serial Echo & Uppercase Converter ROM ($8000 - $FFFF)
; ==============================================================================
        .org $8000

reset:
        ; 1. Initialize Stack Pointer to $FF
        LDX #$FF
        TXS

        ; 2. Print Welcome Message
        LDX #$00
print_str:
        LDA msg,X
        BEQ start_echo       ; Null terminator ($00) exits string loop
        JSR send_char
        INX
        BNE print_str

start_echo:
        ; 3. Interactive Echo Loop
echo_loop:
        JSR get_char         ; Wait for and read a character
        CMP #$0D             ; Check if Carriage Return (Enter)
        BEQ print_newline    ; If so, handle newline
        
        ; Convert lowercase to uppercase
        CMP #'a'             ; Compare to 'a'
        BCC print_char       ; If less than 'a', print as is
        CMP #'z'+1           ; Compare to 'z'+1
        BCS print_char       ; If greater than or equal to 'z'+1, print as is
        SEC
        SBC #$20             ; Convert lowercase to uppercase (A - a = $20)

print_char:
        JSR send_char        ; Echo character back
        JMP echo_loop

print_newline:
        LDA #$0D             ; Send CR
        JSR send_char
        LDA #$0A             ; Send LF
        JSR send_char
        JMP echo_loop

; ==============================================================================
; Serial Hardware Functions (6850 ACIA Style at $5000/$5001)
; ==============================================================================
get_char:
        LDA $5001            ; Read status register
        AND #$01             ; Bit 0 = Receive Data Register Full (RDRF)
        BEQ get_char         ; Loop until a character is received
        LDA $5000            ; Read character from data register
        RTS

send_char:
        PHA                  ; Save character to stack
wait_tx:
        LDA $5001            ; Read status register
        AND #$02             ; Bit 1 = Transmit Data Register Empty (TDRE)
        BEQ wait_tx          ; Loop until transmit buffer is empty
        PLA                  ; Restore character
        STA $5000            ; Write character to data register
        RTS

msg:
        .byte "6502 COMPLIANT SERIAL INTERFACE OK!", $0D, $0A
        .byte "TYPE LOWERCASE LETTERS TO CONVERT TO UPPERCASE (PRESS CTRL+C TO EXIT):", $0D, $0A, $00

; ==============================================================================
; Hardware Vectors
; ==============================================================================
        .org $FFFA
        .word reset          ; NMI Vector
        .word reset          ; RESET Vector ($8000)
        .word reset          ; IRQ / BRK Vector
