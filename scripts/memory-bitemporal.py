#!/usr/bin/env python3
"""memory-bitemporal.py — SPEC-153: bi-temporal memory extension for MEMORY.md.

Extends the memory system with two timestamps per entry:
- valid_at (occurred): when the fact/event actually happened
- learned_at (recorded): when it was registered in memory

Supports:
  --add --entry TEXT --occurred DATE --learned DATE
  --query --at DATE   (returns memory state as of that date)
  --list              (show all entries with timestamps)
  --export            (export as JSON)

Storage: ~/.savia/memory-bitemporal.db (SQLite, standalone)
Compatible with existing MEMORY.md format via optional sync.

Usage:
  python3 scripts/memory-bitemporal.py --add --entry "Use Redis for caching" \\
      --occurred 2026-01-15 --learned 2026-06-01
  python3 scripts/memory-bitemporal.py --query --at 2026-03-01
  python3 scripts/memory-bitemporal.py --list
"""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# ── Constants ─────────────────────────────────────────────────────────────────

DEFAULT_DB_PATH = Path.home() / ".savia" / "memory-bitemporal.db"
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}Z?)?$")


# ── DB ────────────────────────────────────────────────────────────────────────

def _connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS bt_entries (
            id          TEXT PRIMARY KEY,
            entry       TEXT NOT NULL,
            occurred    TEXT NOT NULL,
            learned     TEXT NOT NULL,
            invalidated TEXT,
            source      TEXT DEFAULT 'manual'
        )
        """
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_bt_occurred ON bt_entries(occurred)"
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_bt_learned  ON bt_entries(learned)"
    )
    conn.commit()
    return conn


def _now_iso() -> str:
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _today() -> str:
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%d")


def _validate_date(date_str: str, field: str) -> str:
    """Validate and normalise a date string to YYYY-MM-DD."""
    if not date_str:
        raise ValueError(f"{field}: date cannot be empty")
    if not DATE_RE.match(date_str):
        raise ValueError(
            f"{field}: invalid date format '{date_str}'. Expected YYYY-MM-DD."
        )
    return date_str[:10]  # normalise to YYYY-MM-DD


# ── Core operations ───────────────────────────────────────────────────────────

def add_entry(
    entry: str,
    occurred: str,
    learned: str,
    db_path: Path = DEFAULT_DB_PATH,
    source: str = "manual",
) -> dict:
    """Add a bi-temporal entry. Returns the new entry dict."""
    occurred = _validate_date(occurred, "occurred")
    learned = _validate_date(learned, "learned")

    entry_id = str(uuid.uuid4())[:8]
    conn = _connect(db_path)
    conn.execute(
        "INSERT INTO bt_entries (id, entry, occurred, learned, source) VALUES (?,?,?,?,?)",
        (entry_id, entry.strip(), occurred, learned, source),
    )
    conn.commit()
    conn.close()
    return {"id": entry_id, "entry": entry, "occurred": occurred, "learned": learned}


def query_at(at_date: str, db_path: Path = DEFAULT_DB_PATH) -> list[dict]:
    """
    Return all entries that were known (learned <= at_date) and still
    valid (not yet invalidated, or invalidated after at_date).
    """
    at_date = _validate_date(at_date, "at")
    conn = _connect(db_path)
    cur = conn.execute(
        """
        SELECT id, entry, occurred, learned, invalidated, source
        FROM bt_entries
        WHERE learned <= ?
          AND (invalidated IS NULL OR invalidated > ?)
        ORDER BY occurred DESC
        """,
        (at_date, at_date),
    )
    rows = [dict(r) for r in cur.fetchall()]
    conn.close()
    return rows


def list_all(db_path: Path = DEFAULT_DB_PATH) -> list[dict]:
    """Return all entries ordered by learned date desc."""
    conn = _connect(db_path)
    cur = conn.execute(
        "SELECT id, entry, occurred, learned, invalidated, source FROM bt_entries "
        "ORDER BY learned DESC"
    )
    rows = [dict(r) for r in cur.fetchall()]
    conn.close()
    return rows


def invalidate(entry_id: str, at_date: str | None = None,
               db_path: Path = DEFAULT_DB_PATH) -> bool:
    """Mark an entry as invalidated. Returns True if found."""
    at_date = at_date or _today()
    conn = _connect(db_path)
    cur = conn.execute(
        "UPDATE bt_entries SET invalidated=? WHERE id=? AND invalidated IS NULL",
        (at_date, entry_id),
    )
    conn.commit()
    changed = cur.rowcount > 0
    conn.close()
    return changed


def export_json(db_path: Path = DEFAULT_DB_PATH) -> list[dict]:
    """Export all entries as JSON list."""
    return list_all(db_path)


# ── MEMORY.md compatibility ───────────────────────────────────────────────────

def sync_to_memory_md(
    memory_md_path: Path,
    db_path: Path = DEFAULT_DB_PATH,
    at_date: str | None = None,
) -> int:
    """
    Append any entries not yet in MEMORY.md (detected by entry text).
    Returns count of entries appended.
    """
    at_date = at_date or _today()
    active = query_at(at_date, db_path)
    if not active:
        return 0

    existing = memory_md_path.read_text(encoding="utf-8") if memory_md_path.exists() else ""
    appended = 0
    lines_to_add: list[str] = []
    for e in active:
        # Only add if entry text not already present
        if e["entry"][:40] not in existing:
            lines_to_add.append(
                f"- {e['entry']} [occurred:{e['occurred']} learned:{e['learned']}]"
            )
            appended += 1

    if lines_to_add:
        with memory_md_path.open("a", encoding="utf-8") as fh:
            fh.write("\n".join(lines_to_add) + "\n")

    return appended


# ── CLI ───────────────────────────────────────────────────────────────────────

def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="SPEC-153 memory-bitemporal")
    p.add_argument("--db-path", default=str(DEFAULT_DB_PATH), help="SQLite DB path")
    p.add_argument("--quiet", action="store_true")

    sub = p.add_subparsers(dest="command")

    # --add
    add_p = sub.add_parser("add", aliases=["--add"])
    add_p.add_argument("--entry", required=True, help="Entry text")
    add_p.add_argument("--occurred", required=True, help="When it occurred (YYYY-MM-DD)")
    add_p.add_argument("--learned", default=None, help="When it was learned (default: today)")

    # --query
    qp = sub.add_parser("query", aliases=["--query"])
    qp.add_argument("--at", required=True, help="State-as-of date (YYYY-MM-DD)")

    # --list
    sub.add_parser("list", aliases=["--list"])

    # --export
    sub.add_parser("export", aliases=["--export"])

    # --invalidate
    inv_p = sub.add_parser("invalidate", aliases=["--invalidate"])
    inv_p.add_argument("--id", required=True, help="Entry ID to invalidate")
    inv_p.add_argument("--at", default=None, help="Invalidation date (default: today)")

    # Legacy positional support: handle top-level flags directly
    if argv and argv[0] in ("--add", "--query", "--list", "--export", "--invalidate"):
        argv = list(argv)
        argv[0] = argv[0].lstrip("-")

    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    # Pre-process: allow "--add", "--query", etc. as subcommands
    if argv is None:
        argv = sys.argv[1:]
    argv = list(argv)
    if argv and argv[0].startswith("--") and argv[0][2:] in (
        "add", "query", "list", "export", "invalidate"
    ):
        argv[0] = argv[0][2:]

    args = _parse_args(argv)
    db_path = Path(args.db_path)

    if args.command in ("add",):
        learned = args.learned or _today()
        result = add_entry(args.entry, args.occurred, learned, db_path)
        print(json.dumps(result, indent=2))

    elif args.command in ("query",):
        rows = query_at(args.at, db_path)
        print(json.dumps(rows, indent=2))
        if not args.quiet:
            print(f"entries_at_{args.at}: {len(rows)}", file=sys.stderr)

    elif args.command in ("list",):
        rows = list_all(db_path)
        print(json.dumps(rows, indent=2))

    elif args.command in ("export",):
        rows = export_json(db_path)
        print(json.dumps(rows, indent=2))

    elif args.command in ("invalidate",):
        at_date = getattr(args, "at", None)
        ok = invalidate(args.id, at_date, db_path)
        print(json.dumps({"id": args.id, "invalidated": ok}))

    else:
        print("ERROR: missing command. Use add/query/list/export/invalidate", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
