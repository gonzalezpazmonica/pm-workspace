#!/usr/bin/env bats
# Tests for emotional-regulation-monitor.sh
# Savia Emotional Regulation — session stress assessment
# Ref: Anthropic "Emotion concepts in LLMs" (2026-04-02)

setup() {
  TMPDIR=$(mktemp -d)
  export HOME="$TMPDIR"
  export SAVIA_HOOK_PROFILE="standard"
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOOK="$REPO_ROOT/.claude/hooks/emotional-regulation-monitor.sh"
  TRACKER="$REPO_ROOT/scripts/emotional-state-tracker.sh"
  export CLAUDE_PROJECT_DIR="$REPO_ROOT"
  # Setup memory directory
  PROJ_SLUG=$(echo "$REPO_ROOT" | sed 's|[/:\]|-|g; s|^-||')
  MEMORY_DIR="$TMPDIR/.claude/projects/$PROJ_SLUG/memory"
  mkdir -p "$MEMORY_DIR"
  touch "$MEMORY_DIR/MEMORY.md"
  mkdir -p "$TMPDIR/.savia"
}

teardown() {
  rm -rf "$TMPDIR"
}

run_hook() {
  run bash -c "echo '{}' | bash '$HOOK'"
}

@test "hook has safety flags" {
  grep -q "set -uo pipefail" "$HOOK"
}

@test "calm session (score 0): no output, no memory" {
  bash "$TRACKER" reset
  run_hook
  [ "$status" -eq 0 ]
  # No memory file should be created
  local count
  count=$(find "$MEMORY_DIR" -name "session_stress_*" 2>/dev/null | wc -l)
  [ "$count" -eq 0 ]
}

@test "mild friction (score 2): no memory persisted" {
  bash "$TRACKER" reset
  bash "$TRACKER" record retry
  bash "$TRACKER" record retry
  run_hook
  [ "$status" -eq 0 ]
  local count
  count=$(find "$MEMORY_DIR" -name "session_stress_*" 2>/dev/null | wc -l)
  [ "$count" -eq 0 ]
}

@test "significant friction (score 5+): memory persisted" {
  bash "$TRACKER" reset
  for i in 1 2 3 4 5; do bash "$TRACKER" record retry; done
  bash "$TRACKER" record failure
  bash "$TRACKER" record failure
  bash "$TRACKER" record escalation
  run_hook
  [ "$status" -eq 0 ]
  local count
  count=$(find "$MEMORY_DIR" -name "session_stress_*" 2>/dev/null | wc -l)
  [ "$count" -eq 1 ]
}

@test "memory file has correct frontmatter" {
  bash "$TRACKER" reset
  for i in 1 2 3 4 5; do bash "$TRACKER" record retry; done
  bash "$TRACKER" record failure
  bash "$TRACKER" record failure
  bash "$TRACKER" record escalation
  run_hook
  local file
  file=$(find "$MEMORY_DIR" -name "session_stress_*" | head -1)
  [ -f "$file" ]
  grep -q "^name:" "$file"
  grep -q "^type: feedback" "$file"
  grep -q "Anthropic" "$file"
}

@test "memory file contains event counts" {
  bash "$TRACKER" reset
  for i in 1 2 3; do bash "$TRACKER" record failure; done
  bash "$TRACKER" record escalation
  bash "$TRACKER" record escalation
  # Need enough for score 5+: 3*2 + 2*3 = 12 raw → score 5
  run_hook
  local file
  file=$(find "$MEMORY_DIR" -name "session_stress_*" | head -1)
  [ -f "$file" ]
  grep -q "Failures: 3" "$file"
  grep -q "Escalations: 2" "$file"
}

@test "MEMORY.md index updated" {
  bash "$TRACKER" reset
  for i in 1 2 3 4 5; do bash "$TRACKER" record retry; done
  bash "$TRACKER" record failure
  bash "$TRACKER" record failure
  bash "$TRACKER" record escalation
  run_hook
  grep -q "session_stress_" "$MEMORY_DIR/MEMORY.md"
}

@test "state reset after assessment" {
  bash "$TRACKER" reset
  for i in 1 2 3 4 5; do bash "$TRACKER" record retry; done
  bash "$TRACKER" record failure
  bash "$TRACKER" record failure
  bash "$TRACKER" record escalation
  run_hook
  # Score should be 0 after reset
  local score
  score=$(bash "$TRACKER" score)
  [ "$score" -eq 0 ]
}

@test "missing state file exits gracefully" {
  rm -f "$HOME/.savia/session-stress.json"
  run_hook
  [ "$status" -eq 0 ]
}

@test "always exits 0 (never blocks stop)" {
  bash "$TRACKER" reset
  for i in $(seq 1 20); do bash "$TRACKER" record failure; done
  run_hook
  [ "$status" -eq 0 ]
}

@test "no duplicate entries on same day" {
  bash "$TRACKER" reset
  for i in 1 2 3 4 5; do bash "$TRACKER" record retry; done
  bash "$TRACKER" record failure; bash "$TRACKER" record failure
  bash "$TRACKER" record escalation
  run_hook
  # Simulate second run same day (re-add events)
  for i in 1 2 3 4 5; do bash "$TRACKER" record retry; done
  bash "$TRACKER" record failure; bash "$TRACKER" record failure
  bash "$TRACKER" record escalation
  run_hook
  local count
  count=$(find "$MEMORY_DIR" -name "session_stress_*" 2>/dev/null | wc -l)
  [ "$count" -eq 1 ]
}

@test "skipped under minimal profile" {
  export SAVIA_HOOK_PROFILE="minimal"
  bash "$TRACKER" reset
  for i in $(seq 1 10); do bash "$TRACKER" record failure; done
  run_hook
  [ "$status" -eq 0 ]
  local count
  count=$(find "$MEMORY_DIR" -name "session_stress_*" 2>/dev/null | wc -l)
  [ "$count" -eq 0 ]
}
