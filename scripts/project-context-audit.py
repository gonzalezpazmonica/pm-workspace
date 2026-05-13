#!/usr/bin/env python3
"""Audit static/dynamic ratio in projects/<slug>/CLAUDE.md.

SPEC-PROJECT-CONTEXT-DISCIPLINE. Always informational (never blocks).
"""
from __future__ import annotations
import argparse
import os
import re
import sqlite3
import sys
from dataclasses import dataclass, field
from pathlib import Path

OPEN_RE = re.compile(r"<!--\s*\[(STATIC|DYNAMIC)\]\s*-->")
CLOSE_RE = re.compile(r"<!--\s*\[/(STATIC|DYNAMIC)\]\s*-->")
HEADING_RE = re.compile(r"^(#{2,3})\s+(.+)$")

MIN_BLOCK_LINES = 3
RATIO_TARGET = 0.80
PREREQ_MIN_TURNS = 200


@dataclass
class Block:
    kind: str  # STATIC | DYNAMIC | UNMARKED
    start: int
    end: int
    heading: str = ""

    @property
    def lines(self) -> int:
        return self.end - self.start + 1


@dataclass
class AuditResult:
    project: str
    file: Path
    total_lines: int
    blocks: list[Block] = field(default_factory=list)
    error: str | None = None

    @property
    def static_lines(self) -> int:
        return sum(b.lines for b in self.blocks if b.kind == "STATIC")

    @property
    def dynamic_lines(self) -> int:
        return sum(b.lines for b in self.blocks if b.kind == "DYNAMIC")

    @property
    def unmarked_lines(self) -> int:
        return sum(b.lines for b in self.blocks if b.kind == "UNMARKED")

    @property
    def static_ratio(self) -> float:
        if self.total_lines == 0:
            return 0.0
        return self.static_lines / self.total_lines


def parse_file(path: Path) -> AuditResult:
    project = path.parent.name
    result = AuditResult(project=project, file=path, total_lines=0)
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        result.error = f"cannot read file: {exc}"
        return result

    lines = text.splitlines()
    result.total_lines = len(lines)

    # Pass 1: find marker blocks (STATIC / DYNAMIC)
    open_kind: str | None = None
    open_line: int = 0
    marked_ranges: list[tuple[int, int, str]] = []  # (start, end, kind), 1-indexed inclusive

    for idx, line in enumerate(lines, start=1):
        mo = OPEN_RE.search(line)
        mc = CLOSE_RE.search(line)
        if mo:
            if open_kind is not None:
                result.error = (
                    f"nested or unclosed marker at line {idx}: "
                    f"opening [{mo.group(1)}] while [{open_kind}] still open"
                )
                return result
            open_kind = mo.group(1)
            open_line = idx
        elif mc:
            if open_kind is None:
                result.error = f"closing [/{mc.group(1)}] at line {idx} with no opening marker"
                return result
            if mc.group(1) != open_kind:
                result.error = (
                    f"mismatched closing at line {idx}: "
                    f"opened [{open_kind}] closed [/{mc.group(1)}]"
                )
                return result
            marked_ranges.append((open_line, idx, open_kind))
            open_kind = None

    if open_kind is not None:
        result.error = f"unclosed marker [{open_kind}] opened at line {open_line}"
        return result

    # Pass 2: build Block list. For UNMARKED, group by H2/H3 sections.
    covered = set()
    for start, end, kind in marked_ranges:
        heading = ""
        for i in range(start, min(end + 1, len(lines) + 1)):
            m = HEADING_RE.match(lines[i - 1])
            if m:
                heading = m.group(2)[:60]
                break
        block = Block(kind=kind, start=start, end=end, heading=heading)
        if block.lines >= MIN_BLOCK_LINES:
            result.blocks.append(block)
        for i in range(start, end + 1):
            covered.add(i)

    # Identify UNMARKED H2/H3 sections in gaps
    section_start: int | None = None
    section_heading: str = ""
    for idx, line in enumerate(lines, start=1):
        if idx in covered:
            if section_start is not None:
                _close_unmarked(result, section_start, idx - 1, section_heading, covered)
                section_start = None
            continue
        m = HEADING_RE.match(line)
        if m:
            if section_start is not None:
                _close_unmarked(result, section_start, idx - 1, section_heading, covered)
            section_start = idx
            section_heading = m.group(2)[:60]
    if section_start is not None:
        _close_unmarked(result, section_start, len(lines), section_heading, covered)

    result.blocks.sort(key=lambda b: b.start)
    return result


def _close_unmarked(result: AuditResult, start: int, end: int, heading: str, covered: set) -> None:
    real_lines = sum(1 for i in range(start, end + 1) if i not in covered)
    if real_lines < MIN_BLOCK_LINES:
        return
    block = Block(kind="UNMARKED", start=start, end=end, heading=heading)
    result.blocks.append(block)


