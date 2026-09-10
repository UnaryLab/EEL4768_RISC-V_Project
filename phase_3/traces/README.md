# Phase 3 trace test

A self-checking testbench and the recorded vectors it replays, so you can
check `hart.v` on your own machine with nothing but Icarus Verilog. It
drives **22661 vectors** and checks **22661 sets of outputs** against what
an independent RV32I simulator (not any reference `hart.v`) computed for
exactly that execution.

| test | drives | vectors |
| --- | --- | --- |
| `hart` | `hart` (and `alu`/`imm`/`rf`/`decoder` inside it) | 22661 instructions actually retired |

This is **not** the trace you are graded on. It is a different, much larger
set covering the same behaviour, generated a different way (bulk random
generation with a fixed seed, rather than the hand-written programs the
grader uses) -- so passing here is evidence your design is right rather
than evidence you matched one particular list of test cases.

## Running it

Put your Verilog in `submission/` and run:

```sh
./run_traces.sh
```

or point it at wherever your files already live:

```sh
./run_traces.sh ~/eel4768/phase_3
```

Every `.v` and `.sv` file under that directory is compiled, so helper
modules are fine alongside the five required files
(`hart.v`/`alu.v`/`imm.v`/`rf.v`/`decoder.v`). It prints the test's output,
a pass/fail line at the end, and exits nonzero if anything failed. The
compile log and full output land in `build/hart/`.

If `iverilog`/`vvp` are not on your `PATH`, either put them there or say
where they are:

```sh
IVERILOG=/opt/iverilog/bin/iverilog VVP=/opt/iverilog/bin/vvp ./run_traces.sh
```

### Running it by hand

Nothing about this testbench is special -- compile it the way you compile
your own:

```sh
iverilog -g2005 -s hart_trace_tb -o sim rtl/hart_trace_tb.v \
    submission/hart.v submission/alu.v submission/imm.v submission/rf.v submission/decoder.v
vvp sim
```

(`vvp sim`, not `./sim` -- Icarus's compiled output needs to be handed to
`vvp` explicitly; a direct `./sim` only works by accident on some Unix
shells and never on Windows.)

The testbench looks for `vectors/hart.trace` and `vectors/hart_program.hex`
relative to the directory you run it from. To keep them somewhere else,
pass the paths in:

```sh
vvp sim +trace=/home/you/traces/vectors/hart.trace +program=/home/you/traces/vectors/hart_program.hex
```

## Reading a failure

Failures print as they happen, up to twenty of them before the testbench
goes quiet and just counts:

```
[FAIL] vector 9645 (LOAD_STORE.SB_LB): pc=000096b0 inst=009f8123
         mem_wdata lane 3: got ff, expected 2a
```

Then a summary, broken down by group, and a final verdict line:

```
---------- summary ----------
vectors: 22661   passed: 22600   failed: 61
  LOAD_STORE.SB_LB  300/360 <-- FAIL
  ...
[LOAD_STORE.SB_LB FAILURE]

TEST FAILED: 61 of 22661 vectors wrong.
```

The group names are the ones the autograder reports, so a
`[LOAD_STORE.SB_LB FAILURE]` here points at the same kind of check that
will fail there -- though not the identical vectors (see above).

Vector numbers count retired instructions, in the order your design
actually retired them -- not lines in the trace file (comments, blank
lines, and `# --- GROUP ---` markers are skipped and not counted) and not
addresses in the program (a loop revisits the same address multiple times,
each one its own vector; a taken branch's skipped instructions are never
retired at all, so they never get a vector number).

## The trace files

Two files work together, unlike phase 2's alu/decoder/imm/rf traces (which
only ever needed one each):

- **`vectors/hart_program.hex`** -- the actual program, as a flat
  instruction memory image (`$readmemh` format, one instruction per line,
  address = line number x4). This gets loaded into a real instruction
  memory once, up front. Your `hart.v` fetches from it the same way it
  would fetch from real memory -- at whatever address it computes itself.
