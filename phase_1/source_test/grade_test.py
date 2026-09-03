#!/usr/bin/env python3
"""Local pass/fail check of a phase-1 submission, configuration 1 only.

    python3 grade_test.py <submission_dir> <output_dir> <summary_file>

Six checks, no points: the four assembly programs under configuration 1, then
the two assembler tests (addition under configuration 1, plus all_instructions,
which has no configuration). Each check is PASS or FAIL, the summary is written
to <summary_file> and printed, and the process exits nonzero if any check
failed.

This is a self-check. The graded, Gradescope-facing autograder is a separate
program: it runs three configurations, awards points and sandboxes the code it
runs. Nothing here does.
"""

import os
import subprocess
import sys

sys.dont_write_bytecode = True   # no __pycache__ in a directory meant to be zipped

import config                                            # noqa: E402
from splice import splice                                # noqa: E402


# --------------------------------------------------------------------------
# Reading and comparing
# --------------------------------------------------------------------------

def read_text(path):
    with open(path, "r", newline=None, errors="replace") as f:
        return f.read()


def dump_lines(text):
    """The RARS memory-dump lines of a run."""
    return [line.rstrip() for line in text.splitlines()
            if line.startswith("Mem[") and line.strip()]


def expected_dump_lines(path):
    return [line.rstrip() for line in read_text(path).splitlines() if line.strip()]


def normalize(text):
    """Assembler-output comparison: ignore blank lines, surrounding spaces and
    hex letter case. CRLF is already gone -- read_text reads in text mode."""
    return [line.strip().lower() for line in text.splitlines() if line.strip()]


def count_differences(got, expected):
    return sum(1 for i in range(max(len(got), len(expected)))
               if (got[i] if i < len(got) else None)
               != (expected[i] if i < len(expected) else None))


def find_file(root, name):
    """The submission's copy of `name`, shallowest match first."""
    matches = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in config.JUNK_DIRS]
        if name in filenames:
            matches.append(os.path.join(dirpath, name))
    matches.sort(key=lambda path: (path.count(os.sep), path))
    return matches[0] if matches else None


def locate_output(rundir, filename):
    """The reference assembler writes into gen/ next to the .s file; some
    students write next to the .s file instead. Accept both."""
    for directory in (os.path.join(rundir, "gen"), rundir):
        candidate = os.path.join(directory, filename)
        if os.path.isfile(candidate) and not os.path.islink(candidate):
            return candidate
    return None


def run(cmd, cwd):
    """(combined output, timed_out, returncode)."""
    try:
        proc = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT,
                              timeout=config.TIMEOUT_SEC)
    except subprocess.TimeoutExpired:
        return "", True, None
    return proc.stdout.decode("utf-8", "replace"), False, proc.returncode


# --------------------------------------------------------------------------
# The two halves. Each returns (passed, reason); reason is shown only on FAIL.
#
# Both run the child directly in its output directory, so what a check produced
# -- the spliced program it was given, the RARS dump, the generated files --
# is left behind for inspection instead of being copied out of a scratch tree.
# --------------------------------------------------------------------------

def check_assembly(program, submission_dir, output_dir):
    """The student's .text, spliced with the configuration's .data, run on RARS."""
    jar = config.rars_jar()
    if not os.path.isfile(jar):
        return False, ("RARS jar not found at %s (set %s)"
                       % (jar, config.RARS_JAR_ENV))

    asm_name = program + ".s"
    student = find_file(submission_dir, asm_name)
    if student is None:
        return False, "%s not found in the submission" % asm_name
    try:
        spliced = splice(read_text(student),
                         read_text(config.data_block_path(program)))
    except ValueError as exc:
        return False, ("%s could not be spliced with the configuration's "
                       ".data: %s" % (asm_name, exc))

    workdir = config.assembly_workdir(output_dir, program)
    os.makedirs(workdir, exist_ok=True)
    with open(os.path.join(workdir, asm_name), "w") as f:
        f.write(spliced)

    start, end = config.RARS_RANGES[program]
    output, timed_out, _ = run(
        ["java", "-Xmx512m", "-Djava.awt.headless=true", "-jar", jar,
         "nc", "ae1", "se1", asm_name, "%s-%s" % (start, end)], workdir)
    if timed_out:
        return False, "RARS did not finish within %d s" % config.TIMEOUT_SEC

    got = dump_lines(output)
    with open(os.path.join(workdir, "dump.txt"), "w") as f:
        f.write("".join(line + "\n" for line in got))

    # RARS exits 0 even when assembly fails, so the dump line is the only
    # reliable signal that the program actually ran.
    if not any(("Mem[%s]" % start) in line for line in got):
        return False, ("no memory dump (no Mem[%s] line): the program did not "
                       "assemble, or crashed" % start)

    # A program can have more than one accepted answer -- see config.py's
    # EXPECTED_ASSEMBLY_VARIANTS. Matching any one of them passes.
    accepted = [expected_dump_lines(path)
                for path in config.expected_assembly_paths(program)
                if os.path.isfile(path)]
    if not accepted:
        return False, ("no expected output on file for %s under configuration "
                       "%d" % (program, config.CONFIG))
    if any(got == expected for expected in accepted):
        return True, ""

    # Report against the nearest accepted answer; the others say nothing about
    # how close this run came.
    nearest = min(accepted, key=lambda expected: count_differences(got, expected))
    alternatives = ("" if len(accepted) == 1
                    else " (nearest of %d accepted answers)" % len(accepted))
    return False, ("result memory differs from the expected %s-%s "
                   "(%d of %d line(s))%s"
                   % (start, end, count_differences(got, nearest),
                      len(nearest), alternatives))


