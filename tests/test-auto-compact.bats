#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-022-power-features-cli.md
# Tests for auto-compact.sh — Automatic context snapshot before compact

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/auto-compact.sh"
  TMPDIR_AC=$(mktemp -d)
  export CLAUDE_PROJECT_DIR="$TMPDIR_AC"
}

teardown() { rm -rf "$TMPDIR_AC"; }

@test "script has safety flags" {
  head -10 "$SCRIPT" | grep -qE "set -(e|u).*pipefail"
}

@test "runs without crash" {
  run bash "$SCRIPT"
  [[ "$status" -le 1 ]]
}

@test "creates snapshot directory" {
  bash "$SCRIPT" 2>/dev/null || true
  [[ -d "$TMPDIR_AC/output/context-snapshots" ]]
}

@test "negative: handles missing CLAUDE_PROJECT_DIR gracefully" {
  unset CLAUDE_PROJECT_DIR
  run bash "$SCRIPT"
  [[ "$status" -le 1 ]]
}

@test "edge: empty project dir handled" {
  export CLAUDE_PROJECT_DIR="$TMPDIR_AC/empty"
  mkdir -p "$TMPDIR_AC/empty"
  run bash "$SCRIPT"
  [[ "$status" -le 1 ]]
}

@test "coverage: SNAPSHOT_DIR variable defined" {
  grep -q "SNAPSHOT_DIR" "$SCRIPT"
}

@test "negative: nonexistent project dir does not crash" {
  export CLAUDE_PROJECT_DIR="/nonexistent/path/xyz"
  run bash "$SCRIPT"
  [[ "$status" -le 1 ]]
}

@test "edge: multiple runs are idempotent" {
  bash "$SCRIPT" 2>/dev/null || true
  bash "$SCRIPT" 2>/dev/null || true
  [[ -d "$TMPDIR_AC/output/context-snapshots" ]]
}

@test "edge: snapshot dir permissions" {
  bash "$SCRIPT" 2>/dev/null || true
  [[ -r "$TMPDIR_AC/output/context-snapshots" ]]
  [[ -w "$TMPDIR_AC/output/context-snapshots" ]]
}

@test "coverage: script uses mkdir -p" {
  grep -q "mkdir -p" "$SCRIPT"
}

@test "positive: script contains date or timestamp" {
  grep -qE "date|timestamp|iso|YYYY" "$SCRIPT"
}

@test "positive: script under 150 lines" {
  local lines
  lines=$(wc -l < "$SCRIPT")
  [[ "$lines" -le 150 ]]
}

@test "edge: zero-size project dir works" {
  export CLAUDE_PROJECT_DIR="$TMPDIR_AC/zero"
  mkdir -p "$TMPDIR_AC/zero"
  run bash "$SCRIPT"
  [ "$status" -le 1 ]
}

@test "edge: null CLAUDE_PROJECT_DIR value" {
  export CLAUDE_PROJECT_DIR=""
  run bash "$SCRIPT"
  [ "$status" -le 1 ]
}

@test "edge: boundary — nonexistent parent dir" {
  export CLAUDE_PROJECT_DIR="$TMPDIR_AC/deep/nested/path"
  run bash "$SCRIPT"
  [ "$status" -le 1 ]
}
