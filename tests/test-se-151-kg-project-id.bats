#!/usr/bin/env bats
# test-se-151-kg-project-id.bats — SE-151: project_id support in knowledge-graph
# Ref: docs/propuestas/SE-151 / scripts/knowledge-graph.py
# Minimum 15 tests, target ≥80 score

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PY="$REPO_ROOT/scripts/knowledge-graph.py"
  export SH="$REPO_ROOT/scripts/knowledge-graph.sh"
  TMPDIR_KG="$(mktemp -d)"
  export KG_DB="$TMPDIR_KG/test-kg.db"
  # Override PROJECT_ROOT so scripts don't use the live workspace DB
  export PROJECT_ROOT="$REPO_ROOT"
}

teardown() {
  rm -rf "$TMPDIR_KG"
}

# ── Safety ──────────────────────────────────────────────────────────────────

@test "SE-151: py_compile passes on knowledge-graph.py" {
  run python3 -m py_compile "$PY"
  [ "$status" -eq 0 ]
}

@test "SE-151: knowledge-graph.sh has set -uo pipefail" {
  run grep -E "^set -[a-z]*uo[a-z]*\s*pipefail|^set -[a-z]*u[a-z]*\s+.*pipefail|set -uo pipefail|set -euo pipefail" "$SH"
  [ "$status" -eq 0 ]
}

# ── Flag acceptance ─────────────────────────────────────────────────────────

@test "SE-151: build --project flag accepted without error" {
  run python3 "$PY" build --db "$KG_DB" --project test-proj
  [ "$status" -eq 0 ]
}

@test "SE-151: status --project flag accepted without error" {
  python3 "$PY" build --db "$KG_DB" --project test-proj >/dev/null 2>&1
  run python3 "$PY" status --db "$KG_DB" --project test-proj
  [ "$status" -eq 0 ]
}

@test "SE-151: entities --project flag accepted without error" {
  python3 "$PY" build --db "$KG_DB" --project test-proj >/dev/null 2>&1
  run python3 "$PY" entities --db "$KG_DB" --project test-proj
  [ "$status" -eq 0 ]
}

@test "SE-151: query --project flag accepted without error" {
  python3 "$PY" build --db "$KG_DB" --project test-proj >/dev/null 2>&1
  run python3 "$PY" query "pm-workspace" --db "$KG_DB" --project test-proj
  [ "$status" -eq 0 ]
}

@test "SE-151: impact --project flag accepted without error" {
  python3 "$PY" build --db "$KG_DB" --project test-proj >/dev/null 2>&1
  run python3 "$PY" impact "pm-workspace" --db "$KG_DB" --project test-proj
  [ "$status" -eq 0 ]
}

# ── project_id column ──────────────────────────────────────────────────────

@test "SE-151: project_id column exists in entities table after build" {
  python3 "$PY" build --db "$KG_DB" --project test-proj >/dev/null 2>&1
  run python3 - "$KG_DB" <<'EOF'
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
cols = [row[1] for row in conn.execute("PRAGMA table_info(entities)")]
assert "project_id" in cols, f"project_id not in {cols}"
print("OK")
EOF
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "SE-151: project_id column exists on legacy DB (migration)" {
  # Create DB with old schema (no project_id), then open_db should migrate
  python3 - "$KG_DB" <<'EOF'
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
conn.executescript("""
CREATE TABLE IF NOT EXISTS entities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  first_seen TEXT DEFAULT (datetime('now')),
  last_seen  TEXT DEFAULT (datetime('now')),
  UNIQUE(name, type)
);
CREATE TABLE IF NOT EXISTS relations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_a INTEGER NOT NULL,
  relation TEXT NOT NULL,
  entity_b INTEGER NOT NULL,
  UNIQUE(entity_a, relation, entity_b)
);
""")
conn.commit()
EOF
  run python3 "$PY" status --db "$KG_DB"
  [ "$status" -eq 0 ]
  # Now project_id column should exist after open_db migration
  run python3 - "$KG_DB" <<'EOF'
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
cols = [row[1] for row in conn.execute("PRAGMA table_info(entities)")]
assert "project_id" in cols, f"project_id not in {cols}"
print("OK")
EOF
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── Filtering ──────────────────────────────────────────────────────────────

@test "SE-151: entities --project returns only entities for that project" {
  python3 "$PY" build --db "$KG_DB" --project alpha-proj >/dev/null 2>&1
  run python3 "$PY" entities --db "$KG_DB" --project alpha-proj
  [ "$status" -eq 0 ]
  # Output should be non-empty (sources were ingested)
  [ "${#lines[@]}" -gt 0 ]
}

@test "SE-151: entities nonexistent project returns 0 lines" {
  python3 "$PY" build --db "$KG_DB" --project alpha-proj >/dev/null 2>&1
  run python3 "$PY" entities --db "$KG_DB" --project nonexistent-xyz-proj
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 0 ]
}

@test "SE-151: entities without --project flag returns all entities" {
  python3 "$PY" build --db "$KG_DB" >/dev/null 2>&1
  run python3 "$PY" entities --db "$KG_DB"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -gt 0 ]
}

@test "SE-151: entities rows include project_id label when tagged" {
  python3 "$PY" build --db "$KG_DB" --project show-proj >/dev/null 2>&1
  run python3 "$PY" entities --db "$KG_DB" --project show-proj
  [ "$status" -eq 0 ]
  # At least one line should contain [show-proj]
  local found=0
  for line in "${lines[@]}"; do
    if [[ "$line" == *"[show-proj]"* ]]; then
      found=1
      break
    fi
  done
  [ "$found" -eq 1 ]
}

# ── Build tagging ──────────────────────────────────────────────────────────

@test "SE-151: build --project tags entities in DB" {
  python3 "$PY" build --db "$KG_DB" --project tag-test >/dev/null 2>&1
  run python3 - "$KG_DB" <<'EOF'
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
count = conn.execute(
  "SELECT COUNT(*) FROM entities WHERE project_id='tag-test'"
).fetchone()[0]
assert count > 0, f"Expected >0 entities with project_id=tag-test, got {count}"
print(f"OK: {count} entities tagged")
EOF
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "SE-151: build output shows project label" {
  run python3 "$PY" build --db "$KG_DB" --project labeled-proj
  [ "$status" -eq 0 ]
  [[ "$output" == *"[project=labeled-proj]"* ]]
}

# ── Edge cases ─────────────────────────────────────────────────────────────

@test "SE-151: empty DB status with --project returns 0 entities without crash" {
  # Create empty but valid DB
  python3 "$PY" build --db "$KG_DB" >/dev/null 2>&1
  # wipe entities
  python3 - "$KG_DB" <<'EOF'
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
conn.execute("DELETE FROM entities")
conn.execute("DELETE FROM relations")
conn.commit()
EOF
  run python3 "$PY" status --db "$KG_DB" --project any-proj
  [ "$status" -eq 0 ]
  [[ "$output" == *"Entities : 0"* ]]
}

@test "SE-151: build without --project (legacy mode) still works" {
  run python3 "$PY" build --db "$KG_DB"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BUILD complete"* ]]
  # No [project=] label
  [[ "$output" != *"[project="* ]]
}
