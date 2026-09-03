`default_nettype none

// A four-operation mux: a worked example of a small combinational module,
// paired with `opmux_tb.v` to show how to test one. It is not part of any
// assignment -- nothing you submit depends on it, and you are free to edit it,
// break it and re-run the testbench to watch what happens.
//
// It selects between four operations on two 32-bit operands. The operators
// are written directly (`+`, `-`, `<<`, `>>`) because this module exists to
// demonstrate a testbench, not to be a design exercise.
module opmux (
    // First 32-bit operand.
    input  wire [31:0] i_a,
    // Second 32-bit operand. For the two shift operations only the low five
    // bits are used, since shifting a 32-bit value by more than 31 is not
    // meaningful.
    input  wire [31:0] i_b,
    // Operation select.
    //   2'b00: i_a + i_b
    //   2'b01: i_a - i_b
    //   2'b10: i_a << i_b[4:0]
    //   2'b11: i_a >> i_b[4:0]   (logical: zeros shifted in)
    input  wire [ 1:0] i_sel,
    // Output enable. When deasserted the result is forced to zero, whatever
    // the operands are.
    input  wire        i_en,
    // The selected operation's 32-bit result. Any carry out of the addition
    // is discarded, so the result wraps.
    output wire [31:0] o_result,
    // Asserted when `o_result` is zero. Note this follows the *gated* result,
    // so it is asserted whenever `i_en` is deasserted.
    output wire        o_zero
);

    localparam [1:0] OP_ADD = 2'b00;
    localparam [1:0] OP_SUB = 2'b01;
    localparam [1:0] OP_SLL = 2'b10;
    localparam [1:0] OP_SRL = 2'b11;

    reg [31:0] operation;

    // A combinational always block: every input it reads appears in the
    // sensitivity list (`@(*)` builds that list for you), every branch assigns
    // `operation`, and it assigns with `=` rather than `<=`. Miss any of those
    // three and you infer a latch instead of a mux.
    always @(*) begin
        case (i_sel)
            OP_ADD:  operation = i_a +  i_b;
            OP_SUB:  operation = i_a -  i_b;
            OP_SLL:  operation = i_a << i_b[4:0];
            OP_SRL:  operation = i_a >> i_b[4:0];
            default: operation = 32'b0;
        endcase
    end

    assign o_result = i_en ? operation : 32'b0;
    assign o_zero   = (o_result == 32'b0);

endmodule

`default_nettype wire
