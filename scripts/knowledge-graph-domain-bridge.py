#!/usr/bin/env python3
"""
knowledge-graph-domain-bridge.py — SE-086 Slice 2 addition.

Ingests CONTEXT.md files from projects/ into the SE-162 knowledge graph,
adding DOMAIN_TERM edges between domain term entities and their project.

Usage:
    python3 scripts/knowledge-graph-domain-bridge.py [--db PATH] [--root PATH]

Designed to be run after `knowledge-graph.py build`. Adds edges without
resetting the graph.
"""

from __future__ import annotations

import argparse
import os
import re
import sqlite3
from pathlib import Path

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent))
DEFAULT_DB = Path(os.environ.get("KG_DB", Path.home() / ".savia" / "knowledge-graph.db"))


def open_db(db_path: Path) -> sqlite3.Connection:
    if not db_path.exists():
        print(f"ERROR: knowledge graph DB not found: {db_path}")
        print("Run: bash scripts/knowledge-graph.sh build")
        raise SystemExit(1)
    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def upsert_entity(conn: sqlite3.Connection, name: str, etype: str) -> int:
    conn.execute(
        "INSERT OR IGNORE INTO entities(name, type) VALUES(?,?)", (name, etype)
    )
    conn.execute(
        "UPDATE entities SET last_seen=datetime('now') WHERE name=? AND type=?",
        (name, etype),
    )
    return conn.execute(
        "SELECT id FROM entities WHERE name=? AND type=?", (name, etype)
    ).fetchone()[0]


def upsert_relation(
    conn: sqlite3.Connection, a: int, relation: str, b: int, source: str
) -> None:
    conn.execute(
        """INSERT OR IGNORE INTO relations(entity_a, relation, entity_b, source, confidence)
           VALUES(?,?,?,?,?)""",
        (a, relation, b, source, 0.9),
    )


def parse_context_md(path: Path) -> list[tuple[str, str]]:
    """Parse CONTEXT.md glossary table → [(term, definition)]."""
    terms: list[tuple[str, str]] = []
    in_table = False
    for line in path.read_text(errors="ignore").splitlines():
        if re.match(r'\|\s*Term\s*\|', line, re.I):
            in_table = True
            continue
        if in_table and line.startswith("|---"):
            continue
        if in_table and line.startswith("|"):
            parts = [p.strip() for p in line.strip("|").split("|")]
            if len(parts) >= 2:
                term = parts[0].strip()
                defn = parts[1].strip() if len(parts) > 1 else ""
                if term and not term.startswith("---"):
                    terms.append((term, defn))
        elif in_table and not line.startswith("|"):
            in_table = False
    return terms


def ingest_context_files(conn: sqlite3.Connection, root: Path) -> int:
    """Scan projects/*/CONTEXT.md and add DOMAIN_TERM edges."""
    count = 0
    for context_md in root.glob("projects/*/CONTEXT.md"):
        project_name = context_md.parent.name
        proj_id = upsert_entity(conn, project_name, "project")
        terms = parse_context_md(context_md)
        for term, _defn in terms:
            term_id = upsert_entity(conn, term, "concept")
            upsert_relation(conn, proj_id, "DOMAIN_TERM", term_id,
                            source=str(context_md.relative_to(root)))
            count += 1
    conn.commit()
    return count


def main() -> None:
    parser = argparse.ArgumentParser(
        description="SE-086: Ingest CONTEXT.md domain terms into knowledge graph"
    )
    parser.add_argument("--db", default=str(DEFAULT_DB))
    parser.add_argument("--root", default=str(ROOT))
    args = parser.parse_args()

    conn = open_db(Path(args.db))
    root = Path(args.root)
    added = ingest_context_files(conn, root)
    total_r = conn.execute("SELECT COUNT(*) FROM relations WHERE relation='DOMAIN_TERM'").fetchone()[0]
    print(f"DOMAIN_TERM edges added: {added}  (total in graph: {total_r})")


if __name__ == "__main__":
    main()
