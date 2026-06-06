#!/usr/bin/env python3
"""
knowledge-graph.py — SE-162 / SE-151: Knowledge Graph sobre memoria Savia.

Builds a typed-edge graph (entities + relations) in SQLite from plain-text
sources (.md, .jsonl). SQLite is a derived cache — plain text stays source of
truth.

Usage:
    python3 scripts/knowledge-graph.py build   [--db PATH] [--root PATH] [--project SLUG]
    python3 scripts/knowledge-graph.py query   "question" [--db PATH] [--limit N] [--project SLUG]
    python3 scripts/knowledge-graph.py impact  "entity"   [--db PATH] [--depth N] [--project SLUG]
    python3 scripts/knowledge-graph.py status             [--db PATH] [--project SLUG]
    python3 scripts/knowledge-graph.py entities [--type TYPE] [--db PATH] [--project SLUG]

Entity types : project, person, skill, decision, spec, concept, tool, rule
Relation types: uses, owns, blocks, depends_on, decided, implements, mentions

SE-151: --project SLUG tags all entities on build and filters on read.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
from collections import deque
from pathlib import Path

# ── Paths ────────────────────────────────────────────────────────────────────

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent))
DEFAULT_DB = Path(os.environ.get("KG_DB", Path.home() / ".savia" / "knowledge-graph.db"))
MEMORY_STORE = ROOT / "output" / ".memory-store.jsonl"
MEMORY_CACHE_DB = Path.home() / ".savia" / "memory-cache.db"
EXTERNAL_MEMORY = ROOT / ".claude" / "external-memory" / "auto"

# ── Schema ───────────────────────────────────────────────────────────────────

SCHEMA = """
CREATE TABLE IF NOT EXISTS entities (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT    NOT NULL,
    type       TEXT    NOT NULL,
    project_id TEXT,
    first_seen TEXT    DEFAULT (datetime('now')),
    last_seen  TEXT    DEFAULT (datetime('now')),
    UNIQUE(name, type, project_id)
);

CREATE TABLE IF NOT EXISTS relations (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_a   INTEGER NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    relation   TEXT    NOT NULL,
    entity_b   INTEGER NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    valid_from TEXT    DEFAULT (datetime('now')),
    valid_to   TEXT    DEFAULT NULL,
    source     TEXT,
    confidence REAL    DEFAULT 1.0,
    UNIQUE(entity_a, relation, entity_b)
);

CREATE INDEX IF NOT EXISTS idx_rel_a   ON relations(entity_a);
CREATE INDEX IF NOT EXISTS idx_rel_b   ON relations(entity_b);
CREATE INDEX IF NOT EXISTS idx_ent_name ON entities(name);
CREATE INDEX IF NOT EXISTS idx_ent_type ON entities(type);
CREATE INDEX IF NOT EXISTS idx_ent_project ON entities(project_id);
"""

# ── Extraction patterns ───────────────────────────────────────────────────────

# Spec IDs: SE-NNN, SPEC-NNN, SPEC-NNN-SLUG
RE_SPEC   = re.compile(r'\b((?:SE|SPEC)-\d{3}(?:-[A-Z0-9_-]+)?)\b', re.I)
# Person names in memory: "Monica", "monica", user slugs
RE_PERSON = re.compile(r'\bMonica\b|\bmonica\b')
# Project names
RE_PROJECT = re.compile(r'\b(pm-workspace|trazabios|savia(?:-web|-mobile|-hub)?|homelab|dotnet-microservices-home-lab)\b', re.I)
# Tools / platforms
RE_TOOL   = re.compile(r'\b(Azure\s*DevOps|GitHub|OpenCode|Claude\s*Code|SaviaClaw|LocalAI|DeepSeek|Jira|SQLite|Terraform|Docker)\b', re.I)
# Skills (present in .claude/skills/)
_SKILLS_DIR = ROOT / ".claude" / "skills"
_SKILL_NAMES: list[str] = []
if _SKILLS_DIR.exists():
    _SKILL_NAMES = [d.name for d in _SKILLS_DIR.iterdir()
                    if d.is_dir() and d.name != "_template"]

# ── DB helpers ───────────────────────────────────────────────────────────────

def open_db(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    # Create tables using schema without project_id unique constraint first (compat)
    _SCHEMA_COMPAT = """
