#!/usr/bin/env bash
# knowledge-graph.sh — Temporal knowledge graph in SQLite (local cache)
# SPEC-090: Build and query entity/relation graph from .md sources
#
# Usage:
#   knowledge-graph.sh build                  — Scan sources, populate SQLite
#   knowledge-graph.sh query "search text"    — Find entities by name
#   knowledge-graph.sh impact "entity"        — BFS cascade up to depth 3
#   knowledge-graph.sh status                 — Show counts and last build
#
# Sources: auto-memory .md files, memory-store.jsonl, decision-log.md
# DB path: ~/.savia/knowledge-graph.db
set -uo pipefail

# ── Paths ───────────────────────────────────────────────────────────────────
SAVIA_DIR="${SAVIA_DIR:-$HOME/.savia}"
DB_PATH="${KG_DB_PATH:-$SAVIA_DIR/knowledge-graph.db}"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ── Auto-memory paths ──────────────────────────────────────────────────────
AUTOMEMORY_DIR="${AUTOMEMORY_DIR:-$HOME/.claude/projects}"
MEMORY_STORE="${MEMORY_STORE:-$PROJECT_ROOT/output/.memory-store.jsonl}"
DECISION_LOG="${DECISION_LOG:-$PROJECT_ROOT/decision-log.md}"

# ── Helpers ─────────────────────────────────────────────────────────────────
iso8601_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

ensure_dir() {
  [[ -d "$SAVIA_DIR" ]] || mkdir -p "$SAVIA_DIR"
}

db_exists() {
  [[ -f "$DB_PATH" ]]
}

# ── Python wrapper for all SQLite operations ───────────────────────────────
sql_exec() {
  python3 -c "
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
conn.execute('PRAGMA journal_mode=WAL')
try:
    cur = conn.execute(sys.argv[2])
    rows = cur.fetchall()
    if rows:
        for r in rows:
            print('|'.join(str(c) if c is not None else '' for c in r))
    conn.commit()
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
finally:
    conn.close()
" "$DB_PATH" "$1"
}

sql_exec_script() {
  python3 -c "
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
conn.executescript(sys.argv[2])
conn.close()
" "$DB_PATH" "$1"
}

sql_query_formatted() {
  python3 -c "
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
cur = conn.execute(sys.argv[2])
cols = [d[0] for d in cur.description] if cur.description else []
rows = cur.fetchall()
if not rows:
    sys.exit(0)
widths = [max(len(str(c)), max((len(str(r[i])) if r[i] is not None else 0) for r in rows)) for i, c in enumerate(cols)]
header = '  '.join(c.ljust(w) for c, w in zip(cols, widths))
print(header)
print('  '.join('-' * w for w in widths))
for r in rows:
    print('  '.join((str(v) if v is not None else '').ljust(w) for v, w in zip(r, widths)))
conn.close()
" "$DB_PATH" "$1"
}

# ── Schema ──────────────────────────────────────────────────────────────────
init_schema() {
  ensure_dir
  sql_exec_script "
CREATE TABLE IF NOT EXISTS entities (
  id INTEGER PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  type TEXT NOT NULL,
  first_seen TEXT,
  last_seen TEXT
);
CREATE TABLE IF NOT EXISTS relations (
  id INTEGER PRIMARY KEY,
  entity_a INTEGER REFERENCES entities(id),
  relation TEXT NOT NULL,
  entity_b INTEGER REFERENCES entities(id),
  valid_from TEXT,
  valid_to TEXT,
  source TEXT,
  confidence REAL DEFAULT 1.0
);
CREATE TABLE IF NOT EXISTS metadata (
  key TEXT PRIMARY KEY,
  value TEXT
);
CREATE INDEX IF NOT EXISTS idx_entities_name ON entities(name);
CREATE INDEX IF NOT EXISTS idx_relations_a ON relations(entity_a);
CREATE INDEX IF NOT EXISTS idx_relations_b ON relations(entity_b);
"
}

