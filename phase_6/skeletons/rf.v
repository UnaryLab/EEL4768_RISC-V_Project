`default_nettype none

// The register file is effectively a single cycle memory with 32-bit words
// and depth 32. It has two asynchronous read ports, allowing two independent
// registers to be read at the same time combinationally, and one synchronous
// write port, allowing a register to be written to on the next clock edge.
//
// The register `x0` is hardwired to zero.
// NOTE: This can be implemented either by silently discarding writesto
// address 5'd0, or by muxing the output to zero when reading from that
// address.
//
// Phase 6: the same module also holds the 32 floating-point registers
// f0-f31, with three read ports (the fused multiply-add instructions read
// rs3) and a write port with an explicit write enable. Unlike x0, f0 is an
// ordinary register, so address 5'd0 cannot mean "no write" there.
module rf #(
    // When this parameter is set to 1, "RF bypass" mode is enabled. This
    // allows data at the write port to be observed at the read ports
    // immediately without having to wait for the next clock edge. This is
    // a common forwarding optimization in a pipelined core (phase 5), but will
    // cause a single-cycle processor to behave incorrectly. You are required
    // to implement and test both modes. In phase 4, you will disable this
    // parameter, before enabling it in phase 6.
    parameter BYPASS_EN = 0
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Both read register ports are asynchronous (zero-cycle). That is, read
    // data is visible combinationally without having to wait for a clock.
    //
    // The read ports are *independent* and can read two different registers
    // (but of course, also the same register if needed).
    //
    // Register `x0` is hardwired to zero, so reading from address 5'd0
    // should always return 32'd0 on either port regardless of any writes.
    //
    // Register read port 1, with input address [0, 31] and output data.
    input  wire [ 4:0] i_rs1_raddr,
    output wire [31:0] o_rs1_rdata,
    // Register read port 2, with input address [0, 31] and output data.
    input  wire [ 4:0] i_rs2_raddr,
    output wire [31:0] o_rs2_rdata,
    // The register write port is synchronous. When write is enabled, the
    // data at the write port will be written to the specified register
    // at the next clock edge. When the writen enable is low, the register
    // file should remain unchanged at the clock edge.
    //
    // Write register enable, address [0, 31] and input data.
    input  wire [ 4:0] i_rd_waddr,
    input  wire [31:0] i_rd_wdata,
    // Floating-point read ports 1-3, with input address [0, 31] and output
    // data. All three are asynchronous and independent, like the integer
    // ports. f0 is an ordinary register.
    input  wire [ 4:0] i_frs1_raddr,
    output wire [31:0] o_frs1_rdata,
    input  wire [ 4:0] i_frs2_raddr,
    output wire [31:0] o_frs2_rdata,
    input  wire [ 4:0] i_frs3_raddr,
    output wire [31:0] o_frs3_rdata,
    // Floating-point write port: synchronous, written at the next clock edge
    // when the write enable is high (any address, f0 included).
    input  wire        i_frd_wen,
    input  wire [ 4:0] i_frd_waddr,
    input  wire [31:0] i_frd_wdata
);

// Write your code here.

endmodule

`default_nettype wire
