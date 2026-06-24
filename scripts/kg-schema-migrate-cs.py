#!/usr/bin/env python3
"""kg-schema-migrate-cs.py — SPEC-194 Criterion Simulation Layer.

Adds the frame_reaffirmations table to the knowledge graph SQLite DB.
Idempotent: can be run multiple times without duplicating the table.

Uses Python stdlib sqlite3 only. No external dependencies.

Default DB path: .savia-kg/graph.db (or SAVIA_KG_DB env var).

Usage:
    python3 scripts/kg-schema-migrate-cs.py
    python3 scripts/kg-schema-migrate-cs.py --db /path/to/graph.db
    python3 scripts/kg-schema-migrate-cs.py --verify
    python3 scripts/kg-schema-migrate-cs.py --dry-run
"""
from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from pathlib import Path

# ── Defaults ──────────────────────────────────────────────────────────────────
SCRIPT_DIR = Path(__file__).resolve().parent
WORKSPACE  = Path(os.environ.get("CLAUDE_PROJECT_DIR", SCRIPT_DIR.parent))
DEFAULT_DB = Path(os.environ.get(
    "SAVIA_KG_DB",
    str(WORKSPACE / ".savia-kg" / "graph.db")
))

# ── Schema definition ─────────────────────────────────────────────────────────
CREATE_FRAME_REAFFIRMATIONS = """
CREATE TABLE IF NOT EXISTS frame_reaffirmations (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id      TEXT    NOT NULL,
    ts           TEXT    NOT NULL,
    operator     TEXT    NOT NULL DEFAULT 'default',
    reason       TEXT,
    verdict_before TEXT,
    tags         TEXT,
    extra_json   TEXT
)
"""

CREATE_INDEX_TASK_ID = (
    "idx_frame_reaffirmations_task",
    "CREATE INDEX IF NOT EXISTS idx_frame_reaffirmations_task "
    "ON frame_reaffirmations(task_id)"
)

CREATE_INDEX_TS = (
    "idx_frame_reaffirmations_ts",
    "CREATE INDEX IF NOT EXISTS idx_frame_reaffirmations_ts "
    "ON frame_reaffirmations(ts)"
)

INDEXES = [CREATE_INDEX_TASK_ID, CREATE_INDEX_TS]


def _table_exists(cursor: sqlite3.Cursor, table: str) -> bool:
    cursor.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?", (table,)
    )
    return cursor.fetchone() is not None


def _index_exists(cursor: sqlite3.Cursor, index_name: str) -> bool:
    cursor.execute(
        "SELECT name FROM sqlite_master WHERE type='index' AND name=?", (index_name,)
    )
    return cursor.fetchone() is not None


def migrate(db_path: Path, dry_run: bool = False) -> dict:
    """Run CS schema migration. Returns result dict with applied/skipped lists."""
    applied: list[str] = []
    skipped: list[str] = []
    errors:  list[str] = []

    # Ensure DB directory and file exist
    if not db_path.exists():
        db_path.parent.mkdir(parents=True, exist_ok=True)
        if not dry_run:
            conn = sqlite3.connect(str(db_path))
            conn.close()

    conn   = sqlite3.connect(str(db_path))
    cursor = conn.cursor()

    try:
        # frame_reaffirmations table
        if _table_exists(cursor, "frame_reaffirmations"):
            skipped.append("table frame_reaffirmations (already exists)")
        else:
            if not dry_run:
                conn.execute(CREATE_FRAME_REAFFIRMATIONS)
                conn.commit()
            applied.append("CREATE TABLE frame_reaffirmations")

        # Indexes
        for idx_name, idx_sql in INDEXES:
            if _index_exists(cursor, idx_name):
                skipped.append(f"index {idx_name} (already exists)")
            else:
                if not dry_run:
                    conn.execute(idx_sql)
                    conn.commit()
                applied.append(f"CREATE INDEX {idx_name}")

    except sqlite3.Error as exc:
        errors.append(str(exc))
        conn.rollback()
    finally:
        conn.close()

    return {
        "db_path": str(db_path),
        "applied": applied,
        "skipped": skipped,
        "errors":  errors,
        "success": len(errors) == 0,
    }


def verify(db_path: Path) -> dict:
    """Verify expected table and indexes are present."""
    if not db_path.exists():
        return {"valid": False, "missing": ["database file not found"]}

    conn    = sqlite3.connect(str(db_path))
    cursor  = conn.cursor()
    missing = []

    if not _table_exists(cursor, "frame_reaffirmations"):
        missing.append("table frame_reaffirmations")

    for idx_name, _ in INDEXES:
        if not _index_exists(cursor, idx_name):
            missing.append(f"index {idx_name}")

    conn.close()
    return {"valid": len(missing) == 0, "missing": missing}


def main() -> None:
    parser = argparse.ArgumentParser(
        description="SPEC-194 KG CS schema migration — idempotent"
    )
    parser.add_argument(
        "--db", default=str(DEFAULT_DB),
        help=f"Path to SQLite database (default: {DEFAULT_DB})"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show what would be done without applying changes"
    )
    parser.add_argument(
        "--verify", action="store_true",
        help="Verify schema is up to date (exit 1 if missing)"
    )
    args = parser.parse_args()

    db = Path(args.db)

    if args.verify:
        result = verify(db)
        print(json.dumps(result, indent=2))
        sys.exit(0 if result["valid"] else 1)

    result = migrate(db, dry_run=args.dry_run)

    print(json.dumps(result, indent=2))

    if not result["success"]:
        sys.exit(1)

    prefix = "[DRY RUN] " if args.dry_run else ""
    print(
        f"\n{prefix}CS migration complete: "
        f"{len(result['applied'])} applied, "
        f"{len(result['skipped'])} skipped, "
        f"{len(result['errors'])} errors."
    )


if __name__ == "__main__":
    main()
