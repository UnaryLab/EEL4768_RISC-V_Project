`default_nettype none

module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000,
    // When set, pipeline forwarding optimizations are enabled.
    parameter FWD_EN = 1,
    // When set, register file bypassing is enabled.
    parameter BYPASS_EN = 1,
    // Cache configuration. Pass these down unchanged to the instruction
    // cache and the data cache (see cache.v). The testbench sets all five,
    // so these defaults are never used for grading.
    parameter EVICT_POLICY = 0,
    parameter NUM_WAYS     = 1,
    parameter CACHE_SIZE   = 16,
    parameter BLOCK_SIZE   = 128,
    parameter PREFETCH_EN  = 0
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Phase 4's combinational instruction and data memory ports are now
    // internal: they connect the pipeline to two `cache` instances inside
    // the hart, one for instructions and one for data. What leaves the hart
    // is the caches' memory side, one block (BLOCK_SIZE bytes) per transfer,
    // against a main memory with a fixed delay:
    //  * o_*mem_rd is a one-cycle request for the line at o_*mem_rd_addr
    //    (line aligned); i_*mem_valid is high for one cycle when that line
    //    is on i_*mem_rd_data. Requests are answered in order.
    //  * o_dmem_wr is a one-cycle line write; o_dmem_wr_be has one bit per
    //    byte (all ones for a dirty write-back, only the stored bytes for a
    //    write-through). Instructions are read only, so there is no
    //    instruction-side write port.
    output wire                    o_imem_rd,
    output wire [31:0]             o_imem_rd_addr,
    input  wire                    i_imem_valid,
    input  wire [BLOCK_SIZE*8-1:0] i_imem_rd_data,
    output wire                    o_dmem_rd,
    output wire [31:0]             o_dmem_rd_addr,
    input  wire                    i_dmem_valid,
    input  wire [BLOCK_SIZE*8-1:0] i_dmem_rd_data,
    output wire                    o_dmem_wr,
    output wire [31:0]             o_dmem_wr_addr,
    output wire [BLOCK_SIZE*8-1:0] o_dmem_wr_data,
    output wire [BLOCK_SIZE-1:0]   o_dmem_wr_be,
    // The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    output wire [31:0] o_retire_dmem_addr,
    output wire [ 3:0] o_retire_dmem_mask,
    output wire        o_retire_dmem_ren,
    output wire        o_retire_dmem_wen,
    output wire [31:0] o_retire_dmem_rdata,
    output wire [31:0] o_retire_dmem_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc,
    // F extension retire fields. The floating-point source registers read
    // by the instruction being retired (addresses are the instruction's rs1,
    // rs2 and rs3 fields) and their values as read in the decode stage; they
    // are only meaningful for instructions that read them.
    output wire [ 4:0] o_retire_frs1_raddr,
    output wire [31:0] o_retire_frs1_rdata,
    output wire [ 4:0] o_retire_frs2_raddr,
    output wire [31:0] o_retire_frs2_rdata,
    output wire [ 4:0] o_retire_frs3_raddr,
    output wire [31:0] o_retire_frs3_rdata,
    // Asserted when the instruction being retired writes floating-point
    // register `o_retire_frd_waddr` with `o_retire_frd_wdata`. (f0 is an
    // ordinary register, so an enable is needed.)
    output wire        o_retire_frd_wen,
    output wire [ 4:0] o_retire_frd_waddr,
    output wire [31:0] o_retire_frd_wdata,
    // The accrued floating-point exception flags (fflags) after the
    // instruction being retired.
    output wire [ 4:0] o_retire_fflags

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);

// Write your code here.

endmodule
