#include <iostream>
#include <fstream>
#include <vector>
#include <cstdint>
#include <iomanip>
#include <string>
#include <deque>
#include <sstream>
#include "Vcpu_6502.h"
#include "verilated.h"

// -----------------------------------------------------------------------------
// 6502 Disassembler Helper
// -----------------------------------------------------------------------------
struct DecodedInst {
    std::string text;
    int len;
};

DecodedInst disassemble_6502(const std::vector<uint8_t>& mem, uint16_t pc) {
    uint8_t op = mem[pc];
    uint8_t b1 = mem[(pc + 1) & 0xFFFF];
    uint8_t b2 = mem[(pc + 2) & 0xFFFF];
    std::ostringstream oss;
    oss << std::hex << std::uppercase << std::setfill('0');

    // Branch Target Calculation
    auto rel_target = [&](int8_t offset) {
        uint16_t target = pc + 2 + offset;
        std::ostringstream s;
        s << "$" << std::hex << std::setw(4) << std::setfill('0') << target;
        return s.str();
    };

    switch (op) {
        // Implied / Accumulator / Stack (1 byte)
        case 0x00: return {"BRK", 1};
        case 0x08: return {"PHP", 1};
        case 0x0A: return {"ASL A", 1};
        case 0x18: return {"CLC", 1};
        case 0x28: return {"PLP", 1};
        case 0x2A: return {"ROL A", 1};
        case 0x38: return {"SEC", 1};
        case 0x40: return {"RTI", 1};
        case 0x48: return {"PHA", 1};
        case 0x4A: return {"LSR A", 1};
        case 0x58: return {"CLI", 1};
        case 0x60: return {"RTS", 1};
        case 0x68: return {"PLA", 1};
        case 0x6A: return {"ROR A", 1};
        case 0x78: return {"SEI", 1};
        case 0x88: return {"DEY", 1};
        case 0x8A: return {"TXA", 1};
        case 0x98: return {"TYA", 1};
        case 0x9A: return {"TXS", 1};
        case 0xA8: return {"TAY", 1};
        case 0xAA: return {"TAX", 1};
        case 0xBA: return {"TSX", 1};
        case 0xB8: return {"CLV", 1};
        case 0xC8: return {"INY", 1};
        case 0xCA: return {"DEX", 1};
        case 0xD8: return {"CLD", 1};
        case 0xE8: return {"INX", 1};
        case 0xEA: return {"NOP", 1};
        case 0xF8: return {"SED", 1};

        // Branches (2 bytes)
        case 0x10: return {"BPL " + rel_target(static_cast<int8_t>(b1)), 2};
        case 0x30: return {"BMI " + rel_target(static_cast<int8_t>(b1)), 2};
        case 0x50: return {"BVC " + rel_target(static_cast<int8_t>(b1)), 2};
        case 0x70: return {"BVS " + rel_target(static_cast<int8_t>(b1)), 2};
        case 0x90: return {"BCC " + rel_target(static_cast<int8_t>(b1)), 2};
        case 0xB0: return {"BCS " + rel_target(static_cast<int8_t>(b1)), 2};
        case 0xD0: return {"BNE " + rel_target(static_cast<int8_t>(b1)), 2};
        case 0xF0: return {"BEQ " + rel_target(static_cast<int8_t>(b1)), 2};

        // Immediate (2 bytes)
        case 0x09: oss << "ORA #$" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0x29: oss << "AND #$" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0x49: oss << "EOR #$" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0x69: oss << "ADC #$" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0xA0: oss << "LDY #$" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0xA2: oss << "LDX #$" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0xA9: oss << "LDA #$" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0xC0: oss << "CPY #$" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0xC9: oss << "CMP #$" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0xE0: oss << "CPX #$" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0xE9: oss << "SBC #$" << std::setw(2) << (int)b1; return {oss.str(), 2};

        // Zero Page (2 bytes)
        case 0x05: oss << "ORA $" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0x24: oss << "BIT $" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0x25: oss << "AND $" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0x45: oss << "EOR $" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0x65: oss << "ADC $" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0x84: oss << "STY $" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0x85: oss << "STA $" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0x86: oss << "STX $" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0xA4: oss << "LDY $" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0xA5: oss << "LDA $" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0xA6: oss << "LDX $" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0xC4: oss << "CPY $" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0xC5: oss << "CMP $" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0xE4: oss << "CPX $" << std::setw(2) << (int)b1; return {oss.str(), 2};
        case 0xE5: oss << "SBC $" << std::setw(2) << (int)b1; return {oss.str(), 2};

        // Absolute (3 bytes)
        case 0x20: oss << "JSR $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1; return {oss.str(), 3};
        case 0x4C: oss << "JMP $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1; return {oss.str(), 3};
        case 0x6C: oss << "JMP ($" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ")"; return {oss.str(), 3};
        case 0x8D: oss << "STA $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1; return {oss.str(), 3};
        case 0xAD: oss << "LDA $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1; return {oss.str(), 3};
        case 0xCD: oss << "CMP $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1; return {oss.str(), 3};
        case 0xEC: oss << "CPX $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1; return {oss.str(), 3};
        case 0xCC: oss << "CPY $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1; return {oss.str(), 3};

        default:
            oss << ".byte $" << std::setw(2) << (int)op;
            return {oss.str(), 1};
    }
}

