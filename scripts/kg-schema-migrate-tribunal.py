#!/usr/bin/env python3
"""kg-schema-migrate-tribunal.py — SPEC-199: Idempotent schema migration.

Creates (or updates) the tribunal_iterations table in
~/.savia/tribunal-iterations.db.

Safe to run multiple times: uses CREATE TABLE IF NOT EXISTS + CREATE INDEX IF NOT EXISTS.

CLI:
    python3 scripts/kg-schema-migrate-tribunal.py [--db PATH]
    -> {"migrated": true, "db": "...", "tables": ["tribunal_iterations"]}
"""
from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from pathlib import Path

DEFAULT_DB = Path(os.environ.get(
    "SAVIA_TRIBUNAL_HIST_DB",
    Path.home() / ".savia" / "tribunal-iterations.db"
))

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS tribunal_iterations (
    iteration_id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    iteration_n INTEGER NOT NULL,
    draft_hash TEXT NOT NULL,
    draft_text TEXT,
    verdict TEXT,
    score_avg REAL,
    embedding BLOB,
    final_verdict TEXT,
    evolution_summary TEXT,
    confidential INTEGER DEFAULT 0,
    ts TEXT DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_tribunal_draft_hash ON tribunal_iterations(draft_hash);
CREATE INDEX IF NOT EXISTS idx_tribunal_session ON tribunal_iterations(session_id);
"""


def migrate(db_path: Path) -> dict:
    """Apply schema migration. Idempotent."""
    db_path.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(str(db_path))
    try:
        con.executescript(SCHEMA_SQL)
        con.commit()
        # Verify
        cur = con.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='tribunal_iterations'"
        )
        tables = [row[0] for row in cur.fetchall()]
    finally:
        con.close()
    return {"migrated": True, "db": str(db_path), "tables": tables}


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Migrate KG schema for tribunal_iterations.")
    p.add_argument("--db", default=str(DEFAULT_DB), help="SQLite DB path")
    p.add_argument("--json", action="store_true", help="Output JSON result")
    args = p.parse_args(argv)

    result = migrate(Path(args.db))

    if args.json:
        print(json.dumps(result))
    else:
        print(f"migrated=True  db={result['db']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
