import argparse
import sys
import pyslang
from prettyerr import Error
from .validators import *

registered_validators = [
    OperatorValidator,
    BehavioralValidator,
    SystemTaskValidator,
]


def build_diagnostics(compilation: pyslang.Compilation, werror: bool) -> tuple[pyslang.TextDiagnosticClient, pyslang.DiagnosticEngine]:
    client = pyslang.TextDiagnosticClient()
    client.showAbsPaths(False)
    client.showColors(True)
    client.showColumn(True)
    # client.showHierarchyInstance(False)
    client.showIncludeStack(False)
    client.showLocation(True)
    client.showMacroExpansion(True)
    client.showOptionName(False)
    client.showSourceLine(True)

    engine = pyslang.DiagnosticEngine(compilation.sourceManager)
    engine.setWarningsAsErrors(werror)
    engine.addClient(client)

    return client, engine


def compile(filenames: list[str], werror: bool):
    tree = pyslang.SyntaxTree.fromFiles(filenames)

    compilation = pyslang.Compilation()
    compilation.addSyntaxTree(tree)

    client, engine = build_diagnostics(compilation, werror)
    diagnostics = compilation.getAllDiagnostics()
    if diagnostics:
        for diag in diagnostics:
            engine.issue(diag)

        fmt = client.getString()
        print(fmt, end="", file=sys.stderr)

        if engine.numErrors > 0:
            return None

    return compilation


def validate(filenames: list[str], werror: bool) -> list[Error]:
    compilation = compile(filenames, werror=werror)
    if compilation is None:
        print("One or more syntax errors found during parsing, not running compliance checks.", file=sys.stderr)
        sys.exit(1)


    root = compilation.getRoot()
    errors: list[Error] = []
    for Validator in registered_validators:
        instance = Validator(compilation.sourceManager, compilation)
        root.visit(instance)
        errors.extend(instance.errors)

    return errors
