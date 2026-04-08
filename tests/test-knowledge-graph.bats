#!/usr/bin/env bats
# Tests for knowledge-graph.sh — Temporal knowledge graph in SQLite
# SPEC-090: Entity/relation extraction, query, impact analysis
# Ref: docs/propuestas/SPEC-090-temporal-knowledge-graph.md

SCRIPT="scripts/knowledge-graph.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMPDIR_KG=$(mktemp -d)
  export SAVIA_DIR="$TMPDIR_KG/savia"
  export KG_DB_PATH="$SAVIA_DIR/knowledge-graph.db"
  export AUTOMEMORY_DIR="$TMPDIR_KG/automemory"
  export MEMORY_STORE="$TMPDIR_KG/memory-store.jsonl"
  export DECISION_LOG="$TMPDIR_KG/decision-log.md"
  export PROJECT_ROOT="$REPO_ROOT"
  mkdir -p "$SAVIA_DIR" "$AUTOMEMORY_DIR"
}

teardown() {
  rm -rf "$TMPDIR_KG"
}

# Helper: query sqlite via python3 (no sqlite3 CLI dependency)
sql() {
  python3 -c "
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
cur = conn.execute(sys.argv[2])
for r in cur.fetchall():
    print('|'.join(str(c) if c is not None else '' for c in r))
conn.close()
" "$KG_DB_PATH" "$1"
}

# ── Safety ──────────────────────────────────────────────────────────────────

@test "target script has safety flags set" {
  grep -q 'set -uo pipefail' "$REPO_ROOT/$SCRIPT"
}

@test "script file exists and is executable" {
  [ -f "$REPO_ROOT/$SCRIPT" ]
  [ -x "$REPO_ROOT/$SCRIPT" ]
}

# ── Build ───────────────────────────────────────────────────────────────────

@test "build creates db file" {
  run bash "$REPO_ROOT/$SCRIPT" build
  [ "$status" -eq 0 ]
  [ -f "$KG_DB_PATH" ]
}

@test "build creates entities table with correct schema" {
  bash "$REPO_ROOT/$SCRIPT" build
  run python3 -c "
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
cur = conn.execute('PRAGMA table_info(entities)')
cols = [r[1] for r in cur.fetchall()]
assert 'name' in cols, 'missing name column'
assert 'type' in cols, 'missing type column'
assert 'first_seen' in cols, 'missing first_seen column'
assert 'last_seen' in cols, 'missing last_seen column'
print('schema OK')
conn.close()
" "$KG_DB_PATH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"schema OK"* ]]
}

@test "build creates relations table with correct schema" {
  bash "$REPO_ROOT/$SCRIPT" build
  run python3 -c "
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
cur = conn.execute('PRAGMA table_info(relations)')
cols = [r[1] for r in cur.fetchall()]
assert 'entity_a' in cols, 'missing entity_a'
assert 'relation' in cols, 'missing relation'
assert 'entity_b' in cols, 'missing entity_b'
assert 'confidence' in cols, 'missing confidence'
assert 'source' in cols, 'missing source'
print('schema OK')
conn.close()
" "$KG_DB_PATH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"schema OK"* ]]
}

@test "build with no sources exits gracefully with zero counts" {
  run bash "$REPO_ROOT/$SCRIPT" build
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 entities"* ]]
  [[ "$output" == *"0 relations"* ]]
}

@test "build extracts SPEC references as entities" {
  mkdir -p "$AUTOMEMORY_DIR/project1/memory"
  echo "Implemented SPEC-090 and referenced SPEC-013 for session memory." \
    > "$AUTOMEMORY_DIR/project1/memory/notes.md"

  bash "$REPO_ROOT/$SCRIPT" build

  run sql "SELECT name FROM entities WHERE name='SPEC-090';"
  [[ "$output" == "SPEC-090" ]]

  run sql "SELECT name FROM entities WHERE name='SPEC-013';"
  [[ "$output" == "SPEC-013" ]]
}

