#!/usr/bin/env python3
"""SE-402 verify: files changed on the branch that no ledger record attributes.

A changed file is attributed when some ledger record for this repo root has a
sha256_after equal to the file's current content, or to its content in any
commit of base..HEAD (the edit was made, then committed). Deletions are
attributed by a record with an empty sha256_after for that path.
Ref: docs/specs/SE-402-attributed-edit-ledger.spec.md
"""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path


def git(root: Path, *args: str, binary: bool = False):
    res = subprocess.run(["git", *args], cwd=root, stdout=subprocess.PIPE,
                         stderr=subprocess.DEVNULL, check=False)
    if res.returncode != 0:
        return None
    return res.stdout if binary else res.stdout.decode("utf-8", "replace")


def load_exclusions(root: Path) -> list[str]:
    path = root / "config" / "edit-ledger-exclusions.txt"
    if not path.is_file():
        return []
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.append(line)
    return out


def excluded(rel: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(rel, p) or rel.startswith(p.rstrip("*")) and p.endswith("/**")
               for p in patterns)


def load_ledger(ledger_dir: Path, root: Path) -> dict[str, set[str]]:
    hashes: dict[str, set[str]] = {}
    if not ledger_dir.is_dir():
        return hashes
    root_s = str(root)
    for f in ledger_dir.glob("*.jsonl"):
        try:
            lines = f.read_text(encoding="utf-8").splitlines()
        except OSError:
            continue
        for line in lines:
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if rec.get("repo_root") != root_s:
                continue
            hashes.setdefault(rec.get("path", ""), set()).add(rec.get("sha256_after", ""))
    return hashes


def changed_files(root: Path, base: str) -> set[str]:
    files: set[str] = set()
    merge_base = (git(root, "merge-base", base, "HEAD") or "").strip()
    if merge_base:
        files.update(filter(None, (git(root, "diff", "--name-only", f"{merge_base}..HEAD") or "").splitlines()))
    files.update(filter(None, (git(root, "diff", "--name-only", "HEAD") or "").splitlines()))
    files.update(filter(None, (git(root, "ls-files", "--others", "--exclude-standard") or "").splitlines()))
    return files


def branch_versions(root: Path, base: str, rel: str) -> set[str]:
    """sha256 of every version of `rel` committed on base..HEAD."""
    out: set[str] = set()
    merge_base = (git(root, "merge-base", base, "HEAD") or "").strip()
    if not merge_base:
        return out
    for commit in filter(None, (git(root, "rev-list", f"{merge_base}..HEAD", "--", rel) or "").splitlines()):
        blob = git(root, "show", f"{commit}:{rel}", binary=True)
        out.add("" if blob is None else hashlib.sha256(blob).hexdigest())
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger-dir", required=True)
    ap.add_argument("--base", default="origin/main")
    ap.add_argument("--root", default=None)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--strict", action="store_true")
    a = ap.parse_args()

    root_s = a.root or (git(Path.cwd(), "rev-parse", "--show-toplevel") or "").strip()
    if not root_s:
        print("edit-ledger verify: not a git repository", file=sys.stderr)
        return 2
    root = Path(root_s).resolve()
    if git(root, "rev-parse", "--verify", a.base) is None:
        print(f"edit-ledger verify: base '{a.base}' not found", file=sys.stderr)
        return 2

    ledger = load_ledger(Path(a.ledger_dir), root)
    patterns = load_exclusions(root)
    unattributed = []
    for rel in sorted(changed_files(root, a.base)):
        if excluded(rel, patterns):
            continue
        known = ledger.get(rel)
        if not known:
            unattributed.append(rel)
            continue
        path = root / rel
        current = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else ""
        if current in known or known & branch_versions(root, a.base, rel):
            continue
        unattributed.append(rel)

    if a.json:
        print(json.dumps({"base": a.base, "unattributed": unattributed,
                          "count": len(unattributed)}, ensure_ascii=False))
    elif unattributed:
        print(f"{len(unattributed)} cambio(s) no atribuido(s):")
        for rel in unattributed:
            print(f"  - {rel}")
    else:
        print("OK: todos los cambios atribuidos")
    return 1 if (a.strict and unattributed) else 0


if __name__ == "__main__":
    sys.exit(main())
