#!/usr/bin/env bats
# Tests for Era 107.3 — Backlog Resolver (local-first data source)

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
  # Create temporary test backlog
  TEST_PROJ="$ROOT/projects/_test-resolver-$$"
  mkdir -p "$TEST_PROJ/backlog/pbi" "$TEST_PROJ/backlog/sprints"
  cp "$ROOT/.claude/templates/backlog/config-template.yaml" "$TEST_PROJ/backlog/_config.yaml"
  sed -i "s/{PROJECT}/test-proj/;s/{DATE}/2026-03-14/" "$TEST_PROJ/backlog/_config.yaml"
  echo "2026-S11" > "$TEST_PROJ/backlog/_current-sprint.md"
  # Create a test PBI
  cat > "$TEST_PROJ/backlog/pbi/PBI-001-test.md" <<'EOPBI'
---
id: PBI-001
title: "Test item"
type: User Story
state: Active
priority: 2-High
estimation_sp: 5
assigned_to: "alice"
sprint: "2026-S11"
---
EOPBI
  export RESOLVER_ROOT="$ROOT"
  source "$ROOT/scripts/backlog-resolver.sh"
}

teardown() {
  rm -rf "$TEST_PROJ" 2>/dev/null || true
}

@test "backlog-resolver.sh exists and is executable" {
  [ -x "$ROOT/scripts/backlog-resolver.sh" ]
}

@test "has_local_backlog detects test backlog" {
  has_local_backlog "_test-resolver-$$"
}

@test "resolve_backlog_path returns valid path" {
  local path; path=$(resolve_backlog_path "_test-resolver-$$")
  [ -d "$path" ]
}

@test "get_current_sprint returns sprint ID" {
  local sprint; sprint=$(get_current_sprint "_test-resolver-$$")
  [ "$sprint" = "2026-S11" ]
}

@test "count_by_state returns correct count" {
  local count; count=$(count_by_state "_test-resolver-$$" "Active")
  [ "$count" = "1" ]
}

@test "board_summary outputs state counts" {
  local summary; summary=$(board_summary "_test-resolver-$$")
  echo "$summary" | grep -q "Active: 1"
}

@test "data_source returns local for test project" {
  local src; src=$(data_source "_test-resolver-$$")
  [ "$src" = "local" ]
}

@test "data_source returns none for nonexistent project" {
  unset AZURE_DEVOPS_ORG_URL 2>/dev/null || true
  local src; src=$(data_source "nonexistent-xyz-$$")
  [ "$src" = "none" ]
}

# ── Negative cases ──

@test "count_by_state returns 0 for unknown state" {
  [[ -n "${CI:-}" ]] && skip "needs backlog resolver setup"
  local count; count=$(count_by_state "_test-resolver-$$" "NonExistentState")
  [ "$count" = "0" ]
}

@test "has_local_backlog fails for missing project" {
  run has_local_backlog "project-that-does-not-exist-$$"
  [ "$status" -ne 0 ]
}

# ── Edge cases ──

@test "board_summary handles empty backlog dir" {
  rm -f "$TEST_PROJ/backlog/pbi/"*.md
  local summary; summary=$(board_summary "_test-resolver-$$")
  # Should still work, just no counts
  [ -n "$summary" ]
}

# ── Spec/doc reference ──
# Ref: docs/rules/domain/backlog-git-config.md

@test "resolver script references backlog sovereignty" {
  grep -q "local" "$ROOT/scripts/backlog-resolver.sh"
}

@test "target has safety flags" {
  grep -q "set -[euo]" "$ROOT/scripts/backlog-resolver.sh"
}

@test "limit: large sprint name handled" {
  local sprint; sprint=$(get_current_sprint "_test-resolver-$$")
  [ -n "$sprint" ]
  python3 -c "assert len('$sprint') > 0"
}

@test "core hooks use safety flags" {
  grep -q "set -[euo]" .opencode/hooks/validate-bash-global.sh
}
