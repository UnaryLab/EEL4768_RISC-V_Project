# Phase 3 Documentation

You will find the documentation and problem descriptions for phase three in `phase_3/documentation/phase_3.pdf`. Be sure to **read all pages** of the PDF. There is one part to this phase, that breaks down as follows.

1. Single-Cycle RV32I CPU (`hart.v`)

# Install

I recommend using conda, as this will allow you to install everything needed.

https://docs.conda.io/projects/conda/en/latest/user-guide/install/index.html

Once you have conda, follow the instructions below.

### Linux/MacOS

```
git clone https://github.com/UnaryLab/EEL4768_RISC-V_Project
cd EEL4768_RISC-V_Project/phase_3/
conda env create -f environment.yaml
```
Then, you can activate the conda environment
```
conda activate eel4768_phase_3
```
You need to reactivate or make sure you are in this conda env before running the test script everytime.

### Windows

Icarus and GTK cannot be directly installed through conda. If you have a windows system, I recommend either using [wsl](https://learn.microsoft.com/en-us/windows/wsl/install) (Windows subsystem for linux), or you can use the [eustis server](https://www.youtube.com/watch?v=KGm5RdI_gNA).

Both of these solutions will run a linux operating system. If you have issues, please come to my office hours.

# Testing your work

**There is no autograder in this repository.** Verifying that your `hart.v`
runs real programs correctly is part of the assignment. Unlike phase 2, a CPU
executes one continuous program rather than independent vectors, so
`phase_3/traces/` ships the harness for you: a self-checking testbench, a
program image, and the trace it should retire. It is **not** the trace you are
graded on, so passing it is evidence your design is right rather than evidence
you matched one list of test cases. Writing your own testbenches on top of it
is still expected -- follow the example testbench outlined in `phase_2/example/`
to understand how to write one.

## The trace test

`phase_3/traces/` holds:

- **`vectors/hart_program.hex`** -- the program itself, as a flat instruction
  memory image (`$readmemh` format, one instruction per line, address = line
  number x4). Your design fetches from it at whatever address it computes.
- **`vectors/hart.trace`** -- one line per instruction actually retired, in
  execution order, one column per retire signal. Nothing in it is driven into
  your design; it is only compared against. A column written as `x` is a
  don't-care.
- **`rtl/hart_trace_tb.v`** and **`run_traces.sh`** -- the testbench that
  replays the two, and a script to compile and run it.

`phase_3/traces/README.md` documents the trace format, the don't-cares, and how
to read a failure.

## Run iverilog

Put your five `.v` files in `phase_3/traces/submission/` and run the script,
or point it at wherever your files already live:

```
cd traces
./run_traces.sh
./run_traces.sh ~/eel4768/phase_3
```

To run it by hand instead, or to run your own testbench, just replace the paths
for the testbench and target files:

```
iverilog -g2005 -s hart_trace_tb -o sim rtl/hart_trace_tb.v submission/hart.v submission/alu.v submission/imm.v submission/rf.v submission/decoder.v
vvp sim
```

`-s` names the top module to elaborate, `-o` names the simulator to write, and
every source file the design needs is listed after them. (`vvp sim`, not
`./sim` -- Icarus's compiled output needs to be handed to `vvp` explicitly.)

Running it prints:

```
=== hart ===
    ---------- summary ----------
    vectors: 22661   passed: 22661   failed: 0

    TEST PASSED: all 22661 vectors matched.
========================================
hart: PASSED
```

Every failure names the signal that disagreed and the instruction it disagreed
on. Because the whole trace is one continuous execution, a single wrong branch
target cascades into many `[FAIL]` lines -- always look at the **first** one.
The full output and the compile log are left in `traces/build/hart/`.

## Waveforms

The trace testbench does not write a VCD. To get one, add `$dumpfile`/`$dumpvars`
to a testbench of your own, the way `phase_2/example/opmux_tb.v` does, then:

```
gtkwave hart.vcd
```

This outputs a waveform, similar to the ones from digital systems, to view. This is helpfull for debugging.
