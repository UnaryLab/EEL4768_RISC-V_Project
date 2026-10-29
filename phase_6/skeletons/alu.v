`default_nettype none

// The arithmetic logic unit (ALU) is responsible for performing the core
// calculations of the processor. It takes two 32-bit operands and outputs
// a 32 bit result based on the selection operation - addition, comparison,
// shift, or logical operation. Every RV32I operation is purely
// combinational. In phase 6 the ALU also performs the RV32M multiply and
// divide instructions, which may be combinational or take several cycles
// (see `documentation/phase_6.pdf`).
module alu (
    // Global clock and synchronous active-high reset (used by an iterative
    // multiplier or divider).
    input  wire        i_clk,
    input  wire        i_rst,
    // Major operation selection.
    // 3'b000: addition/subtraction if `i_sub` asserted
    // 3'b001: shift left logical
    // 3'b010: set less than
    // 3'b011: set less than unsigned
    // 3'b100: exclusive or
    // 3'b101: shift right logical/arithmetic if `i_arith` asserted
    // 3'b110: or
    // 3'b111: and
    // When `i_mext` is asserted, this is the M instruction's funct3 instead:
    // 3'b000: mul    - low 32 bits of op1 * op2
    // 3'b001: mulh   - high 32 bits of signed op1 * signed op2
    // 3'b010: mulhsu - high 32 bits of signed op1 * unsigned op2
    // 3'b011: mulhu  - high 32 bits of unsigned op1 * unsigned op2
    // 3'b100: div    - signed op1 / op2, rounded toward zero
    // 3'b101: divu   - unsigned op1 / op2
    // 3'b110: rem    - signed remainder, same sign as op1
    // 3'b111: remu   - unsigned remainder
    input  wire [ 2:0] i_opsel,
    // When asserted, addition operations should subtract instead.
    // This is only used for `i_opsel == 3'b000` (addition/subtraction).
    input  wire        i_sub,
    // When asserted, comparison operations should be treated as unsigned.
    // This is only used for branch comparisons, as the set less than unsigned
    // mode is already specified by `i_opsel`. For branch operations, the ALU
    // result is not used, only the comparison results.
    input  wire        i_unsigned,
    // When asserted, right shifts should be treated as arithmetic instead of
    // logical. This is only used for `i_opsel == 3'b101` (shift right).
    input  wire        i_arith,
    // Asserted while an RV32M instruction is in the execute stage.
    input  wire        i_mext,
    // Asserted when the instruction in the execute stage moves on at the next
    // rising edge. A finished M result is held until then.
    input  wire        i_advance,
    // First 32-bit input operand.
    input  wire [31:0] i_op1,
    // Second 32-bit input operand.
    input  wire [31:0] i_op2,
    // 32-bit output result. Any carry out (from addition) should be ignored.
    output wire [31:0] o_result,
    // Equality result. This is used downstream to determine if a
    // branch should be taken.
    output wire        o_eq,
    // Set less than result. This is used downstream to determine if a
    // branch should be taken.
    output wire        o_slt,
    // Asserted while an M operation is still running; the instruction must
    // stay in the execute stage until it drops.
    output wire        o_busy
);

// Write your code here.

endmodule

`default_nettype wire
