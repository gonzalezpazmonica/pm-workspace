#!/usr/bin/env python3
"""
scripts/knowledge-graph-temporal.py -- SPEC-123: Graphiti Temporal Pattern

Extends the Savia knowledge-graph with valid_at / expired_at temporal fields.

API:
    python3 scripts/knowledge-graph-temporal.py add-temporal \
        --entity NAME --valid-at ISO-DATE [--expired-at ISO-DATE] [--type TYPE]

    python3 scripts/knowledge-graph-temporal.py invalidate \
        --entity NAME [--expired-at ISO-DATE]

    python3 scripts/knowledge-graph-temporal.py query-at \
        --when ISO-DATE [--entity NAME] [--relation REL]

    python3 scripts/knowledge-graph-temporal.py backfill [--db PATH]
"""
from __future__ import annotations
import argparse, json, os, re, sqlite3, sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent))
DEFAULT_DB = Path(os.environ.get("KG_DB", Path.home() / ".savia" / "knowledge-graph.db"))

_ISO_RE = re.compile(r"^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2})?Z?)?$")

def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def _validate_iso(val: str, name: str) -> None:
    if not _ISO_RE.match(val):
        print(f"ERROR: {name} '{val}' is not valid ISO-8601", file=sys.stderr)
        sys.exit(1)