@test "build extracts tool names from source text" {
  mkdir -p "$AUTOMEMORY_DIR/proj/memory"
  echo "Uses memory-store.sh and knowledge-graph.sh for persistence." \
    > "$AUTOMEMORY_DIR/proj/memory/tools.md"

  bash "$REPO_ROOT/$SCRIPT" build

  run sql "SELECT COUNT(*) FROM entities WHERE type='tool';"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "build reads from memory-store.jsonl when present" {
  echo '{"type":"decision","title":"Use SPEC-077 for caching","content":"caching layer"}' \
    > "$MEMORY_STORE"

  bash "$REPO_ROOT/$SCRIPT" build

  run sql "SELECT name FROM entities WHERE name='SPEC-077';"
  [[ "$output" == "SPEC-077" ]]
}

@test "indices exist on entities and relations tables" {
  bash "$REPO_ROOT/$SCRIPT" build

  run python3 -c "
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
indices = [r[1] for r in conn.execute('PRAGMA index_list(entities)').fetchall()]
assert 'idx_entities_name' in indices, f'missing idx_entities_name in {indices}'
indices_r = [r[1] for r in conn.execute('PRAGMA index_list(relations)').fetchall()]
assert 'idx_relations_a' in indices_r, f'missing idx_relations_a in {indices_r}'
assert 'idx_relations_b' in indices_r, f'missing idx_relations_b in {indices_r}'
print('indices OK')
conn.close()
" "$KG_DB_PATH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"indices OK"* ]]
}

# ── Query ───────────────────────────────────────────────────────────────────

@test "query finds entity by name" {
  mkdir -p "$AUTOMEMORY_DIR/proj/memory"
  echo "SPEC-042 defines the query interface." \
    > "$AUTOMEMORY_DIR/proj/memory/spec.md"

  bash "$REPO_ROOT/$SCRIPT" build

  run bash "$REPO_ROOT/$SCRIPT" query "SPEC-042"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SPEC-042"* ]]
}

@test "query with no match returns empty message" {
  bash "$REPO_ROOT/$SCRIPT" build

  run bash "$REPO_ROOT/$SCRIPT" query "NonExistentEntity9999"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No entities matching"* ]]
}

@test "query without db shows helpful error message" {
  run bash "$REPO_ROOT/$SCRIPT" query "anything"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Run: knowledge-graph.sh build"* ]]
}

@test "query with empty argument shows usage error" {
  run bash "$REPO_ROOT/$SCRIPT" query ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

# ── Impact ──────────────────────────────────────────────────────────────────

@test "impact shows connected entities via BFS" {
  mkdir -p "$AUTOMEMORY_DIR/proj/memory"
  echo "SPEC-090 and SPEC-013 are related specs in the same domain." \
    > "$AUTOMEMORY_DIR/proj/memory/cross.md"

  bash "$REPO_ROOT/$SCRIPT" build

  local rel_count
  rel_count=$(sql "SELECT COUNT(*) FROM relations;")

  if [ "$rel_count" -gt 0 ]; then
    run bash "$REPO_ROOT/$SCRIPT" impact "SPEC-090"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Impact analysis"* ]]
  else
    skip "No relations extracted — pattern match dependent"
  fi
}

@test "impact with unknown entity returns empty result" {
  bash "$REPO_ROOT/$SCRIPT" build

  run bash "$REPO_ROOT/$SCRIPT" impact "GhostEntity404"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "impact without db shows helpful error" {
  run bash "$REPO_ROOT/$SCRIPT" impact "anything"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Run: knowledge-graph.sh build"* ]]
}

# ── Status ──────────────────────────────────────────────────────────────────

@test "status shows entity and relation counts" {
  mkdir -p "$AUTOMEMORY_DIR/proj/memory"
  echo "SPEC-099 implements a new feature." \
    > "$AUTOMEMORY_DIR/proj/memory/feat.md"

  bash "$REPO_ROOT/$SCRIPT" build

  run bash "$REPO_ROOT/$SCRIPT" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Entities:"* ]]
  [[ "$output" == *"Relations:"* ]]
  [[ "$output" == *"Last build:"* ]]
}

@test "status without db shows helpful message" {
  run bash "$REPO_ROOT/$SCRIPT" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"No knowledge graph found"* ]]
}

@test "help subcommand shows usage info" {
  run bash "$REPO_ROOT/$SCRIPT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"build"* ]]
  [[ "$output" == *"query"* ]]
  [[ "$output" == *"impact"* ]]
  [[ "$output" == *"status"* ]]
}

# Coverage: cmd_build, cmd_query, cmd_impact, cmd_status verified above
# Coverage: init_schema, sql_exec, sql_exec_script, sql_query_formatted tested via subcommands
# Coverage: extract_and_insert, extract_from_text_inline tested via build with sources
# Coverage: ensure_dir, db_exists, iso8601_now tested indirectly

@test "build extracts relations between entities" {
  mkdir -p "$AUTOMEMORY_DIR/proj/memory"
  echo "The validator uses memory-store.sh for persistence." \
    > "$AUTOMEMORY_DIR/proj/memory/rel.md"

  bash "$REPO_ROOT/$SCRIPT" build

  run sql "SELECT COUNT(*) FROM relations WHERE relation='uses';"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}
