#!/usr/bin/env python3
"""
Native markdownlint for pm-workspace — no npm dependency.
Based on DavidAnson/markdownlint rule specifications.

Usage:
  python3 -m scripts.markdownlint [--config .markdownlint.json] FILE...
  python3 -m scripts.markdownlint --fix FILE...

Exit codes: 0 = clean, 1 = errors found, 2 = usage error
"""
import sys, re, os, argparse
from .config import load_config
from .rules import Linter


def autofix(content):
    """Apply automatic fixes for MD012, MD022, MD047."""
    content = re.sub(r'\n{3,}', '\n\n', content)
    lines = content.split('\n')
    result = []
    for i, line in enumerate(lines):
        prev = result[-1] if result else ''
        nxt = lines[i+1] if i < len(lines)-1 else ''
        if re.match(r'^#{1,6}\s', line) and prev.strip() != '' and i > 0:
            result.append('')
        result.append(line)
        if re.match(r'^#{1,6}\s', line) and nxt.strip() != '':
            result.append('')
            continue
    content = '\n'.join(result)
    content = re.sub(r'\n{3,}', '\n\n', content)
    content = content.rstrip('\n') + '\n'
    return content


def format_errors(errors):
    for fp, ln, rule, alias, msg in sorted(errors, key=lambda e: (e[0], e[1])):
        print(f"{fp}:{ln} error {rule}/{alias} {msg}")


def main():
    parser = argparse.ArgumentParser(
        description="Native markdownlint for pm-workspace")
    parser.add_argument("files", nargs="+", help="Markdown files to lint")
    parser.add_argument("--config", default=".markdownlint.json",
                        help="Config file (default: .markdownlint.json)")
    parser.add_argument("--fix", action="store_true",
                        help="Auto-fix common issues in place")
    args = parser.parse_args()
    cfg = load_config(args.config)

    if args.fix:
        for filepath in args.files:
            if not os.path.isfile(filepath):
                print(f"File not found: {filepath}", file=sys.stderr)
                continue
            with open(filepath) as f:
                content = f.read()
            fixed = autofix(content)
            if fixed != content:
                with open(filepath, 'w') as f:
                    f.write(fixed)
                print(f"Fixed: {filepath}")
            else:
                print(f"Clean: {filepath}")
        return 0

    linter = Linter(cfg)
    for filepath in args.files:
        if not os.path.isfile(filepath):
            print(f"File not found: {filepath}", file=sys.stderr)
            continue
        with open(filepath) as f:
            content = f.read()
        linter.lint(filepath, content)

    if linter.errors:
        format_errors(linter.errors)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
