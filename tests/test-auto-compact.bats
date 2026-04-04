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
