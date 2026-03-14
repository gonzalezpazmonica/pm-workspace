#!/usr/bin/env bats
# Tests for Era 107.2 — Sync Adapters

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  ROOT="$PWD"
}

@test "adapter-interface.sh exists and is executable" {
  [ -x "$ROOT/scripts/sync-adapters/adapter-interface.sh" ]
}

@test "azure-devops-adapter.sh exists and is executable" {
  [ -x "$ROOT/scripts/sync-adapters/azure-devops-adapter.sh" ]
}

@test "jira-adapter.sh exists and is executable" {
  [ -x "$ROOT/scripts/sync-adapters/jira-adapter.sh" ]
}

@test "github-issues-adapter.sh exists and is executable" {
  [ -x "$ROOT/scripts/sync-adapters/github-issues-adapter.sh" ]
}

@test "backlog-sync command exists" {
  [ -f "$ROOT/.claude/commands/backlog-sync.md" ]
}

@test "adapter-interface has required functions" {
  source "$ROOT/scripts/sync-adapters/adapter-interface.sh"
  declare -f sync_log > /dev/null
  declare -f get_pbi_field > /dev/null
  declare -f set_pbi_field > /dev/null
  declare -f compute_sync_status > /dev/null
  declare -f map_state_to_provider > /dev/null
  declare -f map_state_from_provider > /dev/null
}

@test "state mapping azure-devops round-trips correctly" {
  source "$ROOT/scripts/sync-adapters/adapter-interface.sh"
  local mapped; mapped=$(map_state_to_provider "Active" "azure-devops")
  [ "$mapped" = "Active" ]
  local back; back=$(map_state_from_provider "$mapped" "azure-devops")
  [ "$back" = "Active" ]
}

@test "state mapping jira converts correctly" {
  source "$ROOT/scripts/sync-adapters/adapter-interface.sh"
  local mapped; mapped=$(map_state_to_provider "Active" "jira")
  [ "$mapped" = "In Progress" ]
  local back; back=$(map_state_from_provider "In Progress" "jira")
  [ "$back" = "Active" ]
}

@test "state mapping github converts correctly" {
  source "$ROOT/scripts/sync-adapters/adapter-interface.sh"
  local mapped; mapped=$(map_state_to_provider "Active" "github")
  [ "$mapped" = "open" ]
  local back; back=$(map_state_from_provider "closed" "github")
  [ "$back" = "Closed" ]
}

@test "compute_sync_status returns in_sync for same hashes" {
  source "$ROOT/scripts/sync-adapters/adapter-interface.sh"
  local status; status=$(compute_sync_status "2026-03-14" "2026-03-14" "abc123" "abc123")
  [ "$status" = "in_sync" ]
}

@test "compute_sync_status returns local_only for empty remote" {
  source "$ROOT/scripts/sync-adapters/adapter-interface.sh"
  local status; status=$(compute_sync_status "2026-03-14" "" "abc" "def")
  [ "$status" = "local_only" ]
}