def check_prereqs(usage_db: Path, project: str) -> tuple[bool, str]:
    if not usage_db.exists():
        return False, "usage.db not found (SPEC-CACHE-HIT-TRACKING not deployed)"
    try:
        conn = sqlite3.connect(f"file:{usage_db}?mode=ro", uri=True)
        cur = conn.cursor()
        cur.execute(
            "SELECT COUNT(*) FROM turns "
            "WHERE ts > datetime('now','-14 days') "
            "AND file_path LIKE ?",
            (f"projects/{project}/CLAUDE.md",),
        )
        row = cur.fetchone()
        conn.close()
        count = row[0] if row else 0
    except sqlite3.Error as exc:
        return False, f"usage.db query failed: {exc}"
    if count < PREREQ_MIN_TURNS:
        return False, f"only {count} turns in last 14d (need {PREREQ_MIN_TURNS})"
    return True, f"{count} turns"


def hit_rate_for_project(usage_db: Path, project: str) -> float | None:
    if not usage_db.exists():
        return None
    try:
        conn = sqlite3.connect(f"file:{usage_db}?mode=ro", uri=True)
        cur = conn.cursor()
        cur.execute(
            "SELECT SUM(cache_read), SUM(cache_write) FROM turns "
            "WHERE ts > datetime('now','-14 days') "
            "AND file_path LIKE ?",
            (f"projects/{project}/CLAUDE.md",),
        )
        row = cur.fetchone()
        conn.close()
        if not row or row[0] is None:
            return None
        read, write = row[0] or 0, row[1] or 0
        total = read + write
        if total == 0:
            return None
        return read / total
    except sqlite3.Error:
        return None


def workspace_dir() -> Path:
    return Path(
        os.environ.get("SAVIA_WORKSPACE_DIR")
        or os.environ.get("CLAUDE_PROJECT_DIR")
        or os.getcwd()
    )


def render(result: AuditResult, prereq_ok: bool, prereq_msg: str, hit_rate: float | None) -> int:
    print(f"Project: {result.project}")
    print(f"File:    {result.file}  ({result.total_lines} lines)")
    if result.error:
        print(f"ERROR:   {result.error}")
        return 1

    s, d, u = result.static_lines, result.dynamic_lines, result.unmarked_lines
    total = max(result.total_lines, 1)
    print(
        f"Ratio:   static={s} ({s*100//total}%), "
        f"dynamic={d} ({d*100//total}%), "
        f"unmarked={u} ({u*100//total}%)"
    )
    status = "OK" if result.static_ratio >= RATIO_TARGET else "WARNING"
    print(f"Status:  {status} (target: static >={int(RATIO_TARGET*100)}%)")
    print()

    if not prereq_ok:
        print(f"[INFORMATIONAL MODE — SPEC-CACHE-HIT-TRACKING pending: {prereq_msg}]")
    elif hit_rate is not None:
        print(f"[ENFORCING-CAPABLE — observed hit_rate(14d) = {hit_rate*100:.1f}%]")
    print()

    unmarked = [b for b in result.blocks if b.kind == "UNMARKED"]
    if unmarked:
        print("UNMARKED blocks:")
        for b in unmarked:
            print(f"  L{b.start:<5} {b.heading or '(no heading)'}")
        print()

    if result.static_ratio < RATIO_TARGET:
        dyn = [b for b in result.blocks if b.kind in ("DYNAMIC", "UNMARKED")]
        if dyn:
            print("DYNAMIC blocks candidatos a extracción:")
            for b in dyn:
                slug = re.sub(r"[^a-z0-9]+", "-", b.heading.lower()).strip("-") or "block"
                print(f"  L{b.start:<5} → projects/{result.project}/context/{slug}.md")
            print()

    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("slug", nargs="?", help="project slug under projects/")
    ap.add_argument("--file", help="explicit path to CLAUDE.md (overrides slug)")
    ap.add_argument("--db", default=str(Path.home() / ".savia" / "usage.db"))
    args = ap.parse_args()

    if args.file:
        path = Path(args.file)
        if not path.is_absolute():
            path = workspace_dir() / path
    elif args.slug:
        path = workspace_dir() / "projects" / args.slug / "CLAUDE.md"
    else:
        print("usage: project-context-audit.py <slug> | --file PATH", file=sys.stderr)
        return 2

    if not path.exists():
        print(f"ERROR: file not found: {path}", file=sys.stderr)
        return 2

    result = parse_file(path)
    usage_db = Path(args.db)
    prereq_ok, prereq_msg = check_prereqs(usage_db, result.project)
    hit_rate = hit_rate_for_project(usage_db, result.project) if prereq_ok else None
    return render(result, prereq_ok, prereq_msg, hit_rate)


if __name__ == "__main__":
    sys.exit(main())
