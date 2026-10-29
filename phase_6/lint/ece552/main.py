import argparse
import sys
from .validate import validate


def command_validate(args):
    errors = validate(filenames=args.filenames, werror=args.werror)
    if len(errors) > 0:
        print("\n\n".join(map(str, errors)), file=sys.stderr, end="")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="ECE 552 tools"
    )
    subparsers = parser.add_subparsers(
        title="commands",
        dest="command",
        required=True
    )

    validate_parser = subparsers.add_parser(
            "validate",
            help="Validate (System)Verilog code for syntax, synthesizability and ECE 552 compliance"
    )
    validate_parser.set_defaults(func=command_validate)
    validate_parser.add_argument(
        "filenames",
        nargs="+",
        help="One or more input files to validate",
    )
    validate_parser.add_argument(
        "-w",
        dest="werror",
        action="store_true",
        help="Treat all warnings as errors"
    )

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
