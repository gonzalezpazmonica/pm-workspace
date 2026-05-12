"""CLI: python3 -m structured_doc <command> [args]

Commands: lint, diff, validate, list-types
Default output: JSON (machine-readable). Flag --human for terminal-friendly text.
Exit codes: 0=ok, 1=findings/errors, 2=usage error, 3=internal failure.
"""
from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path

from .registry import list_types
from .result import Failure
from .findings import FindingsReport
from .linter.handler import lint_document
from .differ.handler import diff_documents
from .validator.handler import validate_document
from . import _bootstrap  # registers built-in types  # noqa: F401


def _emit(obj, human: bool = False) -> None:
    if human:
        sys.stdout.write(_format_human(obj) + "\n")
    else:
        if hasattr(obj, "model_dump"):
            obj = obj.model_dump()
        sys.stdout.write(json.dumps(obj, indent=2, default=str) + "\n")


def _format_human(obj) -> str:
    if isinstance(obj, FindingsReport):
        lines = []
        for f in obj.findings:
            sym = {"error": "E", "warning": "W", "info": "i"}.get(f.severity, "?")
            lines.append(f"[{sym}] {f.rule_id} @ {f.path}: {f.message}")
        s = obj.summary
        lines.append(f"-- errors={s.errors} warnings={s.warnings} info={s.info}")
        return "\n".join(lines)
    if hasattr(obj, "model_dump"):
        return json.dumps(obj.model_dump(), indent=2, default=str)
    return str(obj)


def _fail(msg: str, code: int = 2) -> int:
    sys.stderr.write(f"error: {msg}\n")
    return code


def cmd_lint(args) -> int:
    res = lint_document(args.type, args.file, args.rules)
    if not res.ok:
        return _fail(f"{res.error_kind}: {res.message}", code=3)
    _emit(res.value, human=args.human)
    return 1 if res.value.summary.errors > 0 else 0


def cmd_diff(args) -> int:
    res = diff_documents(args.type, args.file_a, args.file_b)
    if not res.ok:
        return _fail(f"{res.error_kind}: {res.message}", code=3)
    obj = res.value
    if args.regression_only and not obj.regression:
        _emit({"regression": False, "changes": []}, human=args.human)
        return 0
    _emit(obj, human=args.human)
    return 1 if obj.regression else 0


def cmd_validate(args) -> int:
    res = validate_document(args.type, args.file)
    if not res.ok:
        return _fail(f"{res.error_kind}: {res.message}", code=3)
    _emit(res.value, human=args.human)
    return 0 if res.value.valid else 1


def cmd_list_types(args) -> int:
    _emit({"types": list_types()}, human=args.human)
    return 0


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="structured_doc",
                                description="Tooling for structured Savia documents.")
    p.add_argument("--human", action="store_true",
                   help="Human-readable output (default: JSON)")
    sub = p.add_subparsers(dest="cmd", required=True)

    pl = sub.add_parser("lint", help="Lint a document against its rules YAML")
    pl.add_argument("type")
    pl.add_argument("file")
    pl.add_argument("--human", action="store_true")
    pl.add_argument("--rules", default=None,
                    help="Override rules file (default: registered)")
    pl.set_defaults(func=cmd_lint)

    pd = sub.add_parser("diff", help="Structural diff between two documents")
    pd.add_argument("type")
    pd.add_argument("file_a")
    pd.add_argument("file_b")
    pd.add_argument("--human", action="store_true")
    pd.add_argument("--regression-only", action="store_true")
    pd.set_defaults(func=cmd_diff)

    pv = sub.add_parser("validate", help="Validate frontmatter against JSON Schema")
    pv.add_argument("type")
    pv.add_argument("file")
    pv.add_argument("--human", action="store_true")
    pv.set_defaults(func=cmd_validate)

    pt = sub.add_parser("list-types", help="List registered document types")
    pt.add_argument("--human", action="store_true")
    pt.set_defaults(func=cmd_list_types)

    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
