#include <iostream>
#include <fstream>
#include <vector>
#include <cstdint>
#include <iomanip>
#include <string>
#include <deque>
#include <sstream>
#include <unistd.h>
#include <termios.h>
#include <fcntl.h>
#include "Vcpu_6502.h"
#include "Vcpu_6502___024root.h"
#include "verilated.h"

// -----------------------------------------------------------------------------
// Terminal Raw Mode Support
// -----------------------------------------------------------------------------
struct termios orig_termios;
bool raw_mode_enabled = false;

void disable_raw_mode() {
    if (raw_mode_enabled) {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
        raw_mode_enabled = false;
    }
}

void enable_raw_mode() {
    if (isatty(STDIN_FILENO)) {
        if (tcgetattr(STDIN_FILENO, &orig_termios) == 0) {
            struct termios raw = orig_termios;
            raw.c_lflag &= ~(ECHO | ICANON); // Disable echoing and line-buffered input
            raw.c_iflag &= ~(IXON | ICRNL);  // Disable software flow control and carriage-return mapping
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
            raw_mode_enabled = true;
            atexit(disable_raw_mode);
        }
    }
    // Set stdin to non-blocking unconditionally (even if piped or not a tty)
    int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);
}

// -----------------------------------------------------------------------------
// 6502 Disassembler Helper
// -----------------------------------------------------------------------------
struct DecodedInst {
    std::string text;
    int len;
};

struct TraceEntry {
    uint16_t pc;
    uint8_t opcode;
    uint8_t a;
    uint8_t x;
    uint8_t y;
    uint8_t sp;
    uint8_t p;
    uint64_t cycle;
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

        // Zero Page Indexed (2 bytes)
        case 0x15: oss << "ORA $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0x35: oss << "AND $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0x55: oss << "EOR $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0x75: oss << "ADC $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0x95: oss << "STA $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0xB5: oss << "LDA $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0xD5: oss << "CMP $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0xF5: oss << "SBC $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0x16: oss << "ASL $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0x36: oss << "ROL $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0x56: oss << "LSR $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0x76: oss << "ROR $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0xD6: oss << "DEC $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0xF6: oss << "INC $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0xB4: oss << "LDY $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0x94: oss << "STY $" << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 2};
        case 0xB6: oss << "LDX $" << std::setw(2) << (int)b1 << ",Y"; return {oss.str(), 2};
        case 0x96: oss << "STX $" << std::setw(2) << (int)b1 << ",Y"; return {oss.str(), 2};

        // Absolute (3 bytes)
        case 0x20: oss << "JSR $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1; return {oss.str(), 3};
        case 0x4C: oss << "JMP $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1; return {oss.str(), 3};
        case 0x6C: oss << "JMP ($" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ")"; return {oss.str(), 3};
        case 0x8D: oss << "STA $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1; return {oss.str(), 3};
        case 0xAD: oss << "LDA $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1; return {oss.str(), 3};
        case 0xCD: oss << "CMP $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1; return {oss.str(), 3};
        case 0xEC: oss << "CPX $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1; return {oss.str(), 3};
        case 0xCC: oss << "CPY $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1; return {oss.str(), 3};

        // Absolute Indexed (3 bytes)
        case 0x1D: oss << "ORA $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};
        case 0x3D: oss << "AND $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};
        case 0x5D: oss << "EOR $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};
        case 0x7D: oss << "ADC $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};
        case 0x9D: oss << "STA $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};
        case 0xBD: oss << "LDA $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};
        case 0xDD: oss << "CMP $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};
        case 0xFD: oss << "SBC $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};
        case 0x1E: oss << "ASL $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};
        case 0x3E: oss << "ROL $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};
        case 0x5E: oss << "LSR $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};
        case 0x7E: oss << "ROR $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};
        case 0xDE: oss << "DEC $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};
        case 0xFE: oss << "INC $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};
        case 0xBC: oss << "LDY $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",X"; return {oss.str(), 3};

        case 0x19: oss << "ORA $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",Y"; return {oss.str(), 3};
        case 0x39: oss << "AND $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",Y"; return {oss.str(), 3};
        case 0x59: oss << "EOR $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",Y"; return {oss.str(), 3};
        case 0x79: oss << "ADC $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",Y"; return {oss.str(), 3};
        case 0x99: oss << "STA $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",Y"; return {oss.str(), 3};
        case 0xB9: oss << "LDA $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",Y"; return {oss.str(), 3};
        case 0xD9: oss << "CMP $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",Y"; return {oss.str(), 3};
        case 0xF9: oss << "SBC $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",Y"; return {oss.str(), 3};
        case 0xBE: oss << "LDX $" << std::setw(2) << (int)b2 << std::setw(2) << (int)b1 << ",Y"; return {oss.str(), 3};

        default:
            oss << ".byte $" << std::setw(2) << (int)op;
            return {oss.str(), 1};
    }
}

