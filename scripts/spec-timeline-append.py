#!/usr/bin/env python3
"""spec-timeline-append.py — SPEC-182

Append a bitemporal timeline entry to the `timeline:` array in a spec's
YAML frontmatter.

Usage:
    python3 scripts/spec-timeline-append.py \
        --file docs/propuestas/SPEC-182-*.md \
        --from 2026-06-24 \
        --learned 2026-06-24 \
        --value IMPLEMENTED \
        --source "session:2026-06-24"

    --dry-run   Print what would be written; do not modify the file.

Exit codes:
    0  Success
    1  File not found or invalid frontmatter
    2  Usage error
"""
from __future__ import annotations

import argparse
import re
import sys
from datetime import date
from pathlib import Path

# ── YAML frontmatter helpers (no external deps) ───────────────────────────────

_FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


def _split_frontmatter(text: str) -> tuple[str, str, str]:
    """Return (open_fence, fm_body, rest_of_file).

    open_fence  : '---\\n'
    fm_body     : raw YAML between the fences (no fences)
    rest        : everything after the closing '---\\n'
    Raises ValueError if no valid frontmatter found.
    """
    m = _FM_RE.match(text)
    if not m:
        raise ValueError("No YAML frontmatter block found (expected leading ---)")
    fm_body = m.group(1)
    rest = text[m.end():]
    return "---\n", fm_body, rest


def _timeline_from_fm(fm_body: str) -> tuple[str, str, str]:
    """Split fm_body into (before_timeline, timeline_block, after_timeline).

    If no `timeline:` key exists, timeline_block is '' and before = full body.
    """
    lines = fm_body.split("\n")
    before: list[str] = []
    tl_lines: list[str] = []
    after: list[str] = []

    in_tl = False
    tl_done = False

    for line in lines:
        if tl_done:
            after.append(line)
        elif not in_tl:
            if re.match(r"^timeline\s*:", line):
                in_tl = True
                tl_lines.append(line)
            else:
                before.append(line)
        else:
            # Inside timeline block: belongs to it if indented or blank
            if line == "" or line.startswith("  ") or line.startswith("\t"):
                tl_lines.append(line)
            else:
                tl_done = True
                after.append(line)

    before_str = "\n".join(before)
    tl_str = "\n".join(tl_lines)
    after_str = "\n".join(after)
    return before_str, tl_str, after_str


def _build_entry(from_date: str, learned: str, value: str, source: str) -> str:
    """Build the YAML snippet for one timeline entry (4-space indented)."""
    lines = [
        f"  - from: \"{from_date}\"",
        f"    learned: \"{learned}\"",
        f"    value: \"{value}\"",
        f"    source: \"{source}\"",
    ]
    return "\n".join(lines)


def append_timeline(
    file_path: Path,
    from_date: str,
    learned: str,
    value: str,
    source: str,
    dry_run: bool = False,
) -> str:
    """Return the new file content after appending the timeline entry.

    Writes to *file_path* unless dry_run is True.
    """
    text = file_path.read_text(encoding="utf-8")

    try:
        fence, fm_body, rest = _split_frontmatter(text)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)

    before, tl_block, after = _timeline_from_fm(fm_body)

    new_entry = _build_entry(from_date, learned, value, source)

    if tl_block:
        # Strip trailing blank lines inside the existing block
        tl_stripped = tl_block.rstrip()
        new_tl_block = tl_stripped + "\n" + new_entry
    else:
        # Create timeline key + first entry
        new_tl_block = "timeline:\n" + new_entry

    # Reassemble frontmatter
    parts = []
    if before:
        parts.append(before)
    parts.append(new_tl_block)
    if after:
        parts.append(after)

    # Join with single newline between non-empty sections
    new_fm_body = "\n".join(p for p in parts if p is not None)

    new_text = fence + new_fm_body + "\n---\n" + rest

    if dry_run:
        print("[DRY-RUN] Would write:")
        print(new_text)
    else:
        file_path.write_text(new_text, encoding="utf-8")

    return new_text


# ── CLI ───────────────────────────────────────────────────────────────────────

def _iso_today() -> str:
    return date.today().isoformat()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Append a bitemporal timeline entry to a spec's frontmatter.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--file", required=True, help="Path to the spec file")
    parser.add_argument(
        "--from", dest="from_date", default=_iso_today(),
        help="Event date (when it happened). Default: today.",
    )
    parser.add_argument(
        "--learned", default=_iso_today(),
        help="Transaction date (when the workspace learned it). Default: today.",
    )
    parser.add_argument("--value", required=True, help="Status/value at this point in time")
    parser.add_argument("--source", default="manual", help="Source reference (e.g. git:commit/abc)")
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print what would be written without modifying the file",
    )

    args = parser.parse_args(argv)

    file_path = Path(args.file)
    if not file_path.exists():
        print(f"ERROR: file not found: {file_path}", file=sys.stderr)
        return 1

    append_timeline(
        file_path=file_path,
        from_date=args.from_date,
        learned=args.learned,
        value=args.value,
        source=args.source,
        dry_run=args.dry_run,
    )

    if not args.dry_run:
        print(f"Updated timeline in {file_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
