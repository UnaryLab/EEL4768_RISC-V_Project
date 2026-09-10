#!/usr/bin/env bash
# Run the phase-3 hart trace test against your submission.
#
# Usage:
#   ./run_traces.sh [submission_dir]
#
#   [submission_dir]  the directory holding your hart.v, alu.v, imm.v, rf.v
#                     and decoder.v. Defaults to ./submission next to this
#                     script.
#
# One test runs, driving 22661 recorded vectors -- a real, continuous
# execution through a large randomly-generated program covering every
# instruction type, not 22661 independent cases:
#
#   hart   22661 instructions actually retired
#
# It prints its own failures as it goes and a PASSED/FAILED line at the
# end; the full output is kept in build/hart/output.txt along with the
# compile log. This script exits nonzero on failure, so it can be wired
# into a Makefile or a git hook.
#
# It needs iverilog and nothing else. If iverilog is not on your PATH,
# either put it there or set IVERILOG to the binary:
#
#   IVERILOG=/opt/iverilog/bin/iverilog ./run_traces.sh
#
# To run it by hand instead:
#
#   iverilog -g2005 -s hart_trace_tb -o sim rtl/hart_trace_tb.v submission/*.v
#   vvp sim
#
# The testbench looks for vectors/hart.trace and vectors/hart_program.hex
# relative to the working directory; pass +trace=<path> and
# +program=<path> to point them somewhere else.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

SUBMISSION="${1:-${SCRIPT_DIR}/submission}"

IVERILOG="${IVERILOG:-iverilog}"
if ! command -v "${IVERILOG}" >/dev/null 2>&1; then
    echo "ERROR: iverilog not found (tried '${IVERILOG}')." >&2
    echo "Put it on your PATH, or set IVERILOG to the binary." >&2
    exit 1
fi

# Run the compiled simulation through vvp explicitly rather than executing
# it directly. iverilog's -o output is a vvp-format file with a
# #!/.../vvp shebang, which Unix can execute directly -- but Windows has no
# shebang support at all (even under Git Bash), so a direct "./sim" silently
# fails there with a generic "not found"/"did not run" error. vvp works
# identically on every platform, so this one form covers all of them.
VVP="${VVP:-vvp}"
if ! command -v "${VVP}" >/dev/null 2>&1; then
    echo "ERROR: vvp not found (tried '${VVP}')." >&2
    echo "It ships alongside iverilog; put it on your PATH, or set VVP to the binary." >&2
    exit 1
fi

if [[ ! -d "${SUBMISSION}" ]]; then
    echo "ERROR: no such directory: ${SUBMISSION}" >&2
    echo "Put hart.v, alu.v, imm.v, rf.v and decoder.v in ${SCRIPT_DIR}/submission/," >&2
    echo "or pass the directory holding them as the first argument." >&2
    exit 1
fi
SUBMISSION="$(cd "${SUBMISSION}" && pwd)"

# Every .v/.sv in the submission is handed to iverilog, whatever it is
# named: helper modules are as welcome as the five required files. -s <top>
# below keeps elaboration to the testbench's own module tree, so a
# testbench of your own in the same directory does not run alongside this
# one.
mapfile -t SOURCES < <(find "${SUBMISSION}" \
    \( -name '*.v' -o -name '*.sv' \) \
    -not -path '*/.git/*' -not -path '*/__MACOSX/*' \
    -not -path '*/obj_dir/*' | sort)

if [[ ${#SOURCES[@]} -eq 0 ]]; then
    echo "ERROR: no .v or .sv files under ${SUBMISSION}" >&2
    exit 1
fi

echo "iverilog:   $(command -v "${IVERILOG}")"
echo "submission: ${SUBMISSION}"
echo "sources:    ${#SOURCES[@]} file(s)"
echo

BUILD_DIR="${SCRIPT_DIR}/build"
rm -rf "${BUILD_DIR}"
work="${BUILD_DIR}/hart"
mkdir -p "${work}"

status=0

if ! "${IVERILOG}" -g2005 -s hart_trace_tb -o "${work}/sim" \
        "${SCRIPT_DIR}/rtl/hart_trace_tb.v" "${SOURCES[@]}" \
        > "${work}/build.log" 2>&1; then
    echo "=== hart: BUILD FAILED ==="
    sed 's/^/    /' "${work}/build.log"
    status=1
else
    echo "=== hart ==="
    # vvp always exits 0, so the verdict comes from the testbench's own
    # last line rather than from the exit status.
    if ! "${VVP}" "${work}/sim" \
            "+trace=${SCRIPT_DIR}/vectors/hart.trace" \
            "+program=${SCRIPT_DIR}/vectors/hart_program.hex" \
            > "${work}/output.txt" 2>&1; then
        echo "    simulation did not run to completion, see ${work}/output.txt"
        status=1
    else
        sed 's/^/    /' "${work}/output.txt"
        echo
        if ! grep -q "TEST PASSED" "${work}/output.txt"; then
            status=1
        fi
    fi
fi

echo "========================================"
if [[ ${status} -eq 0 ]]; then
    echo "hart: PASSED"
else
    echo "hart: FAILED"
fi
echo "========================================"
echo "artifacts: ${BUILD_DIR}"

if [[ ${status} -eq 0 ]]; then
    echo "All trace tests passed."
else
    echo "Some trace tests failed."
fi
exit "${status}"
