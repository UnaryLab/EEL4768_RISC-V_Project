# Phase 6 documentation

You can find the documentation and problem descriptions for phase six in `phase_6/documentation/phase_6.pdf`. Be sure to **read all pages** of the PDF. There are two parts to this phase. You also submit all previous files (that is, `hart.v`, `decoder.v`, `imm.v`, `alu.v`, `rf.v`, `cache.v`).

1. Integer multiply and divide (M extension), added to `alu.v`
2. Single-precision floating point (F extension): a new floating-point unit (`fpu.v`), the 32 floating-point registers in `rf.v`, and the matching `decoder.v` and `hart.v` changes

The skeletons in `phase_6/skeletons/` show the new `hart.v`, `alu.v`, `rf.v` and `decoder.v` ports, and the `fpu.v` module header. `imm.v` and `cache.v` are unchanged from phase 5.

> **You will need to re-install the conda environment for this phase.**

# Rubric
| Category | Points |
| -------- | -------- |
| Multiply and divide    | 1    |
| FP move and compare    | 1    |
| FP convert    | 1    |
| FP arithmetic (add, multiply, fused)    | 1    |
| FP divide and square root    | 1    |
| FP control and status    | 1    |
| Mixed    | 1    |
| Stalls and cache misses    | 1    |
| Total | 8 |


# Install

I recommend using conda, as this will allow you to install everything needed.

https://docs.conda.io/projects/conda/en/latest/user-guide/install/index.html

Once you have conda, follow the instructions below.

### Linux/MacOS

```
git clone https://github.com/UnaryLab/EEL4768_RISC-V_Project
cd EEL4768_RISC-V_Project/phase_6/
conda env create -f environment.yaml
```
Then, you can activate the conda environment
```
conda activate eel4768_phase_6
```
You need to reactivate or make sure you are in this conda env before running your testbench every time.

### Windows

Icarus and GTK cannot be directly installed through conda. If you have a windows system, I recommend either using [wsl](https://learn.microsoft.com/en-us/windows/wsl/install) (Windows subsystem for linux), or you can use the [eustis server](https://www.youtube.com/watch?v=KGm5RdI_gNA).

Both of these solutions will run a linux operating system. If you have issues, please come to my office hours.

# Testing your work

**There is no autograder in this repository.** Verifying that your `hart.v`,
`fpu.v`, `cache.v`, `alu.v`, `imm.v`, `rf.v` and `decoder.v` behave correctly is part of the assignment.
Your testbench also needs a main memory for your caches to talk to.
Follow the example testbench outlined in `phase_2/example/` to understand how to write a testbench.

## Linting

`lint/` holds a Verilog rule checker that the autograder runs.
**It only does design checking to see if your design breaks any rules. It does not validate the output or functionality of your design.**

To install it, run the following command from `phase_6/` with the conda environment active.

```
pip install ./lint
```

To check your design, run the checker on your files. The `-w` flag treats warnings as errors, as the autograder does.

```
ece552 validate -w hart.v fpu.v cache.v alu.v imm.v rf.v decoder.v
```

If the command prints nothing and exits with code 0, your files pass. Otherwise, each error names the file, the line, and the rule you broke.

## Example

`phase_2/example/` holds two files:

- **`opmux.v`** -- a small combinational module: four inputs (`i_a`, `i_b`,
  `i_sel`, `i_en`), two outputs (`o_result`, `o_zero`), and a two-bit select
  choosing between `+`, `-`, `<<` and `>>`.
- **`opmux_tb.v`** -- a self-checking testbench for it. **This is the file to
  read.** It is commented as a walkthrough, and its structure is the one every
  testbench you write this semester will have.

## Traces

`phase_6/traces/` holds one program for your hart to run and the data memory it must leave behind:

- **`random_program.hex`**: The initial instruction memory, loaded at `0x00400000`. It holds about 32000 random RV32IMF instructions in nine sections.
- **`random_dmem.hex`**: The expected final data memory, 32768 words starting at `0x10010000`.

There is no expected trace this time. Your testbench runs the program until the final `ebreak` retires, and then compares every word of its data memory with `random_dmem.hex`.
M and F results live in registers, so about every 40 instructions the program stores the registers it changed, plus `fflags`, to a register dump range in memory.
Section 6.1 of the PDF lists the dump range of each section and the cache configuration these files use.

## Run iverilog

To run the example testbench, follow the script below. To run your own verilog file and testbench, just replace the paths for the testbench and target file.

```
cd EEL4768_RISC-V_Project/phase_2/
iverilog -s opmux_tb -o sim example/opmux_tb.v example/opmux.v
./sim
```

For phase 6, list your testbench and every file your hart needs:

```
iverilog -g2005 -s hart_tb -o sim hart_tb.v hart.v fpu.v cache.v alu.v imm.v rf.v decoder.v
./sim
```

`-s` names the top module to elaborate, `-o` names the simulator to write, and
every source file the design needs is listed after them. `-g2005` compiles
the files as Verilog-2005, the same way grading does.

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

Add `$dumpfile`/`$dumpvars` to your own testbench the same way to get a waveform of your hart.

This outputs a waveform, similar to the ones from digital systems, to view. This is helpful for debugging.