CREATE TABLE IF NOT EXISTS entities (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT    NOT NULL,
    type       TEXT    NOT NULL,
    first_seen TEXT    DEFAULT (datetime('now')),
    last_seen  TEXT    DEFAULT (datetime('now')),
    UNIQUE(name, type)
);
CREATE TABLE IF NOT EXISTS relations (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_a   INTEGER NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    relation   TEXT    NOT NULL,
    entity_b   INTEGER NOT NULL REFERENCES entities(id) ON DELETE CASCADE,
    valid_from TEXT    DEFAULT (datetime('now')),
    valid_to   TEXT    DEFAULT NULL,
    source     TEXT,
    confidence REAL    DEFAULT 1.0,
    UNIQUE(entity_a, relation, entity_b)
);
CREATE INDEX IF NOT EXISTS idx_rel_a    ON relations(entity_a);
CREATE INDEX IF NOT EXISTS idx_rel_b    ON relations(entity_b);
CREATE INDEX IF NOT EXISTS idx_ent_name ON entities(name);
CREATE INDEX IF NOT EXISTS idx_ent_type ON entities(type);
"""
    conn.executescript(_SCHEMA_COMPAT)
    # SE-151: add project_id column if missing (idempotent migration)
    cols = {row[1] for row in conn.execute("PRAGMA table_info(entities)")}
    if "project_id" not in cols:
        conn.execute("ALTER TABLE entities ADD COLUMN project_id TEXT")
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_ent_project ON entities(project_id)"
        )
    conn.commit()
    return conn


def upsert_entity(conn: sqlite3.Connection, name: str, etype: str,
                   project_id: str | None = None) -> int:
    """SE-151: upsert entity.
    Entities are globally de-duped by (name, type). project_id is a tag:
    each entity can be tagged to at most one project (last write wins within
    a build cycle). cmd_build with --project X deletes all X-tagged entities
    before ingesting, so isolation is maintained per project.
    """
    name = name.strip()[:200]
    conn.execute(
        "INSERT OR IGNORE INTO entities(name, type, project_id) VALUES(?,?,?)",
        (name, etype, project_id)
    )
    # Update last_seen; if project_id provided, retag (within this build project_id is consistent)
    if project_id is not None:
        conn.execute(
            "UPDATE entities SET last_seen=datetime('now'), project_id=? WHERE name=? AND type=?",
            (project_id, name, etype),
        )
    else:
        conn.execute(
            "UPDATE entities SET last_seen=datetime('now') WHERE name=? AND type=?",
            (name, etype),
        )
    row = conn.execute(
        "SELECT id FROM entities WHERE name=? AND type=?", (name, etype)
    ).fetchone()
    return row[0]


def upsert_relation(
    conn: sqlite3.Connection,
    a: int, relation: str, b: int,
    source: str = "", confidence: float = 1.0,
) -> None:
    conn.execute(
        """INSERT OR IGNORE INTO relations(entity_a, relation, entity_b, source, confidence)
           VALUES(?,?,?,?,?)""",
        (a, relation, b, source, confidence),
    )


# ── Entity extraction from text ──────────────────────────────────────────────

def extract_entities_from_text(text: str) -> list[tuple[str, str]]:
    """Return (name, type) pairs found in text."""
    found: list[tuple[str, str]] = []
    for m in RE_SPEC.findall(text):
        etype = "spec" if m.upper().startswith("SPEC-") else "spec"
        found.append((m.upper(), etype))
    if RE_PERSON.search(text):
        found.append(("Monica", "person"))
    for m in RE_PROJECT.findall(text):
        found.append((m.lower(), "project"))
    for m in RE_TOOL.findall(text):
        found.append((re.sub(r'\s+', '-', m.lower()), "tool"))
    for skill in _SKILL_NAMES:
        if re.search(r'\b' + re.escape(skill) + r'\b', text, re.I):
            found.append((skill, "skill"))
    return found


# ── Sources ──────────────────────────────────────────────────────────────────

def ingest_memory_store(conn: sqlite3.Connection, project_id: str | None = None) -> int:
    """Ingest output/.memory-store.jsonl."""
    if not MEMORY_STORE.exists():
        return 0
    count = 0
    with MEMORY_STORE.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            topic = entry.get("topic", entry.get("title", ""))
            content = entry.get("content", "")
            etype = entry.get("type", "concept")
            if etype not in ("decision", "discovery", "feedback", "concept",
                             "spec", "rule", "tool", "project"):
                etype = "concept"
            topic_id = upsert_entity(conn, topic, etype, project_id)
            entities = extract_entities_from_text(f"{topic} {content}")
            for name, t in entities:
                if name == topic:
                    continue
                eid = upsert_entity(conn, name, t, project_id)
                upsert_relation(conn, topic_id, "mentions", eid,
                                source=str(MEMORY_STORE), confidence=0.8)
            count += 1
    conn.commit()
    return count


def ingest_memory_cache_db(conn: sqlite3.Connection, project_id: str | None = None) -> int:
    """Ingest ~/.savia/memory-cache.db entries."""
    if not MEMORY_CACHE_DB.exists():
        return 0
    try:
        src = sqlite3.connect(str(MEMORY_CACHE_DB))
    except Exception:
        return 0
    count = 0
    try:
        rows = src.execute(
            "SELECT topic_key, type, content FROM memory_entries"
        ).fetchall()
    except Exception:
        src.close()
        return 0
    for topic_key, etype, content in rows:
        if etype not in ("decision", "discovery", "feedback", "concept",
                         "spec", "rule", "tool", "project", "index", "unknown"):
            etype = "concept"
        if etype == "index":
            etype = "concept"
        topic_id = upsert_entity(conn, topic_key, etype, project_id)
        entities = extract_entities_from_text(str(content))
        for name, t in entities:
            if name == topic_key:
                continue
            eid = upsert_entity(conn, name, t, project_id)
            upsert_relation(conn, topic_id, "mentions", eid,
                            source="memory-cache.db", confidence=0.7)
        count += 1
    conn.commit()
    src.close()
    return count


def ingest_roadmap(conn: sqlite3.Connection, project_id: str | None = None) -> int:
    """Extract spec→spec depends_on relations from ROADMAP.md."""
    roadmap = ROOT / "docs" / "ROADMAP.md"
    if not roadmap.exists():
        return 0
    text = roadmap.read_text(errors="ignore")
    specs = RE_SPEC.findall(text)
    count = 0
    # Wire project node
    proj_id = upsert_entity(conn, "pm-workspace", "project", project_id)
    for spec_name in set(specs):
        spec_id = upsert_entity(conn, spec_name.upper(), "spec", project_id)
        upsert_relation(conn, proj_id, "implements", spec_id,
                        source="docs/ROADMAP.md", confidence=0.9)
        count += 1
    # depends_on: look for "Requiere SE-NNN" / "Post SE-NNN" / "depende de SE-NNN"
    for m in re.finditer(
        r'(?:Requiere|Post|depende\s+de)\s+((?:SE|SPEC)-\d{3}(?:-[A-Z0-9_-]+)?)',
        text, re.I
    ):
        dep = m.group(1).upper()
        # find spec that mentions this dep within same line
        line_start = text.rfind('\n', 0, m.start()) + 1
        line_end   = text.find('\n', m.end())
        line = text[line_start:line_end]
        all_in_line = RE_SPEC.findall(line)
        for candidate in all_in_line:
            if candidate.upper() != dep:
                a = upsert_entity(conn, candidate.upper(), "spec", project_id)
                b = upsert_entity(conn, dep, "spec", project_id)
                upsert_relation(conn, a, "depends_on", b,
                                source="docs/ROADMAP.md", confidence=0.85)
    conn.commit()
    return count


def ingest_rules(conn: sqlite3.Connection, project_id: str | None = None) -> int:
    """Extract rule nodes from docs/rules/domain/*.md."""
    rules_dir = ROOT / "docs" / "rules" / "domain"
    if not rules_dir.exists():
        return 0
    count = 0
    proj_id = upsert_entity(conn, "pm-workspace", "project", project_id)
    for md in rules_dir.glob("*.md"):
        rule_id = upsert_entity(conn, md.stem, "rule", project_id)
        upsert_relation(conn, proj_id, "uses", rule_id,
                        source=str(md.relative_to(ROOT)), confidence=1.0)
        text = md.read_text(errors="ignore")[:3000]  # cap for perf
        for spec_name in RE_SPEC.findall(text):
            spec_id = upsert_entity(conn, spec_name.upper(), "spec", project_id)
            upsert_relation(conn, rule_id, "implements", spec_id,
                            source=str(md.relative_to(ROOT)), confidence=0.8)
        # mentions: tools / concepts cited in the rule text
        for name, etype in extract_entities_from_text(text):
            if etype in ("tool", "concept") and name != md.stem:
                eid = upsert_entity(conn, name, etype, project_id)
                upsert_relation(conn, rule_id, "mentions", eid,
                                source=str(md.relative_to(ROOT)), confidence=0.7)
        count += 1
    conn.commit()
    return count


# ── Commands ─────────────────────────────────────────────────────────────────




def cmd_build(args: argparse.Namespace) -> None:
    db = Path(args.db)
    project_id: str | None = getattr(args, "project", None) or None
    conn = open_db(db)

    # Reset: if project_id given, only delete entities for that project
    if project_id:
        # Delete relations touching entities from this project first
        conn.execute(
            """DELETE FROM relations WHERE entity_a IN (
                SELECT id FROM entities WHERE project_id=?
            ) OR entity_b IN (
                SELECT id FROM entities WHERE project_id=?
            )""",
            (project_id, project_id),
        )
        conn.execute("DELETE FROM entities WHERE project_id=?", (project_id,))
    else:
        conn.execute("DELETE FROM relations")
        conn.execute("DELETE FROM entities")
    conn.commit()

    n_store = ingest_memory_store(conn, project_id)
    n_cache = ingest_memory_cache_db(conn, project_id)
    n_road  = ingest_roadmap(conn, project_id)
    n_rules = ingest_rules(conn, project_id)

    total_e = conn.execute("SELECT COUNT(*) FROM entities").fetchone()[0]
    total_r = conn.execute("SELECT COUNT(*) FROM relations").fetchone()[0]

    proj_label = f" [project={project_id}]" if project_id else ""
    print(f"BUILD complete{proj_label} — {db}")
    print(f"  Sources: memory-store({n_store}), memory-cache({n_cache}), "
          f"roadmap({n_road}), rules({n_rules})")
    print(f"  Entities: {total_e}  Relations: {total_r}")


def cmd_status(args: argparse.Namespace) -> None:
    db = Path(args.db)
    if not db.exists():
        print("Graph not built — run: python3 scripts/knowledge-graph.py build")
        return
    project_id: str | None = getattr(args, "project", None) or None
    conn = open_db(db)
    if project_id:
        total_e = conn.execute(
            "SELECT COUNT(*) FROM entities WHERE project_id=?", (project_id,)
        ).fetchone()[0]
        total_r = conn.execute(
            """SELECT COUNT(*) FROM relations WHERE entity_a IN (
                SELECT id FROM entities WHERE project_id=?
            ) OR entity_b IN (
                SELECT id FROM entities WHERE project_id=?
            )""",
            (project_id, project_id),
        ).fetchone()[0]
    else:
        total_e = conn.execute("SELECT COUNT(*) FROM entities").fetchone()[0]
        total_r = conn.execute("SELECT COUNT(*) FROM relations").fetchone()[0]
    proj_label = f" [project={project_id}]" if project_id else ""
    print(f"Knowledge Graph{proj_label} — {db}")
    print(f"  Entities : {total_e}")
    print(f"  Relations: {total_r}")
    print()
    print("  Entities by type:")
    where = "WHERE project_id=?" if project_id else ""
    params = (project_id,) if project_id else ()
    for row in conn.execute(
        f"SELECT type, COUNT(*) FROM entities {where} GROUP BY type ORDER BY 2 DESC",
        params
    ):
        print(f"    {row[0]:15s} {row[1]}")
    print()
    print("  Relations by type:")
    for row in conn.execute(
        "SELECT relation, COUNT(*) FROM relations GROUP BY relation ORDER BY 2 DESC"
    ):
        print(f"    {row[0]:15s} {row[1]}")


def cmd_entities(args: argparse.Namespace) -> None:
    db = Path(args.db)
    if not db.exists():
        print("Graph not built — run: python3 scripts/knowledge-graph.py build")
        sys.exit(1)
    project_id: str | None = getattr(args, "project", None) or None
    conn = open_db(db)
    conditions = []
    params_list: list = []
    if args.type:
        conditions.append("type=?")
        params_list.append(args.type)
    if project_id:
        conditions.append("project_id=?")
        params_list.append(project_id)
    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
    rows = conn.execute(
        f"SELECT name, type, project_id FROM entities {where} ORDER BY type, name",
        tuple(params_list)
    ).fetchall()
    for name, etype, proj in rows:
        proj_label = f"  [{proj}]" if proj else ""
        print(f"{etype:12s}  {name}{proj_label}")


def cmd_query(args: argparse.Namespace) -> None:
    db = Path(args.db)
    if not db.exists():
        print("Graph not built — run: python3 scripts/knowledge-graph.py build")
        sys.exit(1)
    project_id: str | None = getattr(args, "project", None) or None
    conn = open_db(db)
    q = f"%{args.question}%"
    proj_filter = "AND e.project_id=?" if project_id else ""
    proj_params = (project_id,) if project_id else ()
    rows = conn.execute(
        f"""SELECT e.name, e.type,
                  r.relation,
                  e2.name as target
           FROM entities e
           JOIN relations r ON (r.entity_a=e.id OR r.entity_b=e.id)
           JOIN entities e2 ON (CASE WHEN r.entity_a=e.id THEN r.entity_b ELSE r.entity_a END = e2.id)
           WHERE (e.name LIKE ? OR e.type LIKE ?) {proj_filter}
           ORDER BY e.name
           LIMIT ?""",
        (q, q) + proj_params + (args.limit,)
    ).fetchall()
    if not rows:
        # fallback: plain entity search
        fallback_where = "WHERE name LIKE ?" + (" AND project_id=?" if project_id else "")
        fallback_params = (q,) + proj_params + (args.limit,)
        rows2 = conn.execute(
            f"SELECT name, type FROM entities {fallback_where} LIMIT ?",
            fallback_params
        ).fetchall()
        if rows2:
            print(f"Entities matching '{args.question}':")
            for name, etype in rows2:
                print(f"  [{etype}] {name}")
        else:
            print(f"No results for '{args.question}'")
        return
    print(f"Results for '{args.question}':")
    for name, etype, relation, target in rows:
        print(f"  [{etype}] {name}  --{relation}-->  {target}")


def cmd_impact(args: argparse.Namespace) -> None:
    db = Path(args.db)
    if not db.exists():
        print("Graph not built — run: python3 scripts/knowledge-graph.py build")
        sys.exit(1)
    conn = open_db(db)
    entity = args.entity
    row = conn.execute(
        "SELECT id, type FROM entities WHERE name LIKE ? LIMIT 1",
        (f"%{entity}%",)
    ).fetchone()
    if not row:
        print(f"Entity '{entity}' not found")
        sys.exit(1)
    root_id, root_type = row
    root_name = conn.execute(
        "SELECT name FROM entities WHERE id=?", (root_id,)
    ).fetchone()[0]

    # BFS
    visited: set[int] = {root_id}
    queue: deque[tuple[int, int, str]] = deque([(root_id, 0, "")])
    print(f"Impact of [{root_type}] {root_name} (depth={args.depth}):")
    while queue:
        node_id, depth, prefix = queue.popleft()
        if depth >= args.depth:
            continue
        rels = conn.execute(
            """SELECT r.relation, e.id, e.name, e.type
               FROM relations r JOIN entities e ON r.entity_b=e.id
               WHERE r.entity_a=?
               UNION
               SELECT r.relation, e.id, e.name, e.type
               FROM relations r JOIN entities e ON r.entity_a=e.id
               WHERE r.entity_b=? AND r.relation IN ('blocks','depends_on')""",
            (node_id, node_id)
        ).fetchall()
        for relation, eid, ename, etype in rels:
            indent = "  " * (depth + 1)
            print(f"{indent}--{relation}-->  [{etype}] {ename}")
            if eid not in visited:
                visited.add(eid)
                queue.append((eid, depth + 1, indent))


# ── CLI ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="SE-162: Knowledge Graph sobre memoria Savia"
    )
    sub = parser.add_subparsers(dest="command")

    p_build = sub.add_parser("build", help="Build/rebuild graph from sources")
    p_build.add_argument("--db", default=str(DEFAULT_DB))
    p_build.add_argument("--project", default=None, help="SE-151: tag entities with project slug")

    p_status = sub.add_parser("status", help="Show graph statistics")
    p_status.add_argument("--db", default=str(DEFAULT_DB))
    p_status.add_argument("--project", default=None, help="SE-151: filter by project slug")

    p_ent = sub.add_parser("entities", help="List entities")
    p_ent.add_argument("--type", help="Filter by type")
    p_ent.add_argument("--db", default=str(DEFAULT_DB))
    p_ent.add_argument("--project", default=None, help="SE-151: filter by project slug")

    p_q = sub.add_parser("query", help="Query graph")
    p_q.add_argument("question", help="Search term")
    p_q.add_argument("--limit", type=int, default=20)
    p_q.add_argument("--db", default=str(DEFAULT_DB))
    p_q.add_argument("--project", default=None, help="SE-151: filter by project slug")

    p_imp = sub.add_parser("impact", help="Show impact cascade")
    p_imp.add_argument("entity", help="Entity name (partial match)")
    p_imp.add_argument("--depth", type=int, default=3)
    p_imp.add_argument("--db", default=str(DEFAULT_DB))
    p_imp.add_argument("--project", default=None, help="SE-151: filter by project slug")

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(0)

    dispatch = {
        "build": cmd_build,
        "status": cmd_status,
        "entities": cmd_entities,
        "query": cmd_query,
        "impact": cmd_impact,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
