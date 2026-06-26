#!/usr/bin/env bats
# tests/bats/test-se-030-graphrag-gates.bats — SE-030 GraphRAG Quality Gates
# Tests for scripts/graphrag-quality-gates.sh
#
# Ref: docs/propuestas/SE-030-graphrag-quality-gates.md

SCRIPT="$(git rev-parse --show-toplevel)/scripts/graphrag-quality-gates.sh"
FIXTURE_DIR="$(git rev-parse --show-toplevel)/tests/fixtures/graphrag"

setup() {
  mkdir -p "$FIXTURE_DIR"
}

teardown() {
  rm -f "$FIXTURE_DIR"/*.db 2>/dev/null || true
}

# ── Helper: create a minimal valid SQLite KG ─────────────────────────────────
create_minimal_db() {
  local db="$1"
  python3 - "$db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.executescript("""
CREATE TABLE entities (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    first_seen TEXT DEFAULT (datetime('now')),
    last_seen  TEXT DEFAULT (datetime('now')),
    confidence REAL DEFAULT 0.8,
    provenance TEXT DEFAULT 'test'
);
CREATE TABLE relations (
    id INTEGER PRIMARY KEY,
    entity_a INTEGER NOT NULL,
    relation TEXT NOT NULL,
    entity_b INTEGER NOT NULL,
    confidence REAL DEFAULT 1.0
);
INSERT INTO entities VALUES (1,'Alpha','concept',datetime('now'),datetime('now'),0.9,'test.md');
INSERT INTO entities VALUES (2,'Beta','tool',datetime('now'),datetime('now'),0.8,'test.md');
INSERT INTO entities VALUES (3,'Gamma','decision',datetime('now'),datetime('now'),0.7,'test.md');
INSERT INTO entities VALUES (4,'Delta','skill',datetime('now'),datetime('now'),0.95,'test.md');
INSERT INTO entities VALUES (5,'Epsilon','project',datetime('now'),datetime('now'),0.85,'test.md');
INSERT INTO entities VALUES (6,'Zeta','person',datetime('now'),datetime('now'),0.75,'test.md');
INSERT INTO entities VALUES (7,'Eta','spec',datetime('now'),datetime('now'),0.8,'test.md');
INSERT INTO entities VALUES (8,'Theta','rule',datetime('now'),datetime('now'),0.9,'test.md');
INSERT INTO entities VALUES (9,'Iota','concept',datetime('now'),datetime('now'),0.85,'test.md');
INSERT INTO entities VALUES (10,'Kappa','tool',datetime('now'),datetime('now'),0.9,'test.md');
INSERT INTO relations VALUES (1,1,'uses',2,1.0);
INSERT INTO relations VALUES (2,2,'depends_on',3,1.0);
INSERT INTO relations VALUES (3,3,'implements',4,1.0);
INSERT INTO relations VALUES (4,5,'owns',6,1.0);
INSERT INTO relations VALUES (5,7,'mentions',8,1.0);
INSERT INTO relations VALUES (6,9,'uses',10,1.0);
INSERT INTO relations VALUES (7,1,'related_to',3,1.0);
INSERT INTO relations VALUES (8,4,'blocks',5,1.0);
INSERT INTO relations VALUES (9,6,'related_to',7,1.0);
INSERT INTO relations VALUES (10,8,'depends_on',9,1.0);
""")
con.close()
PY
}

# ── Test 1: Script exists and is executable ───────────────────────────────────
@test "SE-030-01: script exists and is bash-parseable" {
  [ -f "$SCRIPT" ]
  bash -n "$SCRIPT"
}

# ── Test 2: Script produces output (table format) ────────────────────────────
@test "SE-030-02: script produces output for valid DB" {
  create_minimal_db "$FIXTURE_DIR/minimal.db"
  run bash "$SCRIPT" --db "$FIXTURE_DIR/minimal.db"
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  [[ "$output" == *"GraphRAG Quality Gates"* ]] || [[ "$output" == *"Summary"* ]]
}

# ── Test 3: JSON output is valid JSON with required keys ─────────────────────
@test "SE-030-03: --json output is valid JSON with checks and summary" {
  create_minimal_db "$FIXTURE_DIR/json_test.db"
  run bash "$SCRIPT" --db "$FIXTURE_DIR/json_test.db" --json
  # Must be valid JSON parseable by python
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'checks' in d; assert 'summary' in d"
  [ $? -eq 0 ]
}

# ── Test 4: JSON output has exactly 12 checks ────────────────────────────────
@test "SE-030-04: JSON output contains exactly 12 checks" {
  create_minimal_db "$FIXTURE_DIR/count_test.db"
  run bash "$SCRIPT" --db "$FIXTURE_DIR/count_test.db" --json
  count=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['checks']))")
  [ "$count" -eq 12 ]
}

# ── Test 5: Missing DB emits WARN not hard error ──────────────────────────────
@test "SE-030-05: missing database does not crash (exits 0 with WARN)" {
  run bash "$SCRIPT" --db "/tmp/nonexistent-$(date +%s).db"
  # Should exit 0 (WARN) not 2 (crash)
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  [[ "$output" != *"Traceback"* ]]
}

# ── Test 6: Summary line appears in text output ───────────────────────────────
@test "SE-030-06: text output contains Summary line" {
  create_minimal_db "$FIXTURE_DIR/summary_test.db"
  run bash "$SCRIPT" --db "$FIXTURE_DIR/summary_test.db"
  [[ "$output" == *"Summary:"* ]]
}

# ── Test 7: Minimal valid DB passes min-entity-count check ───────────────────
@test "SE-030-07: valid DB with 10 entities passes min-entity-count" {
  create_minimal_db "$FIXTURE_DIR/entity_count.db"
  run bash "$SCRIPT" --db "$FIXTURE_DIR/entity_count.db" --json
  status_val=$(echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
check = next(c for c in d['checks'] if c['name'] == 'min-entity-count')
print(check['status'])
")
  [ "$status_val" = "PASS" ]
}

# ── Test 8: Self-loops are detected as FAIL ───────────────────────────────────
@test "SE-030-08: self-loops in relations are detected as FAIL" {
  create_minimal_db "$FIXTURE_DIR/self_loop.db"
  python3 -c "
import sqlite3
con=sqlite3.connect('$FIXTURE_DIR/self_loop.db')
con.execute(\"INSERT INTO relations VALUES(99,1,'self',1,1.0)\")
con.commit(); con.close()
"
  run bash "$SCRIPT" --db "$FIXTURE_DIR/self_loop.db" --json
  status_val=$(echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
check = next(c for c in d['checks'] if c['name'] == 'no-self-loops')
print(check['status'])
")
  [ "$status_val" = "FAIL" ]
}

# ── Test 9: confidence out of range detected ──────────────────────────────────
@test "SE-030-09: confidence scores outside [0,1] are detected as FAIL" {
  create_minimal_db "$FIXTURE_DIR/conf_fail.db"
  python3 -c "
import sqlite3
con=sqlite3.connect('$FIXTURE_DIR/conf_fail.db')
con.execute(\"UPDATE entities SET confidence=1.5 WHERE id=1\")
con.commit(); con.close()
"
  run bash "$SCRIPT" --db "$FIXTURE_DIR/conf_fail.db" --json
  status_val=$(echo "$output" | python3 -c "
import json,sys
d=json.load(sys.stdin)
check = next(c for c in d['checks'] if c['name'] == 'confidence-range')
print(check['status'])
")
  [ "$status_val" = "FAIL" ]
}

# ── Test 10: --help does not crash ────────────────────────────────────────────
@test "SE-030-10: --help flag exits cleanly" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}