// -----------------------------------------------------------------------------
// Diagnostic Dump Routine
// -----------------------------------------------------------------------------
void print_diagnostics(Vcpu_6502* top, const std::vector<uint8_t>& memory, uint16_t trap_pc, uint64_t cycles,
                       const std::deque<std::pair<uint16_t, uint8_t>>& trace,
                       const std::deque<TraceEntry>& inst_trace) {
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

    // 1. CPU Register State
    if (top && top->rootp) {
        uint8_t a = top->rootp->cpu_6502__DOT__reg_a;
        uint8_t x = top->rootp->cpu_6502__DOT__reg_x;
        uint8_t y = top->rootp->cpu_6502__DOT__reg_y;
        uint8_t sp = top->rootp->cpu_6502__DOT__reg_sp;
        uint16_t pc = top->rootp->cpu_6502__DOT__pc;
        uint8_t p = top->rootp->cpu_6502__DOT__p_pushed;
        std::cout << "\n[CPU INTERNAL REGISTERS]\n";
        std::cout << " PC : $" << std::hex << std::setw(4) << std::setfill('0') << pc
                  << "   SP : $" << std::setw(2) << (int)sp << "\n";
        std::cout << " A  : $" << std::setw(2) << (int)a
                  << "   X  : $" << std::setw(2) << (int)x
                  << "   Y  : $" << std::setw(2) << (int)y << "\n";
        std::cout << " P  : $" << std::setw(2) << (int)p << " ("
                  << ((p & 0x80) ? 'N' : 'n')
                  << ((p & 0x40) ? 'V' : 'v')
                  << "11"
                  << ((p & 0x08) ? 'D' : 'd')
                  << ((p & 0x04) ? 'I' : 'i')
                  << ((p & 0x02) ? 'Z' : 'z')
                  << ((p & 0x01) ? 'C' : 'c')
                  << ")\n";
    }

    // 2. Klaus Dormann Test Case Number at $0200
    uint8_t test_case = memory[0x0200];
    std::cout << "\n[DORMANN TEST STATE]\n";
    std::cout << " Active Test Case Number ($0200): $" << std::hex << std::setw(2) << (int)test_case
              << " (" << std::dec << (int)test_case << ")\n";

    // 3. Zero Page Dump ($0000 - $001F)
    std::cout << "\n[ZERO PAGE DUMP ($0000 - $001F)]\n";
    for (int row = 0; row < 2; ++row) {
        std::cout << " $" << std::hex << std::setw(4) << (row * 16) << ": ";
        for (int col = 0; col < 16; ++col) {
            std::cout << std::setw(2) << (int)memory[row * 16 + col] << " ";
        }
        std::cout << "\n";
    }

    // 4. Recent Instruction Trace
    if (!inst_trace.empty()) {
        std::cout << "\n[RECENT INSTRUCTION TRACE]\n";
        for (const auto& entry : inst_trace) {
            DecodedInst d = disassemble_6502(memory, entry.pc);
            std::cout << "  Cycle: " << std::setw(8) << std::dec << entry.cycle
                      << " | PC: $" << std::hex << std::setw(4) << std::setfill('0') << entry.pc
                      << " | Op: " << std::setw(2) << (int)entry.opcode << " (" << std::setw(8) << std::left << d.text << ")"
                      << std::right << " | A: $" << std::setw(2) << (int)entry.a
                      << " X: $" << std::setw(2) << (int)entry.x
                      << " Y: $" << std::setw(2) << (int)entry.y
                      << " SP: $" << std::setw(2) << (int)entry.sp
                      << " Flags: "
                      << ((entry.p & 0x80) ? 'N' : 'n')
                      << ((entry.p & 0x40) ? 'V' : 'v')
                      << "--"
                      << ((entry.p & 0x08) ? 'D' : 'd')
                      << ((entry.p & 0x04) ? 'I' : 'i')
                      << ((entry.p & 0x02) ? 'Z' : 'z')
                      << ((entry.p & 0x01) ? 'C' : 'c')
                      << "\n";
        }
    }

    // 5. Disassembly of Code Around Trap PC
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

    // 6. Last Executed Bus Transactions
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
    std::ifstream file(bin_file, std::ios::binary | std::ios::ate);
    if (!file) {
        std::cerr << "Error: Could not open " << bin_file << "\n";
        delete top;
        return 1;
    }

    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    if (size > 65536) size = 65536;
    uint16_t load_offset = 65536 - size;

    if (file.read(reinterpret_cast<char*>(memory.data() + load_offset), size)) {
        std::cout << "Loaded " << size << " bytes into memory at offset $" 
                  << std::hex << load_offset << " from " << bin_file << std::dec << "\n";
    } else {
        std::cerr << "Error reading file " << bin_file << "\n";
        delete top;
        return 1;
    }

    bool is_dormann = (std::string(bin_file).find("dormann") != std::string::npos);

    // Set Reset Vector to test suite entry ($0400) only for Dormann test suite
    if (is_dormann) {
        memory[0xFFFC] = 0x00;
        memory[0xFFFD] = 0x04;
    }

    // Enable Raw Mode for user programs to interact character-by-character
    if (!is_dormann) {
        enable_raw_mode();
    }

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
    std::deque<TraceEntry> instruction_trace;

    // Loop detection state
    uint16_t candidate_trap = 0;
    int      candidate_hits = 0;
    uint16_t min_addr_window = 0xFFFF;
    uint16_t max_addr_window = 0x0000;
    int      tight_loop_cycles = 0;

    // Serial port emulation state
    unsigned char rx_char = 0;
    bool          rx_full = false;

    while (!Verilated::gotFinish()) {
        // --- Rising Edge ---
        top->clk = 1;
        top->eval();

        if (top->rootp->cpu_6502__DOT__u_control__DOT__step == 1) {
            uint16_t current_pc = (top->rootp->cpu_6502__DOT__pc - 1) & 0xFFFF;
            uint8_t current_opcode = top->rootp->cpu_6502__DOT__u_control__DOT__ir;
            int dup_count = 0;
            for (auto it = instruction_trace.rbegin(); it != instruction_trace.rend(); ++it) {
                if (it->pc == current_pc) dup_count++;
                else break;
            }
            int ff_count = 0;
            if (current_opcode == 0xFF) {
                for (auto it = instruction_trace.rbegin(); it != instruction_trace.rend(); ++it) {
                    if (it->opcode == 0xFF) ff_count++;
                    else break;
                }
            }
            if (dup_count < 3 && ff_count < 3) {
                TraceEntry entry;
                entry.pc = current_pc;
                entry.opcode = current_opcode;
                entry.a = top->rootp->cpu_6502__DOT__reg_a;
                entry.x = top->rootp->cpu_6502__DOT__reg_x;
                entry.y = top->rootp->cpu_6502__DOT__reg_y;
                entry.sp = top->rootp->cpu_6502__DOT__reg_sp;
                entry.p = top->rootp->cpu_6502__DOT__p_pushed;
                entry.cycle = cycles;
                instruction_trace.push_back(entry);
                if (instruction_trace.size() > 500) {
                    instruction_trace.pop_front();
                }
            }
        }

        // Periodically poll for keyboard input (only in interactive raw mode)
        if (!is_dormann && (cycles % 1000 == 0)) {
            if (!rx_full) {
                unsigned char ch;
                int r = read(STDIN_FILENO, &ch, 1);
                if (r > 0) {
                    rx_char = ch;
                    rx_full = true;
                }
            }
        }

        if (top->we) {
            if (top->addr == 0x5000) {
                std::cout.put(top->dout);
                std::cout.flush();
            } else if (top->addr < 0x8000) { // ROM write protection: only RAM (< $8000) is writeable
                memory[top->addr] = top->dout;
            }
        }

        // Setup Read Data
        if (top->addr == 0x5001) {
            top->din = rx_full ? 0x03 : 0x02; // Bit 1 = Tx Ready, Bit 0 = Rx Full
        } else if (top->addr == 0x5000) {
            top->din = rx_char;
            rx_full = false; // Automatically clear Rx Full status on reading data
        } else {
            top->din = memory[top->addr];
        }
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

        // Loop Detector: Detect when addresses stay bounded within a <= 8-byte range (only for Dormann automated tests)
        if (is_dormann && (cycles % 128 == 0)) {
            if ((max_addr_window - min_addr_window) <= 8 && min_addr_window != 0x0000) {
                tight_loop_cycles += 128;
                if (tight_loop_cycles >= 2048) { // Trapped in tight loop for >2000 cycles
                    print_diagnostics(top, memory, min_addr_window, cycles, trace, instruction_trace);
                    break;
                }
            } else {
                tight_loop_cycles = 0;
            }
            min_addr_window = 0xFFFF;
            max_addr_window = 0x0000;
        }

        // Direct JMP self trap detector (only for Dormann automated tests)
        if (is_dormann) {
            if (top->addr == candidate_trap) {
                candidate_hits++;
                if (candidate_hits > 200) {
                    print_diagnostics(top, memory, candidate_trap, cycles, trace, instruction_trace);
                    break;
                }
            } else {
                candidate_trap = top->addr;
                candidate_hits = 1;
            }
        }

        // Periodic Status Heartbeat (only for Dormann automated tests)
        if (is_dormann && (cycles % 5000000 == 0)) {
            std::cout << "[" << std::setw(9) << cycles << " cycles] Currently at addr: $"
                      << std::hex << std::setw(4) << std::setfill('0') << top->addr
                      << " (Test case: $" << (int)memory[0x0200] << ")" << std::dec << "\n";
        }

        // Safety timeout (only for Dormann automated tests)
        if (is_dormann && (cycles > 100000000)) {
            std::cout << "\n[WATCHDOG TIMEOUT TRIGGERED]\n";
            print_diagnostics(top, memory, top->addr, cycles, trace, instruction_trace);
            break;
        }
    }

    disable_raw_mode();
    delete top;
    return 0;
}
