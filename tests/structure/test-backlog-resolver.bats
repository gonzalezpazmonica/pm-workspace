#!/usr/bin/env bats
# Tests for Era 107.3 — Backlog Resolver (local-first data source)

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
  export RESOLVER_ROOT="$ROOT"
  source "$ROOT/scripts/backlog-resolver.sh"
}

@test "backlog-resolver.sh exists and is executable" {
  [ -x "$ROOT/scripts/backlog-resolver.sh" ]
}

@test "has_local_backlog detects savia-web backlog" {
  has_local_backlog "savia-web"
}

@test "resolve_backlog_path returns valid path" {
  local path; path=$(resolve_backlog_path "savia-web")
  [ -d "$path" ]
}

@test "get_current_sprint returns sprint ID" {
  local sprint; sprint=$(get_current_sprint "savia-web")
  [[ "$sprint" =~ ^20[0-9]{2}-S[0-9]{2}$ ]]
}

@test "count_by_state returns numeric value" {
  local count; count=$(count_by_state "savia-web")
  [[ "$count" =~ ^[0-9]+$ ]]
}

@test "board_summary outputs state counts" {
  local summary; summary=$(board_summary "savia-web")
  echo "$summary" | grep -q "New:"
  echo "$summary" | grep -q "Active:"
}

@test "data_source returns local for savia-web" {
  local src; src=$(data_source "savia-web")
  [ "$src" = "local" ]
}

@test "data_source returns none for nonexistent project" {
  unset AZURE_DEVOPS_ORG_URL 2>/dev/null || true
  local src; src=$(data_source "nonexistent-project-xyz")
  [ "$src" = "none" ]
}