// -----------------------------------------------------------------------------
// Diagnostic Dump Routine
// -----------------------------------------------------------------------------
void print_diagnostics(const std::vector<uint8_t>& memory, uint16_t trap_pc, uint64_t cycles,
                       const std::deque<std::pair<uint16_t, uint8_t>>& trace) {
    std::cout << "\n======================================================================\n";
    if (trap_pc == 0x3469) {
        std::cout << " >>> KLAUS DORMANN 6502 TEST PASSED! <<<\n";
        std::cout << " Trapped at Success Vector: $3469\n";
        std::cout << " Total Clock Cycles: " << cycles << "\n";
        std::cout << "======================================================================\n";
        return;
    }

    std::cout << " >>> KLAUS DORMANN TEST FAILED / TRAPPED <<<\n";
    std::cout << " Trap PC Address: $" << std::hex << std::setw(4) << std::setfill('0') << trap_pc
              << " (" << std::dec << trap_pc << ")\n";
    std::cout << " Total Cycles   : " << cycles << "\n";

    // 1. Klaus Dormann Test Case Number at $0200
    uint8_t test_case = memory[0x0200];
    std::cout << "\n[DORMANN TEST STATE]\n";
    std::cout << " Active Test Case Number ($0200): $" << std::hex << std::setw(2) << (int)test_case
              << " (" << std::dec << (int)test_case << ")\n";

    // 2. Zero Page Dump ($0000 - $001F)
    std::cout << "\n[ZERO PAGE DUMP ($0000 - $001F)]\n";
    for (int row = 0; row < 2; ++row) {
        std::cout << " $" << std::hex << std::setw(4) << (row * 16) << ": ";
        for (int col = 0; col < 16; ++col) {
            std::cout << std::setw(2) << (int)memory[row * 16 + col] << " ";
        }
        std::cout << "\n";
    }

    // 3. Disassembly of Code Around Trap PC
    std::cout << "\n[DISASSEMBLY AROUND TRAP ADDRESS]\n";
    uint16_t dis_pc = (trap_pc > 16) ? (trap_pc - 16) : 0x0000;
    while (dis_pc <= trap_pc + 16 && dis_pc < 0xFFFF) {
        DecodedInst d = disassemble_6502(memory, dis_pc);
        std::cout << (dis_pc == trap_pc ? " => " : "    ")
                  << "$" << std::hex << std::setw(4) << dis_pc << ": ";

        // Print raw hex bytes
        for (int i = 0; i < 3; ++i) {
            if (i < d.len) std::cout << std::setw(2) << (int)memory[(dis_pc + i) & 0xFFFF] << " ";
            else           std::cout << "   ";
        }
        std::cout << " " << d.text << "\n";
        dis_pc += d.len;
    }

    // 4. Last Executed Bus Transactions
    std::cout << "\n[RECENT BUS ACTIVITY (LAST " << trace.size() << " TRANSACTIONS)]\n";
    for (size_t i = 0; i < trace.size(); ++i) {
        std::cout << "  [-" << std::dec << (trace.size() - i) << "] Addr: $"
                  << std::hex << std::setw(4) << trace[i].first
                  << "  Data: $" << std::setw(2) << (int)trace[i].second << "\n";
    }
    std::cout << "======================================================================\n";
}

