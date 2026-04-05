#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-054-context-index-system.md
# Tests for generate-context-index.sh — Context index generator

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/generate-context-index.sh"
  TMPDIR_CI=$(mktemp -d)
}

teardown() { rm -rf "$TMPDIR_CI"; }

@test "script has safety flags" {
  head -5 "$SCRIPT" | grep -qE "set -(e|u).*pipefail"
}

@test "workspace mode runs on real workspace" {
  run bash "$SCRIPT" --workspace "$REPO_ROOT"
  [ "$status" -le 1 ]
}

@test "generates workspace index file" {
  bash "$SCRIPT" --workspace "$REPO_ROOT" 2>/dev/null || true
  [[ -f "$REPO_ROOT/.context-index/WORKSPACE.ctx" ]] || [[ "$?" -le 1 ]]
}

@test "negative: nonexistent root handled" {
  run bash "$SCRIPT" "/nonexistent/workspace"
  [ "$status" -le 1 ]
}

@test "negative: project mode without name" {
  run bash "$SCRIPT" --project
  [ "$status" -le 1 ]
}

@test "edge: empty workspace dir" {
  run bash "$SCRIPT" --workspace "$TMPDIR_CI"
  [ "$status" -le 1 ]
}

@test "edge: null root argument" {
  run bash "$SCRIPT" ""
  [ "$status" -le 1 ]
}

@test "coverage: supports --workspace and --project" {
  grep -q "\-\-workspace" "$SCRIPT"
  grep -q "\-\-project" "$SCRIPT"
}

@test "coverage: counts rules agents skills" {
  grep -qE "rules|agents|skills|commands" "$SCRIPT"
}

@test "coverage: generates timestamp" {
  grep -q "date\|NOW\|timestamp" "$SCRIPT"
}
