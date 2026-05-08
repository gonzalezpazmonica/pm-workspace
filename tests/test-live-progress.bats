#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-042-live-progress-feedback.md
# Tests for live-progress-hook.sh — Real-time tool use logging

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/.opencode/hooks/live-progress-hook.sh"
  TMPDIR_LP=$(mktemp -d)
  export HOME="$TMPDIR_LP"
  mkdir -p "$TMPDIR_LP/.savia"
}

teardown() { rm -rf "$TMPDIR_LP"; }

@test "script has safety flags" {
  head -5 "$SCRIPT" | grep -qE "set -(e|u).*pipefail"
}

@test "valid bash syntax" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "handles empty stdin" {
  run bash -c "echo '' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "handles JSON tool input" {
  run bash -c "echo '{\"tool\":\"Bash\",\"input\":{\"command\":\"ls\"}}' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "positive: processes tool event without crash" {
  run bash -c "echo '{\"tool\":\"Read\"}' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "negative: missing savia dir handled" {
  export HOME="$TMPDIR_LP/empty"
  run bash -c "echo '{}' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "edge: very large JSON input" {
  local big
  big=$(python3 -c "print('{\"tool\":\"Bash\",\"x\":\"' + 'A'*5000 + '\"}')" 2>/dev/null || echo '{"tool":"Bash"}')
  run bash -c "echo '$big' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "edge: null tool field" {
  run bash -c "echo '{\"tool\":null}' | bash '$SCRIPT'"
  [ "$status" -eq 0 ]
}

@test "coverage: logs to live.log" {
  grep -q "live.log\|live_log" "$SCRIPT"
}

@test "coverage: rotation logic exists" {
  grep -q "500\|rotate\|tail\|wc -l" "$SCRIPT"
}
