#!/usr/bin/env python3
"""kg-schema-migrate.py — SPEC-193 Componente 10.

Adds source, trust_level, created_by_session columns to the knowledge graph
entities table. Idempotent: can be run multiple times without duplicating
columns or breaking existing data.

Usage:
    python3 scripts/kg-schema-migrate.py [--db PATH]

Default DB path: .savia-kg/knowledge_graph.db (or SAVIA_KG_DB env var).
"""
from __future__ import annotations

import argparse
import os
import sqlite3
import sys
from pathlib import Path

# ── Defaults ─────────────────────────────────────────────────────────────────

SCRIPT_DIR    = Path(__file__).resolve().parent
WORKSPACE     = Path(os.environ.get("CLAUDE_PROJECT_DIR", SCRIPT_DIR.parent))
DEFAULT_DB    = Path(os.environ.get(
    "SAVIA_KG_DB",
    str(WORKSPACE / ".savia-kg" / "knowledge_graph.db")
))

# ── Migration definition ──────────────────────────────────────────────────────

MIGRATIONS = [
    # (column_name, col_type, default_value, description)
    ("source",             "TEXT",    "'unknown'", "Data source: system|user|tool|external|llm-generated"),
    ("trust_level",        "INTEGER", "50",        "Trust score 0-100; system=100, external=40, llm=30"),
    ("created_by_session", "TEXT",    "NULL",      "Session ID that created this entity"),
]

INDEXES = [
    ("idx_entities_trust",   "entities", "trust_level"),
    ("idx_entities_source",  "entities", "source"),
]


def _column_exists(cursor: sqlite3.Cursor, table: str, column: str) -> bool:
    cursor.execute(f"PRAGMA table_info({table})")
    cols = [row[1] for row in cursor.fetchall()]
    return column in cols


def _table_exists(cursor: sqlite3.Cursor, table: str) -> bool:
    cursor.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        (table,)
    )
    return cursor.fetchone() is not None


def _index_exists(cursor: sqlite3.Cursor, index_name: str) -> bool:
    cursor.execute(
        "SELECT name FROM sqlite_master WHERE type='index' AND name=?",
        (index_name,)
    )
    return cursor.fetchone() is not None


def migrate(db_path: Path, dry_run: bool = False) -> dict:
    """Run migration. Return result dict with applied/skipped lists."""
    applied: list[str] = []
    skipped: list[str] = []
    errors:  list[str] = []

    if not db_path.exists():
        # Create the DB and a minimal entities table if not present
        db_path.parent.mkdir(parents=True, exist_ok=True)
        if not dry_run:
            conn = sqlite3.connect(db_path)
            conn.execute(
                "CREATE TABLE IF NOT EXISTS entities "
                "(id INTEGER PRIMARY KEY, name TEXT, type TEXT)"
            )
            conn.commit()
            conn.close()

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    try:
        # Ensure entities table exists
        if not _table_exists(cursor, "entities"):
            if not dry_run:
                conn.execute(
                    "CREATE TABLE IF NOT EXISTS entities "
                    "(id INTEGER PRIMARY KEY, name TEXT, type TEXT)"
                )
                conn.commit()
            applied.append("CREATE TABLE entities (minimal schema)")

        # Apply column migrations (idempotent)
        for col_name, col_type, default, desc in MIGRATIONS:
            if _column_exists(cursor, "entities", col_name):
                skipped.append(f"column entities.{col_name} (already exists)")
                continue
            sql = f"ALTER TABLE entities ADD COLUMN {col_name} {col_type} DEFAULT {default}"
            if not dry_run:
                conn.execute(sql)
                conn.commit()
            applied.append(f"ALTER TABLE entities ADD COLUMN {col_name} ({desc})")

        # Create indexes (idempotent)
        for idx_name, table, column in INDEXES:
            if _index_exists(cursor, idx_name):
                skipped.append(f"index {idx_name} (already exists)")
                continue
            sql = f"CREATE INDEX IF NOT EXISTS {idx_name} ON {table}({column})"
            if not dry_run:
                conn.execute(sql)
                conn.commit()
            applied.append(f"CREATE INDEX {idx_name} ON {table}({column})")

    except sqlite3.Error as e:
        errors.append(str(e))
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
    """Verify expected columns/indexes are present."""
    if not db_path.exists():
        return {"valid": False, "missing": ["database file not found"]}

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    missing: list[str] = []

    for col_name, _, _, _ in MIGRATIONS:
        if not _column_exists(cursor, "entities", col_name):
            missing.append(f"column entities.{col_name}")

    for idx_name, _, _ in INDEXES:
        if not _index_exists(cursor, idx_name):
            missing.append(f"index {idx_name}")

    conn.close()
    return {"valid": len(missing) == 0, "missing": missing}


def main() -> None:
    parser = argparse.ArgumentParser(
        description="SPEC-193 KG schema migration — idempotent"
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
        import json
        print(json.dumps(result, indent=2))
        sys.exit(0 if result["valid"] else 1)

    result = migrate(db, dry_run=args.dry_run)

    import json
    print(json.dumps(result, indent=2))

    if not result["success"]:
        sys.exit(1)

    prefix = "[DRY RUN] " if args.dry_run else ""
    print(
        f"\n{prefix}Migration complete: "
        f"{len(result['applied'])} applied, "
        f"{len(result['skipped'])} skipped, "
        f"{len(result['errors'])} errors."
    )


if __name__ == "__main__":
    main()
