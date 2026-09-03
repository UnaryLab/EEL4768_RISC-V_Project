`timescale 1ns / 1ps
`default_nettype none

// A worked example of a self-checking testbench, for the `opmux` module next
// to it. Read it top to bottom -- it is the shape every testbench you write
// this semester will have:
//
//   1. Declare a `reg` for each DUT input and a `wire` for each DUT output.
//   2. Instantiate the DUT, connecting them by port name.
//   3. Drive the inputs, wait, then compare the outputs against a value you
//      worked out independently of the RTL.
//   4. Count the comparisons and print a verdict, so you never have to read a
//      waveform to find out *whether* something broke -- only *why*.
//
// Point 3 is the one people get wrong. An expected value copied out of the
// design under test proves only that the design agrees with itself.
module opmux_tb;

    // ---------------------------------------------------------------------
    // 1. Signals: reg drives an input, wire observes an output.
    // ---------------------------------------------------------------------
    reg  [31:0] a;
    reg  [31:0] b;
    reg  [ 1:0] sel;
    reg         en;

    wire [31:0] result;
    wire        zero;

    integer passed;
    integer failed;

    // ---------------------------------------------------------------------
    // 2. The device under test. Connect by name (.port(signal)), never by
    //    position -- positional connections break silently the moment someone
    //    reorders the port list.
    // ---------------------------------------------------------------------
    opmux dut (
        .i_a      (a),
        .i_b      (b),
        .i_sel    (sel),
        .i_en     (en),
        .o_result (result),
        .o_zero   (zero)
    );

    // ---------------------------------------------------------------------
    // 3. One comparison. Drive the inputs, let the combinational logic
    //    settle, then check both outputs.
    //
    //    `===` rather than `==` on purpose: `===` compares x and z literally,
    //    so an undriven output fails here instead of quietly comparing
    //    "unknown" and returning unknown.
    // ---------------------------------------------------------------------
    task check;
        // 64 characters. A string literal wider than the reg holding it loses
        // its *leading* characters, silently -- so size this generously.
        input [511:0] label;
        input [ 31:0] t_a;
        input [ 31:0] t_b;
        input [  1:0] t_sel;
        input         t_en;
        input [ 31:0] expect_result;
        input         expect_zero;
        begin
            a   = t_a;
            b   = t_b;
            sel = t_sel;
            en  = t_en;

            // The DUT is combinational, so one time step is enough for the
            // new inputs to propagate. A clocked design would wait on an edge
            // here instead: @(posedge clk).
            #1;

            if (result === expect_result && zero === expect_zero) begin
                passed = passed + 1;
                $display("[PASS] %0s", label);
            end else begin
                failed = failed + 1;
                $display("[FAIL] %0s", label);
                $display("         a=%h b=%h sel=%b en=%b", t_a, t_b, t_sel, t_en);
                $display("         result=%h (expected %h), zero=%b (expected %b)",
                         result, expect_result, zero, expect_zero);
            end
        end
    endtask

    // ---------------------------------------------------------------------
    // A reference model, used by the random test below.
    //
    // Deriving it from the specification rather than from the RTL is what
    // makes it worth anything. Here the two happen to look alike because the
    // module is three lines long; for your ALU or decoder they will not, and
    // copying the RTL into the model would make every test pass by
    // construction.
    // ---------------------------------------------------------------------
    function [31:0] model_result;
        input [31:0] m_a;
        input [31:0] m_b;
        input [ 1:0] m_sel;
        input        m_en;
        reg   [31:0] value;
        begin
            case (m_sel)
                2'b00: value = m_a + m_b;
                2'b01: value = m_a - m_b;
                2'b10: value = m_a << m_b[4:0];
                default: value = m_a >> m_b[4:0];
            endcase
            model_result = m_en ? value : 32'b0;
        end
    endfunction

    // ---------------------------------------------------------------------
    // 4. The test program.
    // ---------------------------------------------------------------------
    integer i;
    integer seed;
    reg [31:0] rand_a;
    reg [31:0] rand_b;
    reg [ 1:0] rand_sel;
    reg [31:0] expected;

    initial begin
        // Records a waveform of every signal in this testbench. Open it with
        // `gtkwave build/opmux.vcd` to see the inputs and outputs over time --
        // the fastest way to understand a failure the printout only summarizes.
        $dumpfile("opmux.vcd");
        $dumpvars(0, opmux_tb);

        passed = 0;
        failed = 0;

        $display("========== opmux testbench ==========");

        // --- Directed tests: values worked out by hand ---------------------
        // Every expected value below was computed on paper, not read off a
        // simulation. That is what makes a failure meaningful.
        $display("--- add ---");
        check("add: 7 + 9",            32'd7, 32'd9, 2'b00, 1'b1, 32'd16,       1'b0);
        check("add: 0 + 0 sets zero",  32'd0, 32'd0, 2'b00, 1'b1, 32'd0,        1'b1);
        check("add: wraps past 2^32",  32'hffff_ffff, 32'd1, 2'b00, 1'b1, 32'd0, 1'b1);

        $display("--- sub ---");
        check("sub: 9 - 7",            32'd9, 32'd7, 2'b01, 1'b1, 32'd2,        1'b0);
        check("sub: 7 - 9 borrows",    32'd7, 32'd9, 2'b01, 1'b1, 32'hffff_fffe, 1'b0);
        check("sub: x - x sets zero",  32'd42, 32'd42, 2'b01, 1'b1, 32'd0,      1'b1);

        $display("--- shift left ---");
        check("sll: 1 << 4",           32'd1, 32'd4, 2'b10, 1'b1, 32'd16,       1'b0);
        check("sll: only low 5 bits of b are used",
                                       32'd1, 32'd32, 2'b10, 1'b1, 32'd1,       1'b0);
        check("sll: bits shifted off the top are lost",
                                       32'h8000_0000, 32'd1, 2'b10, 1'b1, 32'd0, 1'b1);

        $display("--- shift right ---");
        check("srl: 16 >> 4",          32'd16, 32'd4, 2'b11, 1'b1, 32'd1,       1'b0);
        check("srl: logical, so zeros shift in",
                                       32'hffff_ffff, 32'd28, 2'b11, 1'b1, 32'd15, 1'b0);

        $display("--- enable ---");
        check("en low forces the result to zero",
                                       32'd7, 32'd9, 2'b00, 1'b0, 32'd0,        1'b1);

        // --- Random tests: many more cases, checked against the model ------
        // A fixed seed keeps the run reproducible: a failure you see once is a
        // failure you can see again.
        $display("--- random ---");
        seed = 32'd12345;
        for (i = 0; i < 200; i = i + 1) begin
            // $random(seed) updates `seed` in place, so seeding once outside
            // the loop gives the same sequence on every run.
            rand_a   = $random(seed);
            rand_b   = $random(seed);
            rand_sel = $random(seed);
            expected = model_result(rand_a, rand_b, rand_sel, 1'b1);

            a   = rand_a;
            b   = rand_b;
            sel = rand_sel;
            en  = 1'b1;
            #1;

            if (result !== expected || zero !== (expected == 32'b0)) begin
                failed = failed + 1;
                $display("[FAIL] random %0d: a=%h b=%h sel=%b", i, rand_a, rand_b, rand_sel);
                $display("         result=%h (expected %h)", result, expected);
            end else begin
                passed = passed + 1;
            end
        end
        $display("       200 random vectors checked against the model");

        // --- Verdict -------------------------------------------------------
        $display("=====================================");
        $display("%0d passed, %0d failed", passed, failed);
        if (failed == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TEST FAILED");

        // Without $finish the simulation runs forever and iverilog's vvp
        // never returns.
        $finish;
    end

endmodule

`default_nettype wire
