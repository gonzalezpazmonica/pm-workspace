#!/usr/bin/env bats
# Tests for SPEC-048 Dev Session Discard — Phase 1

SCRIPT="scripts/dev-session-discard.sh"

setup() {
  export TMPDIR_ROOT
  TMPDIR_ROOT=$(mktemp -d)
  export CLAUDE_PROJECT_DIR="$TMPDIR_ROOT"

  # Create session directories
  mkdir -p "$TMPDIR_ROOT/.claude/sessions"
  mkdir -p "$TMPDIR_ROOT/output/dev-sessions"

  # Create a sample lock file
  cat > "$TMPDIR_ROOT/.claude/sessions/test-session-01.lock" <<'LOCK'
{
  "session_id": "test-session-01",
  "pid": 99999,
  "started_at": "2026-03-29T01:00:00Z",
  "updated_at": "2026-03-29T01:15:00Z",
  "current_slice": 2,
  "total_slices": 4,
  "state": "implementing"
}
LOCK

  # Create a sample state file
  mkdir -p "$TMPDIR_ROOT/output/dev-sessions/test-session-01"
  cat > "$TMPDIR_ROOT/output/dev-sessions/test-session-01/state.json" <<'STATE'
{
  "session_id": "test-session-01",
  "spec_path": "specs/AB100.spec.md",
  "total_slices": 4,
  "current_slice": 2,
  "slices": [
    {"id": 1, "status": "completed", "files": ["Service.cs"]},
    {"id": 2, "status": "implementing", "files": ["Controller.cs"]},
    {"id": 3, "status": "pending", "files": ["Tests.cs"]},
    {"id": 4, "status": "pending", "files": ["Integration.cs"]}
  ]
}
STATE
}

teardown() {
  rm -rf "$TMPDIR_ROOT"
}

@test "dev-session-discard.sh exists" {
  [ -f "$SCRIPT" ]
}

@test "dev-session-discard.sh is executable" {
  [ -x "$SCRIPT" ]
}

@test "dev-session-discard.sh has set -uo pipefail" {
  head -5 "$SCRIPT" | grep -q "set -uo pipefail"
}

@test "handles no arguments with error" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" == *"session ID required"* ]]
}

@test "handles missing session with error" {
  run bash "$SCRIPT" "nonexistent-session-xyz"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "creates discard log entry" {
  run bash "$SCRIPT" "test-session-01" "spec changed"
  [ "$status" -eq 0 ]
  LOGFILE="$TMPDIR_ROOT/output/dev-sessions/discard-log.jsonl"
  [ -f "$LOGFILE" ]
  # Validate JSON and check session_id
  python3 -c "
import json
with open('$LOGFILE') as f:
    entry = json.loads(f.readline())
assert entry['session_id'] == 'test-session-01', f'Got {entry[\"session_id\"]}'
assert entry['reason'] == 'spec changed', f'Got {entry[\"reason\"]}'
assert entry['had_lock'] == True
assert entry['had_state'] == True
assert entry['slices_completed'] == 1
assert entry['slices_total'] == 4
"
}

@test "cleans lock file" {
  LOCK="$TMPDIR_ROOT/.claude/sessions/test-session-01.lock"
  [ -f "$LOCK" ]
  run bash "$SCRIPT" "test-session-01"
  [ "$status" -eq 0 ]
  [ ! -f "$LOCK" ]
}

@test "archives state file with .discarded suffix" {
  STATE="$TMPDIR_ROOT/output/dev-sessions/test-session-01/state.json"
  [ -f "$STATE" ]
  run bash "$SCRIPT" "test-session-01"
  [ "$status" -eq 0 ]
  [ ! -f "$STATE" ]
  [ -f "${STATE}.discarded" ]
}

@test "works with lock only (no state file)" {
  # Remove state file but keep lock
  rm -rf "$TMPDIR_ROOT/output/dev-sessions/test-session-01"
  run bash "$SCRIPT" "test-session-01" "lock only test"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Lock removed: true"* ]]
  [[ "$output" == *"State archived: false"* ]]
}

@test "works with state only (no lock file)" {
  # Remove lock but keep state
  rm -f "$TMPDIR_ROOT/.claude/sessions/test-session-01.lock"
  run bash "$SCRIPT" "test-session-01" "state only test"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Lock removed: false"* ]]
  [[ "$output" == *"State archived: true"* ]]
}

@test "SPEC-048 document exists" {
  [ -f "docs/propuestas/SPEC-048-dev-session-discard.md" ]
}
