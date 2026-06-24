#!/usr/bin/env python3
"""
kg-schema-migrate-tribunal.py — SPEC-199 Phase 1: KG schema migration for tribunal iterations.

Adds the tribunal_iterations table to the Savia knowledge-graph SQLite DB.
Idempotent: safe to run multiple times.

Usage:
    python3 scripts/kg-schema-migrate-tribunal.py --db ~/.savia/tribunal-iterations.db
    python3 scripts/kg-schema-migrate-tribunal.py --self-test

Output (stdout, JSON):
    {"migrated": true, "schema_version": 1, "db": "..."}
    {"migrated": false, "reason": "already up to date", "schema_version": 1}

Ref: SPEC-199 docs/propuestas/SPEC-199-historical-context-tribunal-rounds.md
"""

import argparse
import json
import os
import sys
import sqlite3
from pathlib import Path

DEFAULT_DB = os.path.expanduser(
    os.environ.get("SAVIA_TRIBUNAL_HIST_DB", "~/.savia/tribunal-iterations.db")
)
SCHEMA_VERSION = 1

DDL = """
CREATE TABLE IF NOT EXISTS tribunal_iterations (
    iteration_id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    iteration_n INTEGER NOT NULL,
    draft_hash TEXT NOT NULL,
    draft_text TEXT,
    verdict TEXT,
    score_avg REAL,
    embedding BLOB,
    embedding_dim INTEGER DEFAULT 0,
    final_verdict TEXT,
    evolution_summary TEXT,
    confidential INTEGER DEFAULT 0,
    ts TEXT DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_tribunal_hash ON tribunal_iterations(draft_hash);
CREATE INDEX IF NOT EXISTS idx_tribunal_session ON tribunal_iterations(session_id);
CREATE TABLE IF NOT EXISTS _schema_version (
    key TEXT PRIMARY KEY,
    version INTEGER NOT NULL,
    applied_at TEXT DEFAULT CURRENT_TIMESTAMP
);
"""


def migrate(db_path: str) -> dict:
    Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    try:
        # Check current version
        conn.executescript(DDL)
        row = conn.execute(
            "SELECT version FROM _schema_version WHERE key='tribunal_iterations'"
        ).fetchone()
        if row and row[0] >= SCHEMA_VERSION:
            conn.close()
            return {"migrated": False, "reason": "already up to date",
                    "schema_version": row[0], "db": db_path}

        conn.execute(
            "INSERT OR REPLACE INTO _schema_version(key, version) VALUES (?, ?)",
            ("tribunal_iterations", SCHEMA_VERSION)
        )
        conn.commit()
        conn.close()
        return {"migrated": True, "schema_version": SCHEMA_VERSION, "db": db_path}
    except Exception as e:
        conn.close()
        return {"migrated": False, "error": str(e), "db": db_path}


def _self_test() -> int:
    import tempfile
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        tmp_db = f.name
    try:
        # First run: migrate
        r1 = migrate(tmp_db)
        assert r1["migrated"] is True, f"first migrate should apply: {r1}"
        assert r1["schema_version"] == SCHEMA_VERSION

        # Second run: idempotent
        r2 = migrate(tmp_db)
        assert r2["migrated"] is False, f"second migrate should be no-op: {r2}"

        # Table exists
        conn = sqlite3.connect(tmp_db)
        tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        assert "tribunal_iterations" in tables
        assert "_schema_version" in tables
        conn.close()

        print("self-test OK")
        return 0
    except AssertionError as e:
        print(f"self-test FAIL: {e}", file=sys.stderr)
        return 1
    finally:
        os.unlink(tmp_db)


def main():
    parser = argparse.ArgumentParser(description="KG schema migration — SPEC-199")
    parser.add_argument("--db", default=DEFAULT_DB, help="SQLite DB path")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        sys.exit(_self_test())

    result = migrate(args.db)
    print(json.dumps(result))
    sys.exit(0 if result.get("migrated") is not False or "error" not in result else 1)


if __name__ == "__main__":
    main()
