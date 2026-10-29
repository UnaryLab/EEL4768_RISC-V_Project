from pyslang import Token, SyntaxNode, CallExpression
from .validator import Validator


# System tasks/functions banned outright, regardless of context (unlike
# BehavioralValidator's blanket "calls must be constant expressions" check,
# this is a targeted, defense-in-depth list aimed specifically at:
#   - file I/O ($fopen/$fclose/$fgets/$fscanf/$fread/$fdisplay/$fwrite,
#     $readmemb/$readmemh/$writememb/$writememh): stock iverilog honors
#     arbitrary filesystem paths here, and the Dockerfile ships this whole
#     repo (including every project's reference/ solution RTL) into every
#     built grading image, so unrestricted file I/O in a submission is a
#     reference-solution exfiltration vector (read arbitrary reference/*.v
#     via $fopen/$readmemh and surface it in Gradescope-visible test output,
#     or exfiltrate via $writememh/$fwrite to a location an attacker can
#     later retrieve).
#   - simulation-control ($finish/$stop/$system): can truncate a
#     testbench's own simulation before its failure markers print (see
#     compile_and_run_project2_tb's docstring in submit.py for the related,
#     already-fixed rogue-top-level-module variant of this), or ($system)
#     shell out to the grading container outright.
# Detected via CallExpression.isSystemCall (True only for a genuine
# `$name(...)` system task/function call -- confirmed False, with
# subroutineName exactly matching the plain, unprefixed identifier, for an
# ordinary user-defined function/task call) combined with subroutineName
# (e.g. "$finish", "$fopen") being in this list.
BANNED_SYSTEM_TASKS = {
    "$fopen",
    "$fclose",
    "$fgets",
    "$fscanf",
    "$fread",
    "$fdisplay",
    "$fwrite",
    "$readmemb",
    "$readmemh",
    "$writememb",
    "$writememh",
    "$finish",
    "$stop",
    "$system",
}


class SystemTaskValidator(Validator):
    def __call__(self, obj: Token | SyntaxNode):
        if isinstance(obj, CallExpression):
            if obj.isSystemCall and obj.subroutineName in BANNED_SYSTEM_TASKS:
                srcfile = self.source_file(obj.sourceRange.start)
                self.report(
                    srcfile=srcfile,
                    title="use of banned system task/function",
                    messages=[(
                        Validator.span(obj.sourceRange),
                        f"{obj.subroutineName} is not allowed: file I/O and simulation-control "
                        "system tasks/functions are banned (not synthesizable, and not needed "
                        "for a correct submission)",
                    )],
                    hint="remove this call; it is never required for a synthesizable submission",
                )
