# ==============================================================================
# 6502 Core Build System (Verilator & Icarus Verilog)
# ==============================================================================

# Toolchain
VERILATOR    ?= verilator
CXX          ?= g++
VASM         ?= vasm6502_oldstyle
IVERILOG     ?= iverilog
VVP          ?= vvp
GTKWAVE      ?= gtkwave

# Verilog Sources & Testbenches
SRCS         := cpu_6502.v alu.v registers.v control.v
SIM_CPP      := sim_main.cpp
TB_VERILOG   := cpu_6502_tb.v

# Output Artifacts
OBJ_DIR      := obj_dir
V_TOP        := cpu_6502
VERILATED_BIN:= $(OBJ_DIR)/V$(V_TOP)
IVERILOG_BIN := cpu_sim.vvp

# User Program & Test Suite Binaries
ASM_SRC      ?= main.asm
USER_BIN     := $(ASM_SRC:.asm=.bin)
DORMANN_BIN  := 6502_dormann.bin

# Verilator Flags
VFLAGS       := -Wno-fatal \
                --top-module $(V_TOP) \
                -O3 \
                -CFLAGS "-O3" \
                --cc $(SRCS) \
                --exe $(SIM_CPP)

# ==============================================================================
# Primary Targets
# ==============================================================================

# Default target: compile and run your own assembly program
.PHONY: all
all: run

# ------------------------------------------------------------------------------
# 1. User Program Execution (Default Pipeline)
# ------------------------------------------------------------------------------

# Assemble .asm to raw binary
$(USER_BIN): $(ASM_SRC)
	$(VASM) -Fbin -dotdir -pad=0xEA $< -o $@

# Generate Verilator C++ simulation model
$(OBJ_DIR)/V$(V_TOP).mk: $(SRCS) $(SIM_CPP)
	$(VERILATOR) $(VFLAGS)

# Compile C++ model into native executable
$(VERILATED_BIN): $(OBJ_DIR)/V$(V_TOP).mk
	$(MAKE) -j$$(nproc) -C $(OBJ_DIR) -f V$(V_TOP).mk V$(V_TOP)

.PHONY: build
build: $(VERILATED_BIN)

# Run user assembly code in Verilator
.PHONY: run
run: $(VERILATED_BIN) $(USER_BIN)
	./$(VERILATED_BIN) $(USER_BIN)

# ------------------------------------------------------------------------------
# 2. Comprehensive Compliance Test (Dormann Suite)
# ------------------------------------------------------------------------------

# Download Dormann test binary if not already cached
$(DORMANN_BIN):
	@echo "Fetching $(DORMANN_BIN)..."
	curl -sSL "https://raw.githubusercontent.com/Klaus2m5/6502_65C02_functional_tests/master/bin_files/6502_functional_test.bin" -o $(DORMANN_BIN)

# Run full Klaus Dormann validation suite
.PHONY: test
test: $(VERILATED_BIN) $(DORMANN_BIN)
	./$(VERILATED_BIN) $(DORMANN_BIN)

# ------------------------------------------------------------------------------
# 3. Waveform Debugging (Icarus Verilog fallback)
# ------------------------------------------------------------------------------

$(IVERILOG_BIN): $(SRCS) $(TB_VERILOG)
	$(IVERILOG) -Wall -g2012 -o $@ $(SRCS) $(TB_VERILOG)

.PHONY: wave
wave: $(IVERILOG_BIN) $(ASM_SRC:.asm=.hex)
	$(VVP) $(IVERILOG_BIN) +HEX=$(ASM_SRC:.asm=.hex)
	$(GTKWAVE) cpu_6502.vcd

# ------------------------------------------------------------------------------
# 4. Microsoft BASIC Targets
# ------------------------------------------------------------------------------

# Paths to the relocated msbasic and cc65 directories (moved up one directory)
MSBASIC_DIR  := ../msbasic
MSBASIC_BIN  := msbasic.bin

# Define assembler and linker paths (prefer global system-wide binaries, fallback to ../cc65 path)
CA65         ?= $(shell which ca65 2>/dev/null || echo ../cc65/bin/ca65)
LD65         ?= $(shell which ld65 2>/dev/null || echo ../cc65/bin/ld65)

# If we are using the fallback parent ca65, make sure it is built
ifeq ($(CA65),../cc65/bin/ca65)
CC65_DEP     := ../cc65/bin/ca65
else
CC65_DEP     :=
endif

# Build local cc65 toolchain if fallback is used and not already built
../cc65/bin/ca65:
	@echo "Building local cc65 toolchain inside ../cc65..."
	$(MAKE) -j$$(nproc) -C ../cc65

# Compile custom MSBASIC ROM binary
$(MSBASIC_BIN): $(CC65_DEP)
	@echo "Assembling and linking MSBASIC ROM..."
	mkdir -p $(MSBASIC_DIR)/tmp
	$(CA65) -D sim $(MSBASIC_DIR)/msbasic.s -o $(MSBASIC_DIR)/tmp/sim.o
	$(LD65) -C $(MSBASIC_DIR)/sim.cfg $(MSBASIC_DIR)/tmp/sim.o -o $@ -Ln $(MSBASIC_DIR)/tmp/sim.lbl

# Compile MSBASIC ROM target
.PHONY: msbasic-build
msbasic-build: $(MSBASIC_BIN)

# Run interactive MSBASIC on Verilator simulator
.PHONY: msbasic
msbasic: $(VERILATED_BIN) $(MSBASIC_BIN)
	./$(VERILATED_BIN) $(MSBASIC_BIN)

# ------------------------------------------------------------------------------
# 5. Cleanup
# ------------------------------------------------------------------------------

.PHONY: clean
clean:
	rm -rf $(OBJ_DIR) $(IVERILOG_BIN) $(USER_BIN) *.vcd *.hex temp.bin
	rm -rf $(MSBASIC_DIR)/tmp