- **`vectors/hart.trace`** -- what your design should retire, one line per
  instruction *actually retired*, in the order it actually happens (not
  memory order). This is the only thing checked against; nothing in it is
  driven into your design.

Every column in `hart.trace` is a signal, exactly like phase 2's trace
files. The header numbers them and names the signal each belongs to:

```
# columns, left to right:
#
#   context for this vector (also loaded into the program image):
#    1  pc           [31:0]
#    2  inst         [31:0]
#
#   compare these against the design's outputs:
#    3  trap
#    4  halt
#    5  rs1_raddr    [4:0]
...
```

and the same list appears in short form directly above every block of
vectors. Columns are all hex. Lines starting with `#`, and blank lines, are
comments.

### Don't-cares

A column written as `x` (or `xx`, `xxxxxxxx`) is a **don't-care**: the
testbench does not check it, and whatever your design drives there is
accepted. This matters for:

- **`rs1_raddr`/`rs1_rdata`** and **`rs2_raddr`/`rs2_rdata`** -- only
  checked for instructions that actually read that operand. rs1 is
  checked for `OP`, `OP-IMM`, `LOAD`, `STORE`, `BRANCH` and `JALR`, and
  not for `LUI`, `AUIPC`, `JAL` or illegal encodings; rs2 is checked for
  `OP`, `STORE` and `BRANCH`, and not for anything else. It's a
  *class*-based rule, not "whenever the value happens to be 0," so an
  instruction reading `x0` on purpose (`addi x1, x0, 5`) is still fully
  checked.
- **`rd_wdata`** -- only checked when `rd_waddr != 0`. When nothing is
  written, the value is architecturally irrelevant (your register file's
  own write-address gating discards it either way), so it isn't required
  to be any particular thing.
- **`mem_addr`/`mem_mask`/`mem_wdata`** -- only checked when `mem_op != 0`
  (i.e. an actual load or store happened this cycle). `mem_wdata` is
  additionally only compared on the byte lanes `mem_mask` selects, even
  when it *is* checked -- the untouched lanes may hold garbage or a
  replicated byte.

Everything else, including on illegal or trapped instructions, is checked
exactly -- there is no other don't-care anywhere in this trace.

### What the trace exercises

The program was generated once, with a fixed seed, by an instructor-side
generator (not shipped here) and covers, in this order: every R-type and I-type ALU op (grouped
individually, e.g. `ALU_R.ADD`, the same way phase 2's `alu.trace` groups
by operation); every load/store width at varied byte offsets; all six
branch ops, taken and not-taken, plus the largest 4-byte-aligned positive
and negative offsets; `jal`/`jalr` including the link register and
`jalr`'s LSB-masking; `lui`/`auipc`; `x0` write-discard/read-zero through
real instruction sequences; illegal encodings and misaligned
half-word/word accesses (never a byte access, which cannot be
misaligned); back-to-back
write-then-read hazards; and a handful of small backward-branching loops.
One `ebreak` ends the whole thing.

### The whole trace runs as one continuous execution

Unlike phase 2's `alu`/`decoder`/`imm` traces (10000 independent vectors,
any one of which could be deleted without affecting any other), this is
one program from reset to `ebreak` -- much closer in spirit to phase 2's
`rf_no_bypass.trace`/`rf_bypass.trace` (10000 consecutive cycles on one
register file instance). A register written near the start is expected to
still hold that value tens of thousands of instructions later; a wrong
branch/jump target doesn't just fail one vector, it fetches a different
instruction than expected for every vector after it, so a single control-
flow bug can cascade into a large number of `[FAIL]` lines from one root
cause. If you see many failures at once, look at the *first* one -- later
ones downstream of it are often just consequences, not independent bugs.

## What this does not do

It does not check style, does not check that your Verilog is
synthesizable, and does not run the rule checker the autograder runs. It
is a functional check only: a design can pass this trace and still lose
points for using a construct the project rules forbid. Re-read the
Verilog coding rules in `../documentation/phase_3.pdf` before
submitting.
