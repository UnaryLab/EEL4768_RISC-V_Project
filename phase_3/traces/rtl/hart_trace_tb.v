`timescale 1ns/1ps
`default_nettype none

// Trace-driven hart test.
//
// Unlike phase 2's alu/decoder/imm/rf trace testbenches, this one can't
// simply "drive a vector's inputs and compare the outputs": hart.v fetches
// from a real instruction memory at an address it computes itself (PC,
// branches, jumps), so the only way to genuinely exercise that is to give
// it a real program image and let it fetch for real. Two files work
// together:
//
//   vectors/hart_program.hex   the flat instruction memory image
//                              ($readmemh format), loaded up front
//   vectors/hart.trace         what the design should retire, one line per
//                              instruction actually retired, in EXECUTION
//                              order (not memory order -- a loop revisits
//                              addresses, a taken branch skips some)
//
// This file drives no inputs from the trace at all -- it only checks. The
// real DUT computes its own addresses against the real program image
// (exactly as on real hardware), and this compares what it did, cycle by
// cycle, against the recorded line.
//
//   iverilog -g2005 -s hart_trace_tb -o sim rtl/hart_trace_tb.v \
//       <your hart.v> <your alu.v> <your imm.v> <your rf.v> <your decoder.v>
//   ./sim
//
// Point it at different files with +trace=<path> and +program=<path>.
//
// DON'T-CARES. rs1/rs2's reported register index and value are only
// checked for instruction classes that actually read that operand (see
// the "Don't-cares" section of ../README.md) -- the trace
// writes those columns as `x` otherwise, and any column that reads back as
// x is skipped, exactly like phase 2's decoder.trace. Every other column,
// including on illegal/trapped instructions, is checked exactly.
module hart_trace_tb();

    localparam integer FIELDS     = 15;   // columns per vector line
    localparam integer MAX_GROUPS = 64;
    localparam integer MAX_REPORT = 20;

    localparam integer IMEM_WORDS = 1 << 15;
    localparam integer DMEM_WORDS = 1 << 12;
    localparam integer IMEM_ABITS = 15;
    localparam integer DMEM_ABITS = 12;

    // ------------------------------------------------------------------
    // Device under test
    // ------------------------------------------------------------------
    reg i_clk;
    reg i_rst;

    wire [31:0] o_imem_raddr;
    reg  [31:0] i_imem_rdata;

    wire [31:0] o_dmem_addr;
    wire        o_dmem_ren;
    wire        o_dmem_wen;
    wire [31:0] o_dmem_wdata;
    wire [ 3:0] o_dmem_mask;
    reg  [31:0] i_dmem_rdata;

    wire        o_retire_valid;
    wire [31:0] o_retire_inst;
    wire        o_retire_trap;
    wire        o_retire_halt;
    wire [ 4:0] o_retire_rs1_raddr;
    wire [31:0] o_retire_rs1_rdata;
    wire [ 4:0] o_retire_rs2_raddr;
    wire [31:0] o_retire_rs2_rdata;
    wire [ 4:0] o_retire_rd_waddr;
    wire [31:0] o_retire_rd_wdata;
    wire [31:0] o_retire_pc;
    wire [31:0] o_retire_next_pc;

    hart #(.RESET_ADDR(32'h00000000)) dut (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .o_imem_raddr(o_imem_raddr),
        .i_imem_rdata(i_imem_rdata),
        .o_dmem_addr(o_dmem_addr),
        .o_dmem_ren(o_dmem_ren),
        .o_dmem_wen(o_dmem_wen),
        .o_dmem_wdata(o_dmem_wdata),
        .o_dmem_mask(o_dmem_mask),
        .i_dmem_rdata(i_dmem_rdata),
        .o_retire_valid(o_retire_valid),
        .o_retire_inst(o_retire_inst),
        .o_retire_trap(o_retire_trap),
        .o_retire_halt(o_retire_halt),
        .o_retire_rs1_raddr(o_retire_rs1_raddr),
        .o_retire_rs1_rdata(o_retire_rs1_rdata),
        .o_retire_rs2_raddr(o_retire_rs2_raddr),
        .o_retire_rs2_rdata(o_retire_rs2_rdata),
        .o_retire_rd_waddr(o_retire_rd_waddr),
        .o_retire_rd_wdata(o_retire_rd_wdata),
        .o_retire_pc(o_retire_pc),
        .o_retire_next_pc(o_retire_next_pc)
    );

    // ---- Instruction memory: combinational, word-addressed, real ----
    reg [31:0] imem [0:IMEM_WORDS-1];
    always @(*) i_imem_rdata = imem[o_imem_raddr[IMEM_ABITS+1:2]];

    // ---- Data memory: combinational read, byte-lane-masked synchronous write ----
    reg [31:0] dmem [0:DMEM_WORDS-1];
    always @(*) i_dmem_rdata = dmem[o_dmem_addr[DMEM_ABITS+1:2]];

    always @(posedge i_clk) begin
        if (o_dmem_wen) begin
            if (o_dmem_mask[0]) dmem[o_dmem_addr[DMEM_ABITS+1:2]][ 7: 0] <= o_dmem_wdata[ 7: 0];
            if (o_dmem_mask[1]) dmem[o_dmem_addr[DMEM_ABITS+1:2]][15: 8] <= o_dmem_wdata[15: 8];
            if (o_dmem_mask[2]) dmem[o_dmem_addr[DMEM_ABITS+1:2]][23:16] <= o_dmem_wdata[23:16];
            if (o_dmem_mask[3]) dmem[o_dmem_addr[DMEM_ABITS+1:2]][31:24] <= o_dmem_wdata[31:24];
        end
    end

    always #5 i_clk = ~i_clk;

    // ------------------------------------------------------------------
    // Trace plumbing
    // ------------------------------------------------------------------
    reg [8*256:1] line;
    reg [8*256:1] trace_path;
    reg [8*256:1] program_path;
    integer fd, i;

    reg [31:0] t_pc, t_inst;
    reg        e_trap, e_halt;
    reg [ 4:0] e_rs1_raddr;
    reg [31:0] e_rs1_rdata;
    reg [ 4:0] e_rs2_raddr;
    reg [31:0] e_rs2_rdata;
    reg [ 4:0] e_rd_waddr;
    reg [31:0] e_rd_wdata;
    reg [ 1:0] e_mem_op;
    reg [31:0] e_mem_addr;
    reg [ 3:0] e_mem_mask;
    reg [31:0] e_mem_wdata;
    reg [31:0] e_next_pc;

    integer vec, pass_count, fail_count, reported, vec_fails;

    reg [8*32:1] grp_name  [0:MAX_GROUPS-1];
    integer      grp_total [0:MAX_GROUPS-1];
    integer      grp_fail  [0:MAX_GROUPS-1];
    reg [8*32:1] section;
    integer      ngroups;
    integer      grp;

    function [8*32:1] current_group(input integer g);
        current_group = (g < 0) ? "-" : grp_name[g];
    endfunction

    // Compare one field against the trace. A column the trace left as a
    // don't-care reads back with x bits in it, and is skipped -- same
    // reduction-XOR idiom phase 2's decoder_trace_tb.v uses.
    task chk(input [8*20:1] signame, input [31:0] got, input [31:0] exp);
        begin
            if ((^exp !== 1'bx) && (got !== exp)) begin
                if (vec_fails == 0 && reported < MAX_REPORT) begin
                    reported = reported + 1;
                    $display("[FAIL] vector %0d (%0s): pc=%h inst=%h",
                             vec, current_group(grp), t_pc, t_inst);
                end
                if (reported <= MAX_REPORT)
                    $display("         %0s: got %h, expected %h", signame, got, exp);
                vec_fails = vec_fails + 1;
            end
        end
    endtask

    // Store data is only meaningful in the byte lanes the mask selects; a
    // submission may leave the others as garbage or a replicated byte.
    task chk_store_data(input [31:0] got, input [31:0] exp, input [3:0] mask);
        integer lane;
        reg [7:0] g, e;
        begin
            for (lane = 0; lane < 4; lane = lane + 1) begin
                if (mask[lane]) begin
                    g = got[lane*8 +: 8];
                    e = exp[lane*8 +: 8];
                    if (g !== e) begin
                        if (vec_fails == 0 && reported < MAX_REPORT) begin
                            reported = reported + 1;
                            $display("[FAIL] vector %0d (%0s): pc=%h inst=%h",
                                     vec, current_group(grp), t_pc, t_inst);
                        end
                        if (reported <= MAX_REPORT)
                            $display("         mem_wdata lane %0d: got %h, expected %h",
                                     lane, g, e);
                        vec_fails = vec_fails + 1;
                    end
                end
            end
        end
    endtask

    initial begin
        if (!$value$plusargs("trace=%s", trace_path))
            trace_path = "vectors/hart.trace";
        if (!$value$plusargs("program=%s", program_path))
            program_path = "vectors/hart_program.hex";

        for (i = 0; i < IMEM_WORDS; i = i + 1) imem[i] = 32'h0;
        for (i = 0; i < DMEM_WORDS; i = i + 1) dmem[i] = 32'h0;
        $readmemh(program_path, imem);

        fd = $fopen(trace_path, "r");
        if (fd == 0) begin
            $display("ERROR: cannot open trace file %0s", trace_path);
            $display("       run this from the directory holding vectors/, or");
            $display("       pass +trace=<path> (and +program=<path>) on the command line.");
            $finish;
        end

        $display("========== Hart trace test ==========");
        $display("program: %0s", program_path);
        $display("trace:   %0s", trace_path);

        i_clk = 1'b0;
        i_rst = 1'b1;
        vec = 0;
        pass_count = 0;
        fail_count = 0;
        reported = 0;
        ngroups = 0;
        grp = -1;

        @(posedge i_clk);
        @(posedge i_clk);
        i_rst = 1'b0;

        while ($fgets(line, fd) > 0) begin
            if ($sscanf(line, "# --- %s", section) == 1) begin
                if (ngroups < MAX_GROUPS) begin
                    grp_name[ngroups]  = section;
                    grp_total[ngroups] = 0;
                    grp_fail[ngroups]  = 0;
                    grp = ngroups;
                    ngroups = ngroups + 1;
                end
            end else if ($sscanf(line, "%h %h %h %h %h %h %h %h %h %h %h %h %h %h %h",
                        t_pc, t_inst, e_trap, e_halt, e_rs1_raddr, e_rs1_rdata,
                        e_rs2_raddr, e_rs2_rdata, e_rd_waddr, e_rd_wdata,
                        e_mem_op, e_mem_addr, e_mem_mask, e_mem_wdata,
                        e_next_pc) == FIELDS) begin
                vec = vec + 1;
                if (grp >= 0) grp_total[grp] = grp_total[grp] + 1;
                vec_fails = 0;

                @(posedge i_clk);
                // Sample every DUT output referenced below *now*, with no
                // added delay: a wire driven combinationally off a register
                // (PC, dmem contents) still reflects its pre-edge value at
                // this instant, per IEEE nonblocking-assignment semantics --
                // exactly the technique phase_2/local/project2/rtl/rf_tb.v's
                // header comment documents, and phase_3/local's own
                // hart_tb.v relies on for the same reason. Unlike phase 2's
                // *combinational* alu/decoder trace testbenches (which need
                // a real settle delay after changing an input, since there
                // is no clock at all), adding one here would let time pass
                // into the *next* cycle, after the DUT's registers have
                // already updated -- reading the wrong instruction entirely.

                chk("pc",         o_retire_pc,         t_pc);
                chk("inst",       o_retire_inst,       t_inst);
                chk("trap",       {31'b0, o_retire_trap}, {31'b0, e_trap});
                chk("halt",       {31'b0, o_retire_halt}, {31'b0, e_halt});
                chk("rs1_raddr",  {27'b0, o_retire_rs1_raddr}, {27'b0, e_rs1_raddr});
                chk("rs1_rdata",  o_retire_rs1_rdata,  e_rs1_rdata);
                chk("rs2_raddr",  {27'b0, o_retire_rs2_raddr}, {27'b0, e_rs2_raddr});
                chk("rs2_rdata",  o_retire_rs2_rdata,  e_rs2_rdata);
                chk("rd_waddr",   {27'b0, o_retire_rd_waddr}, {27'b0, e_rd_waddr});
                chk("rd_wdata",   o_retire_rd_wdata,   e_rd_wdata);
                chk("dmem_ren",   {31'b0, o_dmem_ren}, {31'b0, (e_mem_op == 2'd1)});
                chk("dmem_wen",   {31'b0, o_dmem_wen}, {31'b0, (e_mem_op == 2'd2)});
                if (e_mem_op != 2'd0) begin
                    chk("dmem_addr", o_dmem_addr, e_mem_addr);
                    chk("dmem_mask", {28'b0, o_dmem_mask}, {28'b0, e_mem_mask});
                end
                if (e_mem_op == 2'd2)
                    chk_store_data(o_dmem_wdata, e_mem_wdata, e_mem_mask);
                chk("next_pc",    o_retire_next_pc,   e_next_pc);

                if (vec_fails == 0) begin
                    pass_count = pass_count + 1;
                end else begin
                    fail_count = fail_count + 1;
                    if (grp >= 0) grp_fail[grp] = grp_fail[grp] + 1;
                    if (reported == MAX_REPORT) begin
                        reported = reported + 1;
                        $display("... further failures counted but not printed");
                    end
                end
            end
        end
        $fclose(fd);

        $display("\n---------- summary ----------");
        $display("vectors: %0d   passed: %0d   failed: %0d", vec, pass_count, fail_count);
        for (i = 0; i < ngroups; i = i + 1) begin
            $display("  %s  %0d/%0d %0s", grp_name[i],
                     grp_total[i] - grp_fail[i], grp_total[i],
                     (grp_fail[i] == 0) ? "ok" : "<-- FAIL");
        end
        for (i = 0; i < ngroups; i = i + 1) begin
            if (grp_fail[i] > 0)
                $display("[%0s FAILURE]", grp_name[i]);
        end

        if (vec == 0) begin
            $display("\nTEST FAILED: the trace file held no vectors.");
        end else if (fail_count == 0) begin
            $display("\nTEST PASSED: all %0d vectors matched.", vec);
        end else begin
            $display("\nTEST FAILED: %0d of %0d vectors wrong.", fail_count, vec);
        end

        $finish;
    end

endmodule

`default_nettype wire
