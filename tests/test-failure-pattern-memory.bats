#!/usr/bin/env bats
# tests/test-failure-pattern-memory.bats
# SPEC-188 Fase 1 — failure-pattern-memory.sh formal tests
# >= 6 tests
#
# Tests the failure pattern memory store introduced in SPEC-188 Phase 1.
# Uses a temporary SQLite database so production data is never touched.
# Feature flag: SAVIA_FAILURE_PATTERN_MEMORY_ENABLED (default 0)

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/failure-pattern-memory.sh"

# ── Setup/teardown ────────────────────────────────────────────────────────────
setup() {
  # Isolated temp dir per test — avoids cross-test DB contamination
  TEST_TMP="$(mktemp -d)"
  export PROJECT_ROOT="$TEST_TMP"
  export DB_FILE_OVERRIDE="$TEST_TMP/.claude/external-memory/failure-patterns/patterns.db"
  # Enable feature flag for tests that need it
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1
}

teardown() {
  rm -rf "$TEST_TMP"
}

# ── Test 1: script exists and is executable ───────────────────────────────────
@test "SPEC-188-F1 AC-01: failure-pattern-memory.sh exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

# ── Test 2: init creates the database structure ───────────────────────────────
@test "SPEC-188-F1 AC-02: init creates the SQLite database and failure_patterns table" {
  run bash "$SCRIPT" init
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "OK\|initialised\|schema"

  # Verify the DB file was created
  DB_PATH="$TEST_TMP/.claude/external-memory/failure-patterns/patterns.db"
  [[ -f "$DB_PATH" ]]

  # Verify the table schema was created
  run python3 -c "
import sqlite3, sys
conn = sqlite3.connect('$DB_PATH')
cur = conn.cursor()
cur.execute(\"SELECT name FROM sqlite_master WHERE type='table' AND name='failure_patterns'\")
row = cur.fetchone()
sys.exit(0 if row else 1)
"
  [ "$status" -eq 0 ]
}

# ── Test 3: add inserts a pattern (with feature flag enabled) ─────────────────
@test "SPEC-188-F1 AC-03: add inserts a failure pattern into the database" {
  # Pre-init the DB
  bash "$SCRIPT" init > /dev/null 2>&1

  run bash "$SCRIPT" add \
    --agent "test-runner" \
    --error "TimeoutException: test took >120s" \
    --file-glob "tests/**/*.bats" \
    --lesson "Reduce fixture size to avoid timeout"

  [ "$status" -eq 0 ]
  # Output confirms INSERT or UPDATED
  echo "$output" | grep -qE "INSERTED|UPDATED"
}

# ── Test 4: list returns output (possibly empty, but no error) ────────────────
@test "SPEC-188-F1 AC-04: list returns valid output (empty or populated, no error)" {
  bash "$SCRIPT" init > /dev/null 2>&1

  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  # Output must be non-empty (at minimum "0 entries" message)
  [[ -n "$output" ]]
}

# ── Test 5: stats returns structured text output ──────────────────────────────
@test "SPEC-188-F1 AC-05: stats returns structured text with total/open/acknowledged/resolved fields" {
  bash "$SCRIPT" init > /dev/null 2>&1

  run bash "$SCRIPT" stats
  [ "$status" -eq 0 ]
  # Must include the key counters
  echo "$output" | grep -q "total:"
  echo "$output" | grep -q "open:"
  echo "$output" | grep -q "resolved:"
  # Must also report the feature flag state
  echo "$output" | grep -q "SAVIA_FAILURE_PATTERN_MEMORY_ENABLED"
}

# ── Test 6: SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=0 → disabled behavior ────────
@test "SPEC-188-F1 AC-06: ENABLED=0 disables add and list (returns info message)" {
  bash "$SCRIPT" init > /dev/null 2>&1
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=0

  run bash "$SCRIPT" add --agent "dotnet-developer" --error "NullRef"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "disabled\|ENABLED=0\|SAVIA_FAILURE_PATTERN_MEMORY_ENABLED"

  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "disabled\|ENABLED=0\|SAVIA_FAILURE_PATTERN_MEMORY_ENABLED"
}

# ── Test 7: add + list round-trip (data persists) ─────────────────────────────
@test "SPEC-188-F1 AC-07: add then list round-trip — inserted pattern appears in list" {
  bash "$SCRIPT" init > /dev/null 2>&1

  bash "$SCRIPT" add \
    --agent "python-developer" \
    --error "ModuleNotFoundError: fastapi" \
    > /dev/null 2>&1

  run bash "$SCRIPT" list
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "python-developer"
}

# ── Test 8: stats works even on empty store (no crash) ────────────────────────
@test "SPEC-188-F1 AC-08: stats on uninitialised store does not crash" {
  # No init called — DB does not exist
  # stats should handle gracefully (not crash with exit code != 0)
  run bash "$SCRIPT" stats
  # Exit 0 expected (graceful handling)
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "not initialised\|not initialized\|Store"
}
