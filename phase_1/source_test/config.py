"""Every path, test name, filename pattern and limit this harness uses.

Defined once, here. grade_test.py reads all of them from this module and
hardcodes none of them, so retuning the harness means editing one file.
"""

import os

# The harness root. source_test/ carries its own copies of the configuration-1
# .data blocks, the reference test programs, the expected outputs and the RARS
# jar, so this directory can be zipped and run on its own; nothing here reaches
# outside it.
SOURCE_TEST_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIGS_DIR = os.path.join(SOURCE_TEST_DIR, "configs")
TESTS_DIR = os.path.join(SOURCE_TEST_DIR, "tests")
EXPECTED_ASSEMBLY_DIR = os.path.join(SOURCE_TEST_DIR, "expected", "assembly")
EXPECTED_ASSEMBLER_DIR = os.path.join(SOURCE_TEST_DIR, "expected", "assembler")

# The RARS jar ships in this directory under the default name. A jar named in
# the environment wins over it.
RARS_JAR_ENV = "AUTOGRADER_RARS_JAR"
DEFAULT_RARS_JAR = os.path.join(SOURCE_TEST_DIR, "rars1_6.jar")

# The single configuration this harness runs. The real grader runs three.
CONFIG = 1

ASSEMBLY_TESTS = ["gemm", "mult", "sobel", "addition"]
# The assembler half runs only on programs whose source may ship publicly:
# gemm.s, mult.s and sobel.s are the solutions students must write themselves.
# all_instructions is assembler-only: there is no student all_instructions.s,
# and it has no .data configuration.
ASSEMBLER_TESTS = ["addition", "all_instructions"]

# Per-program RARS memory-dump range: start address, last word dumped.
RARS_RANGES = {
    "mult": ("0x10010008", "0x10010008"),
    "addition": ("0x10010008", "0x10010008"),
    "gemm": ("0x10010080", "0x100100bc"),
    "sobel": ("0x100100ac", "0x100100cc"),
}

# Programs with more than one accepted answer, as the filename suffixes that
# follow "<program>_cfg<N>" in expected/assembly/<program>/. A run matching ANY
# one of them passes. A program absent from this table has the single
# unsuffixed file, "<program>_cfg<N>.txt".
#
# sobel has two, because the assignment as it went out left its final step
# ambiguous. Both are computed from the same configs/sobel/1.data:
#   _correct  the handout's combining step, C = gx + gy
#   _exp      the squared magnitude, C = gx^2 + gy^2, which is what the
#             expected output originally shipped to students was generated from
# Neither can be called wrong from a student's side, so both are credited.
EXPECTED_ASSEMBLY_VARIANTS = {
    "sobel": ["_correct", "_exp"],
}

# The four files the student's assembler must produce, as
# (label, generated filename, expected filename). The generated names carry no
# configuration infix: the assembler is handed <name>.s and always writes
# <name>.hex.txt. Only the expected files are split per configuration.
ASSEMBLER_OUTPUTS = [
    ("Instruction Hex", "{n}.hex.txt", "{n}{cfg}_sol.hex.txt"),
    ("Instruction Binary (bits)", "{n}.bin.txt", "{n}{cfg}_sol.bin.txt"),
    ("Data Hex", "{n}_data.hex.txt", "{n}{cfg}_sol_data.hex.txt"),
    ("Data Binary (bits)", "{n}_data.bin.txt", "{n}{cfg}_sol_data.bin.txt"),
]

# Per-child wall clock. A local tool still has to survive an assembler that
# loops forever.
TIMEOUT_SEC = 60

# Never searched when looking for a file in a submission.
JUNK_DIRS = frozenset([
    "__MACOSX", "__pycache__", ".git", "venv", ".venv", "env", "node_modules",
])


def rars_jar():
    """The env var is a preference, not a promise: take the first jar that
    actually exists, so a run with a stale variable still works."""
    candidates = [c for c in (os.environ.get(RARS_JAR_ENV), DEFAULT_RARS_JAR) if c]
    for candidate in candidates:
        if os.path.isfile(candidate):
            return candidate
    return candidates[0]      # keep the preferred path for the error message


def config_tag(name):
    """The infix separating one configuration's expected files from another.

    all_instructions has no configuration, so its expected files carry no infix.
    """
    return "_cfg%d" % CONFIG if name in ASSEMBLY_TESTS else ""


def data_block_path(program):
    return os.path.join(CONFIGS_DIR, program, "%d.data" % CONFIG)


def reference_program_path(name):
    return os.path.join(TESTS_DIR, name + ".s")


def expected_assembly_paths(program):
    """Every expected-output file accepted for a program, preferred one first.

    Usually a one-element list; a program in EXPECTED_ASSEMBLY_VARIANTS has one
    entry per accepted answer.
    """
    suffixes = EXPECTED_ASSEMBLY_VARIANTS.get(program, [""])
    return [os.path.join(EXPECTED_ASSEMBLY_DIR, program,
                         "%s_cfg%d%s.txt" % (program, CONFIG, suffix))
            for suffix in suffixes]


def expected_assembler_path(name, sol_pattern):
    return os.path.join(EXPECTED_ASSEMBLER_DIR, name,
                        sol_pattern.format(n=name, cfg=config_tag(name)))


def assembly_workdir(output_dir, program):
    return os.path.join(output_dir, "rars_%s_cfg%d" % (program, CONFIG))


def assembler_workdir(output_dir, name):
    return os.path.join(output_dir, "asm_%s" % name, "run" + config_tag(name))