def check_assembler(name, assembler_py, output_dir):
    """The student's assembler, run on the reference program for this test."""
    source = read_text(config.reference_program_path(name))
    if name in config.ASSEMBLY_TESTS:
        source = splice(source, read_text(config.data_block_path(name)))

    rundir = config.assembler_workdir(output_dir, name)
    os.makedirs(rundir, exist_ok=True)
    program = os.path.join(rundir, name + ".s")
    with open(program, "w") as f:
        f.write(source)

    _output, timed_out, returncode = run(
        [sys.executable, assembler_py, program], rundir)
    if timed_out:
        return False, ("your assembler did not finish within %d s"
                       % config.TIMEOUT_SEC)
    if returncode != 0:
        return False, ("your assembler exited %d (invoked as "
                       "python3 assembler.py %s.s)" % (returncode, name))

    for label, gen_pattern, sol_pattern in config.ASSEMBLER_OUTPUTS:
        gen_name = gen_pattern.format(n=name)
        gen_path = locate_output(rundir, gen_name)
        if gen_path is None:
            return False, "your assembler did not generate %s" % gen_name
        generated = normalize(read_text(gen_path))
        expected = normalize(read_text(
            config.expected_assembler_path(name, sol_pattern)))
        if generated != expected:
            return False, ("%s (%s) differs (%d of %d line(s))"
                           % (label, gen_name,
                              count_differences(generated, expected),
                              len(expected)))
    return True, ""


# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------

def config_note(name):
    return " (config %d)" % config.CONFIG if name in config.ASSEMBLY_TESTS else ""


def summary_text(submission_dir, results):
    passed = sum(1 for _label, ok, _reason in results if ok)
    width = max(len(label) for label, _ok, _reason in results)
    lines = ["Phase 1 local test -- configuration %d only" % config.CONFIG,
             "Submission: %s" % submission_dir,
             ""]
    for label, ok, reason in results:
        line = "%s  %s" % ("PASS" if ok else "FAIL", label.ljust(width))
        if not ok and reason:
            line += "  --  " + reason
        lines.append(line.rstrip())
    lines += ["", "%d/%d PASS" % (passed, len(results)), ""]
    return "\n".join(lines)


def main(argv):
    if len(argv) != 4:
        sys.stderr.write("usage: %s <submission_dir> <output_dir> "
                         "<summary_file>\n" % os.path.basename(argv[0]))
        return 2
    submission_dir, output_dir, summary_file = (os.path.abspath(a)
                                                for a in argv[1:])
    if not os.path.isdir(submission_dir):
        sys.stderr.write("ERROR: no such submission directory: %s\n"
                         % submission_dir)
        return 2
    os.makedirs(output_dir, exist_ok=True)

    assembler_py = find_file(submission_dir, "assembler.py")
    results = []
    for program in config.ASSEMBLY_TESTS:
        ok, reason = check_assembly(program, submission_dir, output_dir)
        results.append(("Assembly:  %s%s" % (program, config_note(program)),
                        ok, reason))
    for name in config.ASSEMBLER_TESTS:
        if assembler_py is None:
            ok, reason = False, "assembler.py not found in the submission"
        else:
            ok, reason = check_assembler(name, assembler_py, output_dir)
        results.append(("Assembler: %s%s" % (name, config_note(name)),
                        ok, reason))

    text = summary_text(submission_dir, results)
    os.makedirs(os.path.dirname(summary_file), exist_ok=True)
    with open(summary_file, "w") as f:
        f.write(text)
    sys.stdout.write(text)
    return 0 if all(ok for _label, ok, _reason in results) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
