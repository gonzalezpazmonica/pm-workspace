#!/usr/bin/env bats
# Tests for tool-call-healing.sh (Era 170 — Tool Resilience)
# Ref: docs/rules/domain/context-health.md

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)}"

setup() {
  TMPDIR=$(mktemp -d)
  HOOK="$REPO_ROOT/.opencode/hooks/tool-call-healing.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "tool-call-healing.sh has safety flags" {
  grep -q "set -uo pipefail" "$HOOK"
}

@test "exit 0 on empty input" {
  run bash "$HOOK" < /dev/null
  [ "$status" -eq 0 ]
}

@test "Read with empty file_path blocked" {
  run bash -c 'echo "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"\"}}" | bash '"$HOOK"
  [ "$status" -eq 2 ]
}

@test "Write with empty file_path blocked" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"\"}}" | bash '"$HOOK"
  [ "$status" -eq 2 ]
}

@test "Write to nonexistent parent dir blocked" {
  run bash -c 'echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"/tmp/nonexistent_xyz123/f.md\"}}" | bash '"$HOOK"
  [ "$status" -eq 2 ]
}

@test "Glob with empty pattern blocked" {
  run bash -c 'echo "{\"tool_name\":\"Glob\",\"tool_input\":{\"pattern\":\"\"}}" | bash '"$HOOK"
  [ "$status" -eq 2 ]
}

@test "Grep with empty pattern blocked" {
  run bash -c 'echo "{\"tool_name\":\"Grep\",\"tool_input\":{\"pattern\":\"\"}}" | bash '"$HOOK"
  [ "$status" -eq 2 ]
}

@test "Read with valid file_path passes" {
  run bash -c "echo '{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$REPO_ROOT/CLAUDE.md\"}}' | bash $HOOK"
  [ "$status" -eq 0 ]
}

@test "unknown tool passes through" {
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls\"}}" | bash '"$HOOK"
  [ "$status" -eq 0 ]
}