# ── Entity and relation extraction via Python ──────────────────────────────
extract_and_insert() {
  local source_file="$1"
  local now="$2"
  python3 - "$DB_PATH" "$source_file" "$now" <<'PYEOF'
import sqlite3, sys, re, os

db_path, source_file, now = sys.argv[1], sys.argv[2], sys.argv[3]
source_label = os.path.basename(source_file)

try:
    with open(source_file, 'r', encoding='utf-8', errors='replace') as f:
        text = f.read()
except (FileNotFoundError, PermissionError):
    sys.exit(0)

if not text.strip():
    sys.exit(0)

conn = sqlite3.connect(db_path)
conn.execute("PRAGMA journal_mode=WAL")

def upsert_entity(name, etype):
    conn.execute(
        "INSERT INTO entities(name, type, first_seen, last_seen) "
        "VALUES(?, ?, ?, ?) ON CONFLICT(name) DO UPDATE SET last_seen=?",
        (name, etype, now, now, now)
    )

def get_entity_id(name):
    row = conn.execute("SELECT id FROM entities WHERE name=?", (name,)).fetchone()
    return row[0] if row else None

def insert_relation(id_a, rel, id_b):
    if id_a and id_b and id_a != id_b:
        existing = conn.execute(
            "SELECT 1 FROM relations WHERE entity_a=? AND relation=? AND entity_b=?",
            (id_a, rel, id_b)
        ).fetchone()
        if not existing:
            conn.execute(
                "INSERT INTO relations(entity_a, relation, entity_b, valid_from, source, confidence) "
                "VALUES(?, ?, ?, ?, ?, 1.0)",
                (id_a, rel, id_b, now, source_label)
            )

# Extract SPEC-NNN references
specs = sorted(set(re.findall(r'SPEC-\d+', text)))
for spec in specs:
    upsert_entity(spec, "concept")

# Extract tool/script names (*.sh, *.py)
tools = sorted(set(re.findall(r'[a-z][a-z0-9_-]+\.(?:sh|py)', text)))
for tool in tools:
    upsert_entity(tool, "tool")

# Extract project references
projects = sorted(set(re.findall(r'projects?/([a-z][a-z0-9_-]+)', text)))
for proj in projects:
    upsert_entity(proj, "project")

# Extract CamelCase proper nouns (likely class/component names)
camel = sorted(set(re.findall(r'\b[A-Z][a-z]{2,}[A-Z][a-zA-Z]*\b', text)))
for noun in camel:
    upsert_entity(noun, "concept")

# Extract relations: "X uses Y", "X depends on Y", etc.
rel_pattern = re.compile(
    r'([A-Za-z][A-Za-z0-9_.-]+)\s+'
    r'(uses|depends\s+on|decided|blocks|owns|requires|implements|extends)\s+'
    r'([A-Za-z][A-Za-z0-9_.-]+)',
    re.IGNORECASE
)
for m in rel_pattern.finditer(text):
    ent_a, rel, ent_b = m.group(1), m.group(2).replace(' ', '_'), m.group(3)
    upsert_entity(ent_a, "concept")
    upsert_entity(ent_b, "concept")
    id_a = get_entity_id(ent_a)
    id_b = get_entity_id(ent_b)
    insert_relation(id_a, rel, id_b)

# Cross-reference SPECs within same file
for i in range(len(specs)):
    for j in range(i + 1, len(specs)):
        id_a = get_entity_id(specs[i])
        id_b = get_entity_id(specs[j])
        insert_relation(id_a, "related_to", id_b)

conn.commit()
conn.close()
PYEOF
}

extract_from_text_inline() {
  local text="$1"
  local source_label="$2"
  local now="$3"
  # Write text to temp file, then process
  local tmpf
  tmpf=$(mktemp)
  echo "$text" > "$tmpf"
  python3 - "$DB_PATH" "$tmpf" "$now" "$source_label" <<'PYEOF'
import sqlite3, sys, re, os

db_path, source_file, now, source_label = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

try:
    with open(source_file, 'r', encoding='utf-8', errors='replace') as f:
        text = f.read()
except (FileNotFoundError, PermissionError):
    sys.exit(0)

if not text.strip():
    sys.exit(0)

conn = sqlite3.connect(db_path)
conn.execute("PRAGMA journal_mode=WAL")

def upsert_entity(name, etype):
    conn.execute(
        "INSERT INTO entities(name, type, first_seen, last_seen) "
        "VALUES(?, ?, ?, ?) ON CONFLICT(name) DO UPDATE SET last_seen=?",
        (name, etype, now, now, now)
    )

specs = sorted(set(re.findall(r'SPEC-\d+', text)))
for spec in specs:
    upsert_entity(spec, "concept")

tools = sorted(set(re.findall(r'[a-z][a-z0-9_-]+\.(?:sh|py)', text)))
for tool in tools:
    upsert_entity(tool, "tool")

conn.commit()
conn.close()
PYEOF
  rm -f "$tmpf"
}

# ── Build command ──────────────────────────────────────────────────────────
cmd_build() {
  init_schema
  local now
  now=$(iso8601_now)
  local source_count=0

  # Clear existing data for fresh build
  sql_exec "DELETE FROM relations;"
  sql_exec "DELETE FROM entities;"

  # 1. Scan auto-memory .md files
  if [[ -d "$AUTOMEMORY_DIR" ]]; then
    while IFS= read -r -d '' mdfile; do
      extract_and_insert "$mdfile" "$now"
      ((source_count++))
    done < <(find "$AUTOMEMORY_DIR" -name '*.md' -type f -print0 2>/dev/null)
  fi

  # 2. Scan memory-store.jsonl line by line
  if [[ -f "$MEMORY_STORE" ]]; then
    extract_and_insert "$MEMORY_STORE" "$now"
    ((source_count++))
  fi

  # 3. Scan decision-log.md
  if [[ -f "$DECISION_LOG" ]]; then
    extract_and_insert "$DECISION_LOG" "$now"
    ((source_count++))
  fi

  # Store build metadata
  sql_exec "INSERT OR REPLACE INTO metadata(key, value) VALUES('last_build', '$now');"
  sql_exec "INSERT OR REPLACE INTO metadata(key, value) VALUES('source_count', '$source_count');"

  local ent_count rel_count
  ent_count=$(sql_exec "SELECT COUNT(*) FROM entities;" | tr -d '[:space:]')
  rel_count=$(sql_exec "SELECT COUNT(*) FROM relations;" | tr -d '[:space:]')

  echo "Build complete: $ent_count entities, $rel_count relations from $source_count sources"
}

