#!/usr/bin/env bats
# tests/hooks/test-stop-memory-extract.bats — SPEC-013v2: deep memory extraction

HOOK="$BATS_TEST_DIRNAME/../../.opencode/hooks/stop-memory-extract.sh"
LIB="$BATS_TEST_DIRNAME/../../.opencode/hooks/lib/memory-extract-lib.sh"

setup() {
  export TMPDIR_TEST="$BATS_TEST_TMPDIR/stop-extract-$$"
  mkdir -p "$TMPDIR_TEST/memory" "$TMPDIR_TEST/savia"
  export HOME="$TMPDIR_TEST"
  export CLAUDE_PROJECT_DIR="$TMPDIR_TEST/project"
  mkdir -p "$CLAUDE_PROJECT_DIR"
  export CANONICAL_SESSION_DIR="$HOME/.savia-memory/sessions/$(date +%Y-%m-%d)"
  export MEMORY_DIR="$CANONICAL_SESSION_DIR"
  mkdir -p "$MEMORY_DIR" "$HOME/.savia"
  # Enable standard profile so hook logic runs
  export SAVIA_HOOK_PROFILE="standard"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

@test "script is valid bash" {
  bash -n "$HOOK"
}

@test "lib is valid bash" {
  bash -n "$LIB"
}

@test "script uses set -uo pipefail" {
  head -5 "$HOOK" | grep -q "set -uo pipefail"
}

@test "no extraction when no session-hot or action-log" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "decisions extracted from session-hot" {
  local hot="$MEMORY_DIR/session-hot.md"
  echo "Decisions: We decided to use PostgreSQL instead of MySQL for the new service architecture" > "$hot"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  local found=$(find "$MEMORY_DIR" -name "session_decisions_*.md" | head -1)
  [ -n "$found" ]
  grep -q "PostgreSQL" "$found"
}

@test "repeated failures extracted from action log" {
  local log="$HOME/.savia/session-actions.jsonl"
  # 3 different actions that each failed 3+ times = enough content to pass 50-char gate
  for i in 1 2 3; do
    echo '{"action":"deploy-staging-environment","attempt":3,"ts":"2026-04-03T10:0'$i':00Z"}' >> "$log"
    echo '{"action":"run-integration-test-suite","attempt":4,"ts":"2026-04-03T10:0'$i':00Z"}' >> "$log"
  done
  touch "$MEMORY_DIR/session-hot.md"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  local found=$(find "$MEMORY_DIR" -name "session_failures_*.md" | head -1)
  [ -n "$found" ]
  grep -q "deploy-staging-environment" "$found"
}

@test "discovery extraction from session-hot" {
  local hot="$MEMORY_DIR/session-hot.md"
  echo "The root cause was a race condition in the connection pool manager that caused timeouts" > "$hot"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  local found=$(find "$MEMORY_DIR" -name "session_discoveries_*.md" | head -1)
  [ -n "$found" ]
  grep -q "race condition" "$found"
}

@test "reference extraction (URL) from session-hot" {
  local hot="$MEMORY_DIR/session-hot.md"
  # Put URL on its own line (not inside Decisions: line) to test reference extraction independently
  echo "See https://docs.microsoft.com/aspnet/core/security/authentication/overview and https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow for details" > "$hot"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  local found=$(find "$MEMORY_DIR" -name "session_references_*.md" | head -1)
  [ -n "$found" ]
  grep -q "docs.microsoft.com" "$found"
}

@test "quality gate: items shorter than 50 chars rejected" {
  local hot="$MEMORY_DIR/session-hot.md"
  echo "Decisions: use X" > "$hot"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  local count=$(find "$MEMORY_DIR" -name "session_decisions_*.md" | wc -l)
  [ "$count" -eq 0 ]
}

@test "quality gate: duplicate detection prevents double save" {
  local hot="$MEMORY_DIR/session-hot.md"
  local content="We decided to use PostgreSQL instead of MySQL for the new service architecture"
  echo "Decisions: $content" > "$hot"
  # First run saves
  bash "$HOOK" <<< ""
  local count1=$(find "$MEMORY_DIR" -name "session_decisions_*.md" | wc -l)
  [ "$count1" -eq 1 ]
  # Second run with same content should not duplicate
  echo "Decisions: $content" > "$hot"
  bash "$HOOK" <<< ""
  local count2=$(find "$MEMORY_DIR" -name "session_decisions_*.md" | wc -l)
  [ "$count2" -eq 1 ]
}

@test "quality gate: PII (email) rejected" {
  local hot="$MEMORY_DIR/session-hot.md"
  echo "Decisions: Send the report to john.doe@company.com and wait for approval from the team" > "$hot"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  local count=$(find "$MEMORY_DIR" -name "session_decisions_*.md" | wc -l)
  [ "$count" -eq 0 ]
}

@test "MEMORY.md index updated after extraction" {
  local hot="$MEMORY_DIR/session-hot.md"
  echo "Decisions: We decided to migrate from REST to GraphQL for the public API because of query flexibility" > "$hot"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  [ -f "$MEMORY_DIR/MEMORY.md" ]
  grep -q "session_decisions_" "$MEMORY_DIR/MEMORY.md"
}

@test "action log archived after extraction" {
  local log="$HOME/.savia/session-actions.jsonl"
  echo '{"action":"test","attempt":1}' > "$log"
  touch "$MEMORY_DIR/session-hot.md"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  [ ! -f "$log" ]
  local archived=$(find "$HOME/.savia" -name "session-actions-*.jsonl" | head -1)
  [ -n "$archived" ]
}

@test "output reports items saved count" {
  local hot="$MEMORY_DIR/session-hot.md"
  echo "Decisions: We decided to implement caching at the application layer using Redis for session storage" > "$hot"
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"items extracted to memory"* ]]
}
