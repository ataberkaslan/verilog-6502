# 6502 CPU Core

A cycle-by-cycle, NMOS-compliant 6502 microprocessor core written in synthesizable Verilog. It is verified against the complete, industry-standard **Klaus Dormann 6502 Functional Test Suite**, passing all compliance checks perfectly in `83,767,168` clock cycles.

## Project Structure

*   `cpu_6502.v` - Top-level module interconnecting the Registers, ALU, and Control Unit.
*   `control.v` - Microcoded/step-based execution sequencer & instruction decoder.
*   `alu.v` - Arithmetic Logic Unit supporting binary and NMOS-compliant decimal modes.
*   `registers.v` - Internal registers ($A$, $X$, $Y$, $SP$, $P$) and Program Counter logic.
*   `sim_main.cpp` - High-performance Verilator C++ simulation testbench with rich instruction tracing, register dumping, and execution profiling.
*   `tb_dormann.v` - Icarus Verilog testbench harness for the compliance suite.
*   `Makefile` - Multi-tool build configuration supporting Verilator and Icarus Verilog.

---

## Architectural Fixes & Compliance Engineering

To achieve 100% compliance with the Klaus Dormann test suite, several critical diagnostic fixes and instruction set enhancements were implemented:

### 1. Indirect Jump (`JMP ($addr)`) Address Fetch Fix
*   **The Bug:** The indirect jump sequencer was loading the PC low byte (`pc[7:0]`) too early during cycle 4 (step 4), which caused the subsequent high-byte target fetch in cycle 5 (step 5) to read from a corrupted target address instead of the sequential address (`$addr + 1`).
*   **The Solution:** Refactored the step-sequencer in `control.v` so that the low target byte is safely buffered into the internal temporary register `ptr_low` during step `3`, the high target byte is buffered into `ptr_high` during step `4`, and the Program Counter is updated atomically in a single cycle using the 16-bit wide `load_pc16` control line in step `5`.

### 2. NMOS Decimal Subtraction (`SBC`) Context-Width Fix
*   **The Bug:** In `alu.v`, the decimal subtraction borrow logic was subtracting `(~cin)`. Since the carry-in flag is 1-bit and the enclosing subtraction context was evaluated at 5-bit width, standard Verilog extended `cin` to `5'b00001` *before* applying the bitwise negation operator `~`, yielding `5'b11110` (value 30) instead of the expected `5'b00000`. This resulted in incorrect decimal arithmetic (e.g. `$99 - $00` yielding `$9B`).
*   **The Solution:** Replaced the bitwise negation `~cin` with self-determined logical negation `!cin`, which evaluates to a 1-bit result (`1'b0` when carry-in is active) before zero-extending safely into the subtraction width.

### 3. Complete Implementation of Documented Indexed RMW Instructions
*   **The Enhancement:** Added support for all 12 of the official indexed read-modify-write instructions that were missing from the control block.
*   **Implemented Opcodes:**
    *   **Zero Page Indexed ($X$):** `ASL ZP,X` ($16$), `ROL ZP,X` ($36$), `LSR ZP,X` ($56$), `ROR ZP,X` ($76$), `DEC ZP,X` ($D6$), and `INC ZP,X` ($F6$).
    *   **Absolute Indexed ($X$):** `ASL ABS,X` ($1E$), `ROL ABS,X` ($3E$), `LSR ABS,X` ($5E$), `ROR ABS,X` ($7E$), `DEC ABS,X` ($DE$), and `INC ABS,X` ($FE$).
*   Each of these instructions correctly replicates NMOS 6502 cycle-by-cycle bus activity, including the standard dummy writeback of the original unmodified value prior to writing the final ALU result.

---

## Build & Execution Instructions

### Prerequisites
Make sure you have the following tools installed on your host system:
*   [Verilator](https://www.veripool.org/verilator/) (C++ Verilog Simulator)
*   GNU Make & GCC/G++ Compiler
*   [Icarus Verilog](http://iverilog.icarus.com/) (Optional, for waveform outputs)
*   `curl` (For downloading test assets)

### Run Compliance Test Suite
To download the compliance suite binary, compile the CPU model under Verilator, and run the comprehensive tests:
```bash
make test
```
The simulation will automatically report real-time status and confirm the final successful pass of the suite:
```text
[  5000000 cycles] Currently at addr: $000c (Test case: $29)
...
[80000000 cycles] Currently at addr: $34a5 (Test case: $2a)

======================================================================
 >>> KLAUS DORMANN 6502 TEST PASSED! <<<
 Trapped at Success Vector: $3469
 Total Clock Cycles: 83767168
======================================================================
```

### Run Custom Assembly Programs
To compile and run your own assembly programs (located in `main.asm`):
```bash
make run
```
