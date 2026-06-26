#!/usr/bin/env bats
# tests/bats/test-cognitive-debt.bats — SPEC-107 BATS tests
# Validates hook existence, master switch, protocol doc, and script output.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

@test "cognitive-debt-check.sh exists and is executable" {
  local hook="$REPO_ROOT/.opencode/hooks/cognitive-debt-check.sh"
  [ -f "$hook" ]
  [ -x "$hook" ]
}

@test "SAVIA_COGNITIVE_MONITOR=off exits 0 without banner" {
  local hook="$REPO_ROOT/.opencode/hooks/cognitive-debt-check.sh"
  run env SAVIA_COGNITIVE_MONITOR=off bash "$hook"
  [ "$status" -eq 0 ]
  # stderr must be empty when monitor is off
  [ -z "$output" ]
}

@test "cognitive-debt-protocol.md exists and mentions MIT Media Lab" {
  local doc="$REPO_ROOT/docs/rules/domain/cognitive-debt-protocol.md"
  [ -f "$doc" ]
  grep -q "MIT Media Lab" "$doc"
}

@test "cognitive-debt-monitor.py exists and produces JSON output" {
  local script="$REPO_ROOT/scripts/cognitive-debt-monitor.py"
  [ -f "$script" ]
  run python3 "$script" --session-hours 2 --verification-rate 0.8 --json
  [ "$status" -eq 0 ]
  # output must be valid JSON with cognitive_load_score field
  echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'cognitive_load_score' in d"
  [ "$?" -eq 0 ]
}

@test "hook exits 0 when SAVIA_COGNITIVE_MONITOR=on but session is short" {
  local hook="$REPO_ROOT/.opencode/hooks/cognitive-debt-check.sh"
  # Force a fresh session start file far in the future (session ~0h)
  local tmp_start
  tmp_start=$(mktemp)
  date +%s > "$tmp_start"
  run env SAVIA_COGNITIVE_MONITOR=on \
      SAVIA_SESSION_START_FILE="$tmp_start" \
      COGNITIVE_DEBT_SESSION_LIMIT=4 \
      bash "$hook"
  [ "$status" -eq 0 ]
  rm -f "$tmp_start"
}