// -----------------------------------------------------------------------------
// Main Simulation
// -----------------------------------------------------------------------------
int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vcpu_6502* top = new Vcpu_6502;

    std::vector<uint8_t> memory(65536, 0xEA);

    const char* bin_file = (argc > 1) ? argv[1] : "6502_dormann.bin";
    std::ifstream file(bin_file, std::ios::binary);
    if (!file) {
        std::cerr << "Error: Could not open " << bin_file << "\n";
        delete top;
        return 1;
    }

    file.read(reinterpret_cast<char*>(memory.data()), 65536);
    std::cout << "Loaded " << file.gcount() << " bytes into memory from " << bin_file << "\n";

    // Set Reset Vector to test suite entry ($0400)
    memory[0xFFFC] = 0x00;
    memory[0xFFFD] = 0x04;

    // Reset sequence
    top->clk   = 0;
    top->rst_n = 0;
    top->din   = 0;

    for (int i = 0; i < 20; i++) {
        top->clk = !top->clk;
        if (top->clk == 0) top->din = memory[top->addr];
        top->eval();
    }
    top->rst_n = 1;

    std::cout << "Starting simulation run...\n";

    uint64_t cycles = 0;
    std::deque<std::pair<uint16_t, uint8_t>> trace;

    // Loop detection state
    uint16_t candidate_trap = 0;
    int      candidate_hits = 0;
    uint16_t min_addr_window = 0xFFFF;
    uint16_t max_addr_window = 0x0000;
    int      tight_loop_cycles = 0;

    while (!Verilated::gotFinish()) {
        // --- Rising Edge ---
        top->clk = 1;
        top->eval();

        if (top->we) {
            memory[top->addr] = top->dout;
        }

        // Setup Read Data
        top->din = memory[top->addr];
        top->eval();

        // --- Falling Edge ---
        top->clk = 0;
        top->eval();

        cycles++;

        // Track rolling bus activity
        trace.push_back({top->addr, top->din});
        if (trace.size() > 24) trace.pop_front();

        // Track address range over sliding window
        if (top->addr < min_addr_window) min_addr_window = top->addr;
        if (top->addr > max_addr_window) max_addr_window = top->addr;

        // Loop Detector: Detect when addresses stay bounded within a <= 8-byte range
        if (cycles % 128 == 0) {
            if ((max_addr_window - min_addr_window) <= 8 && min_addr_window != 0x0000) {
                tight_loop_cycles += 128;
                if (tight_loop_cycles >= 2048) { // Trapped in tight loop for >2000 cycles
                    print_diagnostics(memory, min_addr_window, cycles, trace);
                    break;
                }
            } else {
                tight_loop_cycles = 0;
            }
            min_addr_window = 0xFFFF;
            max_addr_window = 0x0000;
        }

        // Direct JMP self trap detector
        if (top->addr == candidate_trap) {
            candidate_hits++;
            if (candidate_hits > 200) {
                print_diagnostics(memory, candidate_trap, cycles, trace);
                break;
            }
        } else {
            candidate_trap = top->addr;
            candidate_hits = 1;
        }

        // Periodic Status Heartbeat
        if (cycles % 5000000 == 0) {
            std::cout << "[" << std::setw(9) << cycles << " cycles] Currently at addr: $"
                      << std::hex << std::setw(4) << std::setfill('0') << top->addr
                      << " (Test case: $" << (int)memory[0x0200] << ")" << std::dec << "\n";
        }

        // Safety timeout
        if (cycles > 100000000) {
            std::cout << "\n[WATCHDOG TIMEOUT TRIGGERED]\n";
            print_diagnostics(memory, top->addr, cycles, trace);
            break;
        }
    }

    delete top;
    return 0;
}