def open_db(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    # Ensure base tables exist (compatible with knowledge-graph.py schema)
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS entities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'concept',
            project_id TEXT,
            first_seen TEXT DEFAULT (datetime('now')),
            last_seen TEXT DEFAULT (datetime('now')),
            UNIQUE(name, type)
        );
        CREATE INDEX IF NOT EXISTS idx_ent_name ON entities(name);
        CREATE TABLE IF NOT EXISTS relations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_a INTEGER NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
            relation TEXT NOT NULL,
            entity_b INTEGER NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
            valid_from TEXT DEFAULT (datetime('now')),
            valid_to TEXT DEFAULT NULL,
            source TEXT,
            confidence REAL DEFAULT 1.0,
            UNIQUE(entity_a, relation, entity_b)
        );
    """)
    # SPEC-123: add temporal columns (idempotent)
    cols = {row[1] for row in conn.execute("PRAGMA table_info(entities)")}
    if "valid_at" not in cols:
        conn.execute("ALTER TABLE entities ADD COLUMN valid_at TEXT DEFAULT NULL")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_ent_valid_at ON entities(valid_at)")
    if "expired_at" not in cols:
        conn.execute("ALTER TABLE entities ADD COLUMN expired_at TEXT DEFAULT NULL")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_ent_expired_at ON entities(expired_at)")
    conn.commit()
    return conn

def upsert_entity(conn: sqlite3.Connection, name: str, etype: str = "concept",
                  project_id: str | None = None) -> int:
    conn.execute(
        "INSERT OR IGNORE INTO entities(name, type, project_id) VALUES(?,?,?)",
        (name, etype, project_id)
    )
    row = conn.execute("SELECT id FROM entities WHERE name=? AND type=?", (name, etype)).fetchone()
    return row[0]

# --- Commands ---

def cmd_add_temporal(args: argparse.Namespace) -> None:
    conn = open_db(Path(args.db))
    valid_at = args.valid_at or _now_iso()
    expired_at = getattr(args, "expired_at", None)
    _validate_iso(valid_at, "--valid-at")
    if expired_at:
        _validate_iso(expired_at, "--expired-at")
        if expired_at < valid_at:
            print(f"ERROR: expired_at '{expired_at}' must be after valid_at '{valid_at}'", file=sys.stderr)
            sys.exit(1)
    etype = getattr(args, "entity_type", None) or "concept"
    eid = upsert_entity(conn, args.entity, etype, getattr(args, "project", None))
    conn.execute("UPDATE entities SET valid_at=?, expired_at=? WHERE id=?",
                 (valid_at, expired_at, eid))
    conn.commit()
    print(json.dumps({"entity": args.entity, "valid_at": valid_at,
                      "expired_at": expired_at, "action": "add_temporal"}, indent=2))

def cmd_invalidate(args: argparse.Namespace) -> None:
    conn = open_db(Path(args.db))
    expired_at = getattr(args, "expired_at", None) or _now_iso()
    if expired_at:
        _validate_iso(expired_at, "--expired-at")
    rows = conn.execute("SELECT id, name FROM entities WHERE name LIKE ?",
                        (f"%{args.entity}%",)).fetchall()
    if not rows:
        print(f"Entity '{args.entity}' not found", file=sys.stderr)
        sys.exit(1)
    for eid, ename in rows:
        # Validate: don't invalidate before valid_at
        va_row = conn.execute("SELECT valid_at FROM entities WHERE id=?", (eid,)).fetchone()
        valid_at = va_row[0] if va_row else None
        if valid_at and expired_at < valid_at:
            print(f"WARN: expired_at '{expired_at}' is before valid_at '{valid_at}' for '{ename}'", file=sys.stderr)
        conn.execute("UPDATE entities SET expired_at=? WHERE id=?", (expired_at, eid))
    conn.commit()
    print(json.dumps({"entity": args.entity, "expired_at": expired_at,
                      "records_updated": len(rows), "action": "invalidate"}, indent=2))

def cmd_query_at(args: argparse.Namespace) -> None:
    conn = open_db(Path(args.db))
    when = args.when
    _validate_iso(when, "--when")
    entity_filter = getattr(args, "entity", None)
    relation_filter = getattr(args, "relation", None)

    where_parts: list[str] = [
        "(e.valid_at IS NULL OR e.valid_at <= :when)",
        "(e.expired_at IS NULL OR e.expired_at > :when)",
    ]
    params: dict[str, Any] = {"when": when}

    if entity_filter:
        where_parts.append("e.name LIKE :entity")
        params["entity"] = f"%{entity_filter}%"

    where_clause = " AND ".join(where_parts)

    if relation_filter:
        params["rel"] = f"%{relation_filter}%"
        rows = conn.execute(
            f"""SELECT e.name, e.type, r.relation, e2.name as target,
                       e.valid_at, e.expired_at
                FROM entities e
                JOIN relations r ON (r.entity_a=e.id OR r.entity_b=e.id)
                JOIN entities e2 ON (
                    CASE WHEN r.entity_a=e.id THEN r.entity_b ELSE r.entity_a END = e2.id
                )
                WHERE {where_clause} AND r.relation LIKE :rel
                ORDER BY e.name""",
            params,
        ).fetchall()
        result = [
            {"entity": n, "type": t, "relation": rel, "target": tgt,
             "valid_at": va, "expired_at": ea}
            for n, t, rel, tgt, va, ea in rows
        ]
    else:
        rows = conn.execute(
            f"""SELECT name, type, valid_at, expired_at
                FROM entities e WHERE {where_clause} ORDER BY name""",
            params,
        ).fetchall()
        result = [
            {"entity": n, "type": t, "valid_at": va, "expired_at": ea}
            for n, t, va, ea in rows
        ]
    print(json.dumps({"when": when, "results": result, "count": len(result)}, indent=2))

def cmd_backfill(args: argparse.Namespace) -> None:
    """SPEC-123 AC-03: Set valid_at=first_seen for entities with null valid_at."""
    conn = open_db(Path(args.db))
    rows = conn.execute(
        "SELECT id, first_seen FROM entities WHERE valid_at IS NULL"
    ).fetchall()
    updated = 0
    for eid, first_seen in rows:
        if first_seen:
            conn.execute("UPDATE entities SET valid_at=? WHERE id=?", (first_seen, eid))
            updated += 1
    conn.commit()
    if updated > 0:
        print(f"[SPEC-123] Backfilled {updated} edges with timestamps", file=sys.stderr)
    print(json.dumps({"action": "backfill", "records_updated": updated}))

# --- CLI ---

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="knowledge-graph-temporal.py",
                                description="SPEC-123: Temporal pattern for Savia knowledge graph")
    p.add_argument("--db", default=str(DEFAULT_DB), metavar="PATH")
    sub = p.add_subparsers(dest="command")

    p_add = sub.add_parser("add-temporal", help="Add/update temporal metadata for an entity")
    p_add.add_argument("--entity", required=True, metavar="NAME")
    p_add.add_argument("--valid-at", dest="valid_at", default=None, metavar="ISO-DATE",
                       help="ISO-8601 start date (default: now)")
    p_add.add_argument("--expired-at", dest="expired_at", default=None, metavar="ISO-DATE")
    p_add.add_argument("--type", dest="entity_type", default="concept", metavar="TYPE")
    p_add.add_argument("--project", default=None)

    p_inv = sub.add_parser("invalidate", help="Mark entity as expired at a given date")
    p_inv.add_argument("--entity", required=True, metavar="NAME")
    p_inv.add_argument("--expired-at", dest="expired_at", default=None, metavar="ISO-DATE",
                       help="ISO-8601 expiry date (default: now)")

    p_q = sub.add_parser("query-at", help="Query entities valid at a specific point in time")
    p_q.add_argument("--when", required=True, metavar="ISO-DATE")
    p_q.add_argument("--entity", default=None, metavar="NAME")
    p_q.add_argument("--relation", default=None, metavar="REL")

    p_bf = sub.add_parser("backfill", help="Backfill valid_at from first_seen for legacy entities")

    return p

def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if not args.command:
        parser.print_help()
        return 0
    dispatch = {
        "add-temporal": cmd_add_temporal,
        "invalidate": cmd_invalidate,
        "query-at": cmd_query_at,
        "backfill": cmd_backfill,
    }
    dispatch[args.command](args)
    return 0

if __name__ == "__main__":
    sys.exit(main())
