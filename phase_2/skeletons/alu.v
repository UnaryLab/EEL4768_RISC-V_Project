`default_nettype none

// The arithmetic logic unit (ALU) is responsible for performing the core
// calculations of the processor. It takes two 32-bit operands and outputs
// a 32 bit result based on the selection operation - addition, comparison,
// shift, or logical operation. This ALU is a purely combinational block, so
// you should not attempt to add any registers or pipeline it.
module alu (
    // Major operation selection.
    // 3'b000: addition/subtraction if `i_sub` asserted
    // 3'b001: shift left logical
    // 3'b010: set less than
    // 3'b011: set less than unsigned
    // 3'b100: exclusive or
    // 3'b101: shift right logical/arithmetic if `i_arith` asserted
    // 3'b110: or
    // 3'b111: and
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
    output wire        o_slt
);
    // Your implementation goes under here
    // ------------------------------------

endmodule

`default_nettype wire
