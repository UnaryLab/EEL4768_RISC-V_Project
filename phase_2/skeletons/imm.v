// The immediate generator is responsible for decoding the 32-bit
// sign-extended immediate from the incoming instruction word. It is a purely
// combinational block that is expected to be embedded in the instruction
// decoder.
module imm (
    // Input instruction word. This is used to extract the relevant immediate
    // bits and assemble them into the final immediate.
    input  wire [31:0] i_inst,
    // Instruction format, determined by the instruction decoder based on the
    // opcode. This is one-hot encoded according to the following format:
    // [0] R-type
    // [1] I-type
    // [2] S-type
    // [3] B-type
    // [4] U-type
    // [5] J-type
    // Because the R-type format does not have an immediate, the output
    // immediate can be treated as a don't-care under this case.
    input  wire [ 5:0] i_format,
    // Output 32-bit immediate, sign-extended from the immediate bitstring.
    output wire [31:0] o_immediate
);
    // Your implementation goes under here
    // ------------------------------------

endmodule
