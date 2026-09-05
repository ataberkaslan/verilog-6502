# ==============================================================================
# 6502 Automated Direct Pipeline Makefile
# ==============================================================================

VASM     ?= vasm6502_oldstyle
IVERILOG ?= iverilog
VVP      ?= vvp
GTKWAVE  ?= gtkwave

VFLAGS   ?= -Wall -g2012

SRCS     := alu.v registers.v control.v cpu_6502.v
TB       := cpu_6502_tb.v
BIN      := cpu_sim.vvp

ASM_SRC  ?= main.asm
HEX_OUT  := $(ASM_SRC:.asm=.hex)

.PHONY: all
all: run

# 1. Directly assemble .asm into Verilog-compatible hex
$(HEX_OUT): $(ASM_SRC)
	$(VASM) -Fbin -dotdir -pad=0xEA $< -o temp.bin
	hexdump -v -e '1/1 "%02X\n"' temp.bin > $@
	@rm -f temp.bin

# 2. Compile Verilog core and testbench
$(BIN): $(SRCS) $(TB)
	$(IVERILOG) $(VFLAGS) -o $@ $(SRCS) $(TB)

# 3. Assemble and run simulation
.PHONY: run
run: $(HEX_OUT) $(BIN)
	$(VVP) $(BIN) +HEX=$(HEX_OUT)

# 4. Inspect traces in GTKWave
.PHONY: wave
wave: run
	$(GTKWAVE) cpu_6502.vcd

# Clean generated output
.PHONY: clean
clean:
	@rm -f *.vvp *.vcd *.hex
