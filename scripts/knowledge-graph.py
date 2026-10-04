#!/usr/bin/env python3
"""
knowledge-graph.py — SE-162 / SE-151 / SE-211 / SE-213: Knowledge Graph sobre memoria Savia.

Builds a typed-edge graph (entities + relations) in SQLite from plain-text
sources (.md, .jsonl). SQLite is a derived cache — plain text stays source of
truth.

Usage:
    python3 scripts/knowledge-graph.py build   [--db PATH] [--project SLUG] [--memory-type TYPE]
    python3 scripts/knowledge-graph.py query   "question" [--db PATH] [--limit N>=1] [--project SLUG]
    python3 scripts/knowledge-graph.py impact  "entity"   [--db PATH] [--depth N>=0] [--project SLUG]
    python3 scripts/knowledge-graph.py status             [--db PATH] [--project SLUG]
    python3 scripts/knowledge-graph.py entities [--type TYPE] [--memory-type TYPE] [--min-confidence FLOAT] [--json] [--db PATH] [--project SLUG]
    python3 scripts/knowledge-graph.py import-audience --tsv PATH [--db PATH] [--project SLUG] [--quiet]

Sources (relative to PROJECT_ROOT): output/.memory-store.jsonl, docs/ROADMAP.md,
docs/rules/domain/*.md, plus ~/.savia/memory-cache.db. It is a memory graph of
the Savia workspace, not a codebase analysis: it takes no source-path argument.
Search terms are literal substrings (% and _ are not wildcards).

Entity types : project, person, skill, decision, spec, concept, tool, rule
Relation types: uses, owns, blocks, depends_on, decided, implements, mentions

SE-151: --project SLUG tags all entities on build and filters on read.
SE-211: memory_type column — 13 semantic types (fact/decision/instruction/preference/goal/
        commitment/event/learning/error/observation/relationship/context/artifact).
SE-213: confidence REAL + provenance TEXT fields for quality-filtered queries.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
import time
from collections import deque
from pathlib import Path

# ── Paths ────────────────────────────────────────────────────────────────────

# ── SE-211: 13 semantic memory types (Memanto-inspired) ────────────────────────

MEMORY_TYPES = frozenset({
    "fact", "decision", "instruction", "preference", "goal",
    "commitment", "event", "learning", "error", "observation",
    "relationship", "context", "artifact",
})

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

# Concurrency: several processes may open (and create) the same DB at once.
# busy_timeout makes ordinary statements wait for the lock; switching to WAL
# needs an exclusive lock that SQLite may refuse immediately, so it is retried
# with a bounded backoff; migrations run inside BEGIN IMMEDIATE so only one
# process adds the missing columns.
_LOCK_TIMEOUT_S = 30.0
_WAL_RETRIES = 50


def _set_wal(conn: sqlite3.Connection) -> None:
    delay = 0.01
    for attempt in range(_WAL_RETRIES):
        try:
            conn.execute("PRAGMA journal_mode=WAL")
            return
        except sqlite3.OperationalError as exc:
            if "locked" not in str(exc) or attempt == _WAL_RETRIES - 1:
                raise
            time.sleep(delay)
            delay = min(delay * 2, 0.5)


_MIGRATIONS = (
    ("project_id", "ALTER TABLE entities ADD COLUMN project_id TEXT"),
    ("memory_type", "ALTER TABLE entities ADD COLUMN memory_type TEXT DEFAULT 'unknown'"),
    ("confidence", "ALTER TABLE entities ADD COLUMN confidence REAL DEFAULT 0.8"),
    ("provenance", "ALTER TABLE entities ADD COLUMN provenance TEXT DEFAULT 'unknown'"),
)


def open_db(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path), timeout=_LOCK_TIMEOUT_S)
    conn.execute(f"PRAGMA busy_timeout={int(_LOCK_TIMEOUT_S * 1000)}")
    _set_wal(conn)
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
    # SE-151 / SE-211 / SE-213: idempotent column migrations, serialized
    # across processes by the write lock of BEGIN IMMEDIATE and re-checked
    # inside it, so two openers never add the same column twice.
    cols = {row[1] for row in conn.execute("PRAGMA table_info(entities)")}
    if any(col not in cols for col, _ in _MIGRATIONS):
        conn.execute("BEGIN IMMEDIATE")
        try:
            cols = {row[1] for row in conn.execute("PRAGMA table_info(entities)")}
            for col, ddl in _MIGRATIONS:
                if col not in cols:
                    conn.execute(ddl)
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_ent_project ON entities(project_id)"
            )
            conn.commit()
        except Exception:
            conn.rollback()
            raise
    return conn


def upsert_entity(
    conn: sqlite3.Connection,
    name: str,
    etype: str,
    project_id: str | None = None,
    memory_type: str | None = None,
    confidence: float = 0.8,
    provenance: str = "unknown",
) -> int:
    """SE-151/SE-211/SE-213: upsert entity with memory_type, confidence, provenance.

    Entities are globally de-duped by (name, type). project_id is a tag:
    each entity can be tagged to at most one project (last write wins within
    a build cycle). cmd_build with --project X deletes all X-tagged entities
    before ingesting, so isolation is maintained per project.

    SE-211: memory_type must be one of MEMORY_TYPES; falls back to 'unknown' with
    a WARN to stderr when an unrecognised type is supplied.
    SE-213: confidence (0.0-1.0, default 0.8) and provenance track data quality.
    """
    name = name.strip()[:200]

    # SE-211: validate memory_type
    resolved_mtype: str = "unknown"
    if memory_type is not None and memory_type != "unknown":
        if memory_type in MEMORY_TYPES:
            resolved_mtype = memory_type
        else:
            print(
                f"[WARN] SE-211: unknown memory_type '{memory_type}' — storing as 'unknown'",
                file=sys.stderr,
            )

    conn.execute(
        "INSERT OR IGNORE INTO entities(name, type, project_id, memory_type, confidence, provenance)"
        " VALUES(?,?,?,?,?,?)",
        (name, etype, project_id, resolved_mtype, confidence, provenance),
    )
    # An upsert that carries no quality information (unknown memory_type and
    # provenance) must not erase what an earlier, explicit source recorded:
    # it only refreshes last_seen and the project tag.
    if resolved_mtype == "unknown" and provenance == "unknown":
        conn.execute(
            "UPDATE entities SET last_seen=datetime('now'),"
            " project_id=COALESCE(?, project_id) WHERE name=? AND type=?",
            (project_id, name, etype),
        )
    # Update last_seen; if project_id provided, retag (within this build project_id is consistent)
    elif project_id is not None:
        conn.execute(
            "UPDATE entities SET last_seen=datetime('now'), project_id=?,"
            " memory_type=?, confidence=?, provenance=?"
            " WHERE name=? AND type=?",
            (project_id, resolved_mtype, confidence, provenance, name, etype),
        )
    else:
        conn.execute(
            "UPDATE entities SET last_seen=datetime('now'),"
            " memory_type=?, confidence=?, provenance=?"
            " WHERE name=? AND type=?",
            (resolved_mtype, confidence, provenance, name, etype),
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
            except json.JSONDecodeError as exc:
                print(f"[WARN] memory-store: skipping invalid JSON line ({exc.msg})",
                      file=sys.stderr)
                continue
            if not isinstance(entry, dict):
                print("[WARN] memory-store: skipping non-object line", file=sys.stderr)
                continue
            topic = entry.get("topic", entry.get("title", ""))
            if not isinstance(topic, str) or not topic.strip():
                print("[WARN] memory-store: skipping entry without a text topic",
                      file=sys.stderr)
                continue
            content = entry.get("content", "")
            if not isinstance(content, str):
                content = json.dumps(content, ensure_ascii=False)
            raw_type = entry.get("type", "concept")
            # SE-211: map the raw store type to memory_type BEFORE coercing the
            # entity type, otherwise bug/pattern/architecture/... never map.
            _mtype_map = {
                "decision": "decision", "discovery": "observation",
                "bug": "error", "architecture": "artifact",
                "pattern": "learning", "session-summary": "context",
                "feedback": "observation", "episode": "event",
            }
            m_type = _mtype_map.get(raw_type, "unknown") if isinstance(raw_type, str) else "unknown"
            etype = raw_type
            if etype not in ("decision", "discovery", "feedback", "concept",
                             "spec", "rule", "tool", "project"):
                etype = "concept"
            topic_id = upsert_entity(
                conn, topic, etype, project_id,
                memory_type=m_type,
                confidence=0.8,
                provenance="explicit_statement",
            )
            entities = extract_entities_from_text(f"{topic} {content}")
            for name, t in entities:
                if name == topic:
                    continue
                eid = upsert_entity(conn, name, t, project_id,
                                    memory_type="unknown",
                                    confidence=0.7,
                                    provenance="inferred")
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

def _like_escape(term: str) -> str:
    """Escape LIKE metacharacters so search terms match literally."""
    return term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def _int_at_least(minimum: int):
    def parse(value: str) -> int:
        try:
            n = int(value)
        except ValueError:
            raise argparse.ArgumentTypeError(f"invalid integer: {value!r}")
        if n < minimum:
            raise argparse.ArgumentTypeError(f"must be >= {minimum}, got {n}")
        return n
    return parse





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

    # SE-211: --memory-type overrides memory_type for everything ingested.
    override = getattr(args, "memory_type", None)
    if override:
        if project_id:
            conn.execute("UPDATE entities SET memory_type=? WHERE project_id=?",
                         (override, project_id))
        else:
            conn.execute("UPDATE entities SET memory_type=?", (override,))
        conn.commit()

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
    rel_where = ("WHERE entity_a IN (SELECT id FROM entities WHERE project_id=?)"
                 " OR entity_b IN (SELECT id FROM entities WHERE project_id=?)"
                 if project_id else "")
    rel_params = (project_id, project_id) if project_id else ()
    for row in conn.execute(
        f"SELECT relation, COUNT(*) FROM relations {rel_where} GROUP BY relation ORDER BY 2 DESC",
        rel_params
    ):
        print(f"    {row[0]:15s} {row[1]}")


def cmd_entities(args: argparse.Namespace) -> None:
    """SE-211/SE-213: list entities with optional memory_type and min-confidence filters."""
    db = Path(args.db)
    if not db.exists():
        print("Graph not built — run: python3 scripts/knowledge-graph.py build")
        sys.exit(1)
    project_id: str | None = getattr(args, "project", None) or None
    conn = open_db(db)
    conditions: list[str] = []
    params_list: list = []
    if args.type:
        conditions.append("type=?")
        params_list.append(args.type)
    if project_id:
        conditions.append("project_id=?")
        params_list.append(project_id)
    # SE-211: filter by memory_type
    mtype_filter: str | None = getattr(args, "memory_type", None)
    if mtype_filter:
        conditions.append("memory_type=?")
        params_list.append(mtype_filter)
    # SE-213: filter by minimum confidence
    min_conf: float | None = getattr(args, "min_confidence", None)
    if min_conf is not None:
        conditions.append("confidence>=?")
        params_list.append(min_conf)
    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
    rows = conn.execute(
        f"SELECT name, type, project_id, memory_type, confidence, provenance"
        f" FROM entities {where} ORDER BY type, name",
        tuple(params_list),
    ).fetchall()
    use_json = getattr(args, "json_output", False)
    if use_json:
        result = []
        for name, etype, proj, mtype, conf, prov in rows:
            result.append({
                "name": name, "type": etype, "project_id": proj,
                "memory_type": mtype, "confidence": conf, "provenance": prov,
            })
        print(json.dumps(result, indent=2))
    else:
        for name, etype, proj, mtype, conf, prov in rows:
            proj_label = f"  [{proj}]" if proj else ""
            mtype_label = f"  mt:{mtype}" if mtype and mtype != "unknown" else ""
            print(f"{etype:12s}  {name}{proj_label}{mtype_label}  conf:{conf:.2f}")


def cmd_query(args: argparse.Namespace) -> None:
    db = Path(args.db)
    if not db.exists():
        print("Graph not built — run: python3 scripts/knowledge-graph.py build")
        sys.exit(1)
    project_id: str | None = getattr(args, "project", None) or None
    conn = open_db(db)
    q = f"%{_like_escape(args.question)}%"
    proj_filter = "AND e.project_id=?" if project_id else ""
    proj_params = (project_id,) if project_id else ()
    rows = conn.execute(
        f"""SELECT e.name, e.type,
                  r.relation,
                  e2.name as target
           FROM entities e
           JOIN relations r ON (r.entity_a=e.id OR r.entity_b=e.id)
           JOIN entities e2 ON (CASE WHEN r.entity_a=e.id THEN r.entity_b ELSE r.entity_a END = e2.id)
           WHERE (e.name LIKE ? ESCAPE '\\' OR e.type LIKE ? ESCAPE '\\') {proj_filter}
           ORDER BY e.name
           LIMIT ?""",
        (q, q) + proj_params + (args.limit,)
    ).fetchall()
    if not rows:
        # fallback: plain entity search
        fallback_where = "WHERE name LIKE ? ESCAPE '\\'" + (" AND project_id=?" if project_id else "")
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
    project_id: str | None = getattr(args, "project", None) or None
    proj_filter = " AND project_id=?" if project_id else ""
    proj_params = (project_id,) if project_id else ()
    row = conn.execute(
        "SELECT id, type FROM entities WHERE name LIKE ? ESCAPE '\\'"
        + proj_filter + " LIMIT 1",
        (f"%{_like_escape(entity)}%",) + proj_params
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
            if project_id and conn.execute(
                "SELECT project_id FROM entities WHERE id=?", (eid,)
            ).fetchone()[0] != project_id:
                continue
            indent = "  " * (depth + 1)
            print(f"{indent}--{relation}-->  [{etype}] {ename}")
            if eid not in visited:
                visited.add(eid)
                queue.append((eid, depth + 1, indent))


# ── CLI ──────────────────────────────────────────────────────────────────────

def cmd_import_audience(args: argparse.Namespace) -> None:
    """SE-221: import audience-cross.tsv as typed relations
    (path_a) -[shared_audience]-> (path_b) with shared_count en source.
    """
    import csv
    tsv_path = args.tsv
    if not os.path.isfile(tsv_path):
        print(f"ERROR: tsv not found: {tsv_path}", file=sys.stderr)
        sys.exit(1)
    conn = open_db(Path(args.db))
    n_rels = 0
    with open(tsv_path, "r", encoding="utf-8") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        for row in reader:
            path_a = row.get("path_a", "").strip()
            path_b = row.get("path_b", "").strip()
            shared = row.get("shared_agents", "").strip()
            count_raw = row.get("audience_count", "0").strip()
            try:
                count = int(count_raw)
            except ValueError:
                count = 0
            if not path_a or not path_b or count < 1:
                continue
            a_id = upsert_entity(conn, path_a, "context-doc",
                                 project_id=args.project,
                                 memory_type="fact",
                                 confidence=1.0,
                                 provenance="se-221-audience-graph")
            b_id = upsert_entity(conn, path_b, "context-doc",
                                 project_id=args.project,
                                 memory_type="fact",
                                 confidence=1.0,
                                 provenance="se-221-audience-graph")
            source = f"shared_audience={shared};count={count}"
            upsert_relation(conn, a_id, "shared_audience", b_id,
                            source=source, confidence=1.0)
            n_rels += 1
    conn.commit()
    if not getattr(args, "quiet", False):
        print(f"imported {n_rels} shared_audience relations from {tsv_path}")
    conn.close()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="SE-162: Knowledge Graph sobre memoria Savia"
    )
    sub = parser.add_subparsers(dest="command")

    p_build = sub.add_parser("build", help="Build/rebuild graph from sources")
    p_build.add_argument("--db", default=str(DEFAULT_DB))
    p_build.add_argument("--project", default=None, help="SE-151: tag entities with project slug")
    p_build.add_argument("--memory-type", dest="memory_type", default=None,
                         choices=sorted(MEMORY_TYPES),
                         help="SE-211: override default memory_type for all ingested entities")

    p_status = sub.add_parser("status", help="Show graph statistics")
    p_status.add_argument("--db", default=str(DEFAULT_DB))
    p_status.add_argument("--project", default=None, help="SE-151: filter by project slug")

    p_ent = sub.add_parser("entities", help="List entities")
    p_ent.add_argument("--type", help="Filter by entity type")
    p_ent.add_argument("--memory-type", dest="memory_type", default=None,
                       help="SE-211: filter by memory_type (decision/fact/…)")
    p_ent.add_argument("--min-confidence", dest="min_confidence", type=float, default=None,
                       help="SE-213: filter entities by minimum confidence (0.0-1.0)")
    p_ent.add_argument("--json", dest="json_output", action="store_true",
                       help="Output as JSON (includes memory_type, confidence, provenance)")
    p_ent.add_argument("--db", default=str(DEFAULT_DB))
    p_ent.add_argument("--project", default=None, help="SE-151: filter by project slug")

    p_q = sub.add_parser("query", help="Query graph")
    p_q.add_argument("question", help="Search term")
    p_q.add_argument("--limit", type=_int_at_least(1), default=20)
    p_q.add_argument("--db", default=str(DEFAULT_DB))
    p_q.add_argument("--project", default=None, help="SE-151: filter by project slug")

    p_imp = sub.add_parser("impact", help="Show impact cascade")
    p_imp.add_argument("entity", help="Entity name (partial match)")
    p_imp.add_argument("--depth", type=_int_at_least(0), default=3)
    p_imp.add_argument("--db", default=str(DEFAULT_DB))
    p_imp.add_argument("--project", default=None, help="SE-151: filter by project slug")

    p_imp_aud = sub.add_parser("import-audience",
                                help="SE-221: import context-audience-cross.tsv as shared_audience relations")
    p_imp_aud.add_argument("--tsv", required=True,
                            help="Path to context-audience-cross.tsv (output of context-audience-graph.py)")
    p_imp_aud.add_argument("--db", default=str(DEFAULT_DB))
    p_imp_aud.add_argument("--project", default=None,
                            help="SE-151: tag entities with project slug")
    p_imp_aud.add_argument("--quiet", action="store_true")

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
        "import-audience": cmd_import_audience,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
