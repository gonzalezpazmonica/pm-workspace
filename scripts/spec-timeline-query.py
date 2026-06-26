#!/usr/bin/env python3
"""spec-timeline-query.py — SPEC-182

Query the bitemporal `timeline:` arrays across one or multiple spec files.

Usage:
    # Single file
    python3 scripts/spec-timeline-query.py \
        --file docs/propuestas/SPEC-182-*.md \
        --format table

    # Directory scan with filters
    python3 scripts/spec-timeline-query.py \
        --dir docs/propuestas/ \
        --status APPROVED \
        --learned-after 2026-06-01 \
        --format csv

    # Point-in-time query (what status did a spec have at a date?)
    python3 scripts/spec-timeline-query.py \
        --file docs/propuestas/SPEC-156.md \
        --at 2026-04-01 \
        --format table

Formats: table (default), json, csv

Exit codes:
    0  Success (may print 0 rows)
    1  File/dir not found
    2  Usage error
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from datetime import date
from io import StringIO
from pathlib import Path
from typing import Iterator

# ── YAML frontmatter parser (no external deps) ────────────────────────────────

_FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


def _extract_frontmatter(text: str) -> str | None:
    m = _FM_RE.match(text)
    return m.group(1) if m else None


def _parse_timeline(fm_body: str) -> list[dict[str, str]]:
    """Parse the `timeline:` block from raw YAML fm_body.

    Returns list of dicts with keys: from, learned, value, source.
    Keys default to '' if absent.
    """
    lines = fm_body.split("\n")

    # Find timeline: block
    in_tl = False
    tl_lines: list[str] = []
    for line in lines:
        if re.match(r"^timeline\s*:", line):
            in_tl = True
            continue
        if in_tl:
            if line == "" or line.startswith("  ") or line.startswith("\t"):
                tl_lines.append(line)
            else:
                break

    if not tl_lines:
        return []

    entries: list[dict[str, str]] = []
    current: dict[str, str] | None = None

    for line in tl_lines:
        # New entry
        entry_start = re.match(r"^\s+-\s+from\s*:\s*[\"']?([^\"']+)[\"']?\s*$", line)
        if entry_start:
            if current is not None:
                entries.append(current)
            current = {"from": entry_start.group(1).strip(), "learned": "", "value": "", "source": ""}
            continue

        if current is None:
            continue

        for key in ("learned", "value", "source"):
            m = re.match(rf"^\s+{key}\s*:\s*[\"']?(.+?)[\"']?\s*$", line)
            if m:
                current[key] = m.group(1).strip().strip("\"'")
                break

    if current is not None:
        entries.append(current)

    return entries


def _get_spec_id(fm_body: str, fallback: str) -> str:
    m = re.search(r"^spec_id\s*:\s*(.+)", fm_body, re.MULTILINE)
    if m:
        return m.group(1).strip().strip("\"'")
    return fallback


# ── Row model ─────────────────────────────────────────────────────────────────

COLUMNS = ["file", "spec_id", "from", "learned", "value", "source"]


def _rows_from_file(path: Path) -> list[dict[str, str]]:
    text = path.read_text(encoding="utf-8")
    fm = _extract_frontmatter(text)
    if fm is None:
        return []
    entries = _parse_timeline(fm)
    spec_id = _get_spec_id(fm, path.stem)
    rows = []
    for e in entries:
        rows.append({
            "file": str(path),
            "spec_id": spec_id,
            "from": e.get("from", ""),
            "learned": e.get("learned", ""),
            "value": e.get("value", ""),
            "source": e.get("source", ""),
        })
    return rows


def _scan_dir(dir_path: Path) -> Iterator[Path]:
    for p in sorted(dir_path.glob("*.md")):
        yield p


# ── Filtering ─────────────────────────────────────────────────────────────────

def _filter_rows(
    rows: list[dict[str, str]],
    status: str | None,
    learned_after: str | None,
    at_date: str | None,
) -> list[dict[str, str]]:
    result = []
    for r in rows:
        if status and r["value"].upper() != status.upper():
            continue
        if learned_after and r["learned"] and r["learned"] < learned_after:
            continue
        if at_date:
            # Keep only the latest entry where from <= at_date
            if r["from"] > at_date:
                continue
        result.append(r)

    if at_date:
        # Per spec_id: keep only the entry with the latest "from" <= at_date
        by_spec: dict[str, dict[str, str]] = {}
        for r in result:
            key = (r["file"], r["spec_id"])
            existing = by_spec.get(str(key))
            if existing is None or r["from"] > existing["from"]:
                by_spec[str(key)] = r
        result = list(by_spec.values())

    return result


# ── Formatters ────────────────────────────────────────────────────────────────

def _fmt_table(rows: list[dict[str, str]]) -> str:
    if not rows:
        return "(no results)"

    # Determine column widths
    widths = {col: len(col) for col in COLUMNS}
    for r in rows:
        for col in COLUMNS:
            widths[col] = max(widths[col], len(r.get(col, "")))

    sep = "+" + "+".join("-" * (w + 2) for w in widths.values()) + "+"
    header = "|" + "|".join(f" {col.ljust(widths[col])} " for col in COLUMNS) + "|"

    lines = [sep, header, sep]
    for r in rows:
        line = "|" + "|".join(f" {r.get(col,'').ljust(widths[col])} " for col in COLUMNS) + "|"
        lines.append(line)
    lines.append(sep)
    return "\n".join(lines)


def _fmt_json(rows: list[dict[str, str]]) -> str:
    return json.dumps(rows, indent=2, ensure_ascii=False)


def _fmt_csv(rows: list[dict[str, str]]) -> str:
    buf = StringIO()
    writer = csv.DictWriter(buf, fieldnames=COLUMNS, extrasaction="ignore")
    writer.writeheader()
    writer.writerows(rows)
    return buf.getvalue()


FORMATTERS = {
    "table": _fmt_table,
    "json": _fmt_json,
    "csv": _fmt_csv,
}


# ── CLI ───────────────────────────────────────────────────────────────────────

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Query bitemporal timeline entries across spec files.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--file", help="Path to a single spec file")
    src.add_argument("--dir", help="Directory to scan for *.md spec files")

    parser.add_argument("--status", help="Filter by value (e.g. APPROVED)")
    parser.add_argument("--learned-after", dest="learned_after", metavar="YYYY-MM-DD",
                        help="Only entries learned on or after this date")
    parser.add_argument("--at", dest="at_date", metavar="YYYY-MM-DD",
                        help="Point-in-time query: what status at this date?")
    parser.add_argument("--format", choices=["table", "json", "csv"], default="table",
                        help="Output format (default: table)")

    args = parser.parse_args(argv)

    rows: list[dict[str, str]] = []

    if args.file:
        path = Path(args.file)
        if not path.exists():
            print(f"ERROR: file not found: {path}", file=sys.stderr)
            return 1
        rows = _rows_from_file(path)
    else:
        dir_path = Path(args.dir)
        if not dir_path.is_dir():
            print(f"ERROR: directory not found: {dir_path}", file=sys.stderr)
            return 1
        for p in _scan_dir(dir_path):
            rows.extend(_rows_from_file(p))

    rows = _filter_rows(rows, args.status, args.learned_after, args.at_date)

    fmt_fn = FORMATTERS[args.format]
    print(fmt_fn(rows))
    return 0


if __name__ == "__main__":
    sys.exit(main())
