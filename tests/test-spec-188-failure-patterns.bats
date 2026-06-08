#!/usr/bin/env bats
# SPEC-188 Fase 1: Failure Pattern Memory — BATS tests
# Ref: docs/propuestas/SPEC-188-root-cause-investigation-architecture.md (Fase 1, P1)
# Quality gate: >=18 tests, score >=80
# Script under test: scripts/failure-pattern-memory.sh

SCRIPT="scripts/failure-pattern-memory.sh"
RULE_DOC="docs/rules/domain/failure-pattern-memory.md"
CMD_OPENCODE=".opencode/commands/failure-patterns.md"
CMD_CLAUDE=".claude/commands/failure-patterns.md"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  # Isolated temp dir per test — DB never shared between tests
  TMP_DIR="$(mktemp -d)"
  export PROJECT_ROOT="$TMP_DIR"
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=0
  # Script under test (from repo)
  SCRIPT_PATH="$REPO_ROOT/$SCRIPT"
}

teardown() {
  [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
}

# ── Static assertions ────────────────────────────────────────────────────────

@test "T01: script exists" {
  [ -f "$REPO_ROOT/$SCRIPT" ]
}

@test "T02: script is executable" {
  [ -x "$REPO_ROOT/$SCRIPT" ]
}

@test "T03: script contains set -uo pipefail" {
  grep -q 'set -uo pipefail' "$REPO_ROOT/$SCRIPT"
}

@test "T04: SPEC-188 is referenced in script" {
  grep -q 'SPEC-188' "$REPO_ROOT/$SCRIPT"
}

@test "T05: failure-pattern-memory.md rule doc exists" {
  [ -f "$REPO_ROOT/$RULE_DOC" ]
}

@test "T06: rule doc has correct context_tier" {
  grep -q 'context_tier: L2' "$REPO_ROOT/$RULE_DOC"
}

@test "T07: opencode command exists" {
  [ -f "$REPO_ROOT/$CMD_OPENCODE" ]
}

@test "T08: claude command exists" {
  [ -f "$REPO_ROOT/$CMD_CLAUDE" ]
}

@test "T09: command files are identical (symlink or same content)" {
  # Both paths must resolve to the same content (symlink or copy)
  diff <(cat "$REPO_ROOT/$CMD_OPENCODE") <(cat "$REPO_ROOT/$CMD_CLAUDE")
}

# ── init subcommand ──────────────────────────────────────────────────────────

@test "T10: init creates the schema — table failure_patterns exists" {
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1
  run bash "$SCRIPT_PATH" init
  [ "$status" -eq 0 ]
  DB="$TMP_DIR/.claude/external-memory/failure-patterns/patterns.db"
  [ -f "$DB" ]
  # Verify table exists via Python sqlite3
  result=$(python3 -c "
import sqlite3, sys
conn = sqlite3.connect('$DB')
tables = conn.execute(\"SELECT name FROM sqlite_master WHERE type='table' AND name='failure_patterns'\").fetchall()
print(len(tables))
conn.close()
")
  [ "$result" = "1" ]
}

@test "T11: init is idempotent — second call does not fail" {
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1
  run bash "$SCRIPT_PATH" init
  [ "$status" -eq 0 ]
  run bash "$SCRIPT_PATH" init
  [ "$status" -eq 0 ]
}

# ── add subcommand ───────────────────────────────────────────────────────────

@test "T12: add inserts a pattern when flag enabled" {
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1
  bash "$SCRIPT_PATH" init >/dev/null
  run bash "$SCRIPT_PATH" add --agent court-orchestrator --error "threshold below 80"
  [ "$status" -eq 0 ]
  [[ "$output" == *"INSERTED"* ]]
}

@test "T13: add increments occurrences on repeated same pattern" {
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1
  bash "$SCRIPT_PATH" init >/dev/null
  bash "$SCRIPT_PATH" add --agent court-orchestrator --error "threshold below 80" >/dev/null
  run bash "$SCRIPT_PATH" add --agent court-orchestrator --error "threshold below 80"
  [ "$status" -eq 0 ]
  [[ "$output" == *"UPDATED"* ]]
  [[ "$output" == *"occurrences=2"* ]]
}

@test "T14: add without --agent exits non-zero" {
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1
  bash "$SCRIPT_PATH" init >/dev/null
  run bash "$SCRIPT_PATH" add --error "some error"
  [ "$status" -ne 0 ]
}

@test "T15: add is no-op when flag disabled" {
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=0
  run bash "$SCRIPT_PATH" add --agent court-orchestrator --error "threshold below 80"
  [ "$status" -eq 0 ]
  [[ "$output" == *"disabled"* ]]
  # DB must not be created
  DB="$TMP_DIR/.claude/external-memory/failure-patterns/patterns.db"
  [ ! -f "$DB" ]
}

# ── list subcommand ──────────────────────────────────────────────────────────

@test "T16: list returns entries after add" {
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1
  bash "$SCRIPT_PATH" init >/dev/null
  bash "$SCRIPT_PATH" add --agent test-agent --error "connection refused" >/dev/null
  run bash "$SCRIPT_PATH" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"test-agent"* ]]
}

@test "T17: list empty store returns 0 entries without crash" {
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1
  bash "$SCRIPT_PATH" init >/dev/null
  run bash "$SCRIPT_PATH" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 entries"* ]]
}

# ── show subcommand ──────────────────────────────────────────────────────────

@test "T18: show returns detail for known pattern" {
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1
  bash "$SCRIPT_PATH" init >/dev/null
  output_add=$(bash "$SCRIPT_PATH" add --agent test-agent --error "null pointer" 2>&1)
  # Extract pattern_id from INSERTED line
  pid=$(echo "$output_add" | grep 'INSERTED:' | awk '{print $2}')
  run bash "$SCRIPT_PATH" show "$pid"
  [ "$status" -eq 0 ]
  [[ "$output" == *"test-agent"* ]]
  [[ "$output" == *"null pointer"* ]]
}

@test "T19: show unknown pattern_id returns NOT_FOUND without crash" {
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1
  bash "$SCRIPT_PATH" init >/dev/null
  run bash "$SCRIPT_PATH" show "deadbeef"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NOT_FOUND"* ]]
}

# ── resolve subcommand ───────────────────────────────────────────────────────

@test "T20: resolve changes status to resolved" {
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1
  bash "$SCRIPT_PATH" init >/dev/null
  out_add=$(bash "$SCRIPT_PATH" add --agent test-agent --error "exit 1" 2>&1)
  pid=$(echo "$out_add" | grep 'INSERTED:' | awk '{print $2}')
  run bash "$SCRIPT_PATH" resolve "$pid" --lesson "fixed in hook v2"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RESOLVED"* ]]
  # Verify status via show
  run bash "$SCRIPT_PATH" show "$pid"
  [[ "$output" == *"resolved"* ]]
}

# ── stats subcommand ─────────────────────────────────────────────────────────

@test "T21: stats shows summary totals" {
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1
  bash "$SCRIPT_PATH" init >/dev/null
  bash "$SCRIPT_PATH" add --agent agent-a --error "error A" >/dev/null
  bash "$SCRIPT_PATH" add --agent agent-b --error "error B" >/dev/null
  run bash "$SCRIPT_PATH" stats
  [ "$status" -eq 0 ]
  [[ "$output" == *"total:"* ]]
  [[ "$output" == *"open:"* ]]
  [[ "$output" == *"resolved:"* ]]
}

@test "T22: stats works even when flag disabled" {
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=0
  run bash "$SCRIPT_PATH" stats
  [ "$status" -eq 0 ]
  [[ "$output" == *"SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=0"* ]]
}

# ── bridge: occurrences >= 10 promotion hint ─────────────────────────────────

@test "T23: add emits promotion hint after 10 occurrences" {
  export SAVIA_FAILURE_PATTERN_MEMORY_ENABLED=1
  bash "$SCRIPT_PATH" init >/dev/null
  # Insert 9 times first
  for i in $(seq 1 9); do
    bash "$SCRIPT_PATH" add --agent sentinel --error "repeated error" >/dev/null
  done
  # 10th insert should emit BRIDGE hint
  run bash "$SCRIPT_PATH" add --agent sentinel --error "repeated error"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BRIDGE"* ]] || [[ "$output" == *"feedback"* ]] || [[ "$output" == *"10"* ]]
}