# ── Query command ──────────────────────────────────────────────────────────
cmd_query() {
  local search="${1:-}"
  if [[ -z "$search" ]]; then
    echo "Usage: knowledge-graph.sh query <text>" >&2
    return 1
  fi

  if ! db_exists; then
    echo "No knowledge graph found. Run: knowledge-graph.sh build" >&2
    return 1
  fi

  local entities
  entities=$(sql_query_formatted \
    "SELECT id, name, type, first_seen, last_seen FROM entities WHERE name LIKE '%${search}%' ORDER BY name;")

  if [[ -z "$entities" ]]; then
    echo "No entities matching '$search'"
    return 0
  fi

  echo "=== Entities matching '$search' ==="
  echo "$entities"
  echo ""

  local relations
  relations=$(sql_query_formatted \
    "SELECT e1.name AS from_entity, r.relation, e2.name AS to_entity, r.source
     FROM relations r
     JOIN entities e1 ON r.entity_a = e1.id
     JOIN entities e2 ON r.entity_b = e2.id
     WHERE e1.name LIKE '%${search}%' OR e2.name LIKE '%${search}%'
     ORDER BY e1.name;")

  if [[ -n "$relations" ]]; then
    echo "=== Relations ==="
    echo "$relations"
  fi
}

# ── Impact command (BFS via recursive CTE) ─────────────────────────────────
cmd_impact() {
  local entity="${1:-}"
  if [[ -z "$entity" ]]; then
    echo "Usage: knowledge-graph.sh impact <entity>" >&2
    return 1
  fi

  if ! db_exists; then
    echo "No knowledge graph found. Run: knowledge-graph.sh build" >&2
    return 1
  fi

  local start_id
  start_id=$(sql_exec "SELECT id FROM entities WHERE name='${entity}';" | tr -d '[:space:]')

  if [[ -z "$start_id" ]]; then
    echo "Entity '$entity' not found"
    return 0
  fi

  echo "=== Impact analysis for '$entity' (BFS depth 3) ==="

  sql_query_formatted "
WITH RECURSIVE impact(entity_id, depth, path) AS (
  SELECT $start_id, 0, '$entity'
  UNION
  SELECT CASE WHEN r.entity_a = i.entity_id THEN r.entity_b ELSE r.entity_a END,
         i.depth + 1,
         i.path || ' -> ' || CASE WHEN r.entity_a = i.entity_id
           THEN (SELECT name FROM entities WHERE id = r.entity_b)
           ELSE (SELECT name FROM entities WHERE id = r.entity_a) END
  FROM impact i
  JOIN relations r ON r.entity_a = i.entity_id OR r.entity_b = i.entity_id
  WHERE i.depth < 3
)
SELECT DISTINCT e.name, e.type, i.depth, i.path
FROM impact i
JOIN entities e ON e.id = i.entity_id
WHERE i.depth > 0
ORDER BY i.depth, e.name;
"
}

# ── Status command ─────────────────────────────────────────────────────────
cmd_status() {
  if ! db_exists; then
    echo "No knowledge graph found. Run: knowledge-graph.sh build"
    return 0
  fi

  local ent_count rel_count last_build source_count
  ent_count=$(sql_exec "SELECT COUNT(*) FROM entities;" | tr -d '[:space:]')
  rel_count=$(sql_exec "SELECT COUNT(*) FROM relations;" | tr -d '[:space:]')
  last_build=$(sql_exec "SELECT value FROM metadata WHERE key='last_build';" 2>/dev/null || echo "unknown")
  source_count=$(sql_exec "SELECT value FROM metadata WHERE key='source_count';" 2>/dev/null || echo "0")

  echo "=== Knowledge Graph Status ==="
  echo "Entities:    $ent_count"
  echo "Relations:   $rel_count"
  echo "Sources:     $source_count"
  echo "Last build:  $last_build"
  echo "DB path:     $DB_PATH"
}

# ── Dispatcher ─────────────────────────────────────────────────────────────
case "${1:-help}" in
  build)  cmd_build ;;
  query)  shift; cmd_query "$@" ;;
  impact) shift; cmd_impact "$@" ;;
  status) cmd_status ;;
  help|*)
    echo "knowledge-graph.sh — Temporal knowledge graph in SQLite"
    echo ""
    echo "Commands:"
    echo "  build              Scan sources and populate graph"
    echo "  query <text>       Search entities by name"
    echo "  impact <entity>    BFS cascade analysis (depth 3)"
    echo "  status             Show graph statistics"
    ;;
esac
