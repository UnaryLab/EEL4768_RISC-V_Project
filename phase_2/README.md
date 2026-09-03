# Phase 2 Documentation

You will find the documentation and problem descriptions for phase two in `phase_2/documentation/phase_2.pdf`. Be sure to **read all pages** of the PDF. There are four parts to this phase, that break down as follows.

1. ALU

2. Immediate Generator

3. Register File

4. Instruction Decoder

`phase_2/skeletons/` has a starting point for each of the four: the module
header and the full port list, documented port by port, with the body left for
you.

# Install

I recommend using conda, as this will allow you to install everything needed.

https://docs.conda.io/projects/conda/en/latest/user-guide/install/index.html

Once you have conda, follow the instructions below.

### Linux/MacOS

```
git clone https://github.com/UnaryLab/EEL4768_RISC-V_Project
cd EEL4768_RISC-V_Project/phase_2/
conda env create -f environment.yaml
```
Then, you can activate the conda environment
```
conda activate eel4768_phase_2
```
You need to reactivate or make sure you are in this conda env before running the test script everytime.

### Windows

Icarus and GTK cannot be directly installed through conda. If you have a windows system, I recommend either using [wsl](https://learn.microsoft.com/en-us/windows/wsl/install) (Windows subsystem for linux), or you can use the [eustis server](https://www.youtube.com/watch?v=KGm5RdI_gNA).

Both of these solutions will run a linux operating system. If you have issues, please come to my office hours.

# Testing your work

**There is no autograder in this repository.** Verifying that your `alu.v`,
`imm.v`, `rf.v` and `decoder.v` behave correctly is part of the assignment.
Follow the example testbench outlined in `phase_2/example/` to understand how to write a testbench.

## The example

`phase_2/example/` holds two files:

- **`opmux.v`** -- a small combinational module: four inputs (`i_a`, `i_b`,
  `i_sel`, `i_en`), two outputs (`o_result`, `o_zero`), and a two-bit select
  choosing between `+`, `-`, `<<` and `>>`.
- **`opmux_tb.v`** -- a self-checking testbench for it. **This is the file to
  read.** It is commented as a walkthrough, and its structure is the one every
  testbench you write this semester will have.


## Run iverilog

To run the example testbench, follow the script below. To run your own verilog file and testbench, just replace the paths for the testbench and target file.

```
iverilog -s opmux_tb -o sim example/opmux_tb.v example/opmux.v
./sim
```

`-s` names the top module to elaborate, `-o` names the simulator to write, and
every source file the design needs is listed after them.

Running the example prints:

```
========== opmux testbench ==========
--- add ---
[PASS] add: 7 + 9
[PASS] add: 0 + 0 sets zero
...
212 passed, 0 failed
ALL TESTS PASSED
```

## Waveforms

The example also writes `opmux.vcd`:

```
gtkwave opmux.vcd
```

This outputs a waveform, similar to the ones from digital systems, to view. This is helpfull for debugging.
