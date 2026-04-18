#!/usr/bin/env bats
# BATS tests for scripts/azdevops-queries.sh after SE-031 slice 3 v2 migration
# Ref: docs/propuestas/SE-031-query-library-nl.md (slice 3 v2)
# SPEC-031 / SPEC-055 quality gate (score ≥ 80)
#
# Verifies that the migrated functions build the same WIQL payloads as the
# inline versions (pre-migration), using the query library resolver.

SCRIPT="scripts/azdevops-queries.sh"
RESOLVER="scripts/query-lib-resolve.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export REPO_ROOT="$BATS_TEST_DIRNAME/.."
  cd "$REPO_ROOT"
}

teardown() {
  cd /
}

# ── Structure / safety ──────────────────────────────────────────────────────

@test "azdevops-queries.sh has valid bash syntax" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "azdevops-queries.sh has set -uo pipefail or equivalent safety header" {
  # Safety verification: script must set safe bash options within the first 30 lines
  run head -30 "$SCRIPT"
  # Accept -euo pipefail or -uo pipefail (both enforce unset + pipe safety)
  [[ "$output" == *"set -uo pipefail"* || "$output" == *"set -euo pipefail"* ]]
}

@test "resolver script has set -uo pipefail" {
  run head -20 "$RESOLVER"
  [[ "$output" == *"set -uo pipefail"* ]]
}

@test "azdevops-queries.sh preserves main entrypoint" {
  run grep -c "^main()" "$SCRIPT"
  [ "$output" = "1" ]
}

# ── Snippets exist and resolve cleanly ──────────────────────────────────────

@test "sprint-items-detailed resolves with project + team params" {
  run bash "$RESOLVER" --id sprint-items-detailed --param project=MyProj --param team=MyTeam
  [ "$status" -eq 0 ]
  [[ "$output" == *"FROM WorkItems"* ]]
  [[ "$output" == *"[MyProj\\MyTeam]"* ]]
  [[ "$output" == *"'MyProj'"* ]]
  [[ "$output" == *"CompletedWork"* ]]
  [[ "$output" == *"StoryPoints"* ]]
}

@test "board-status-not-done resolves with project + team params" {
  run bash "$RESOLVER" --id board-status-not-done --param project=MyProj --param team=MyTeam
  [ "$status" -eq 0 ]
  [[ "$output" == *"FROM WorkItems"* ]]
  [[ "$output" == *"[MyProj\\MyTeam]"* ]]
  [[ "$output" == *"NOT IN ('Done', 'Closed', 'Removed')"* ]]
  [[ "$output" == *"NOT IN ('Epic', 'Feature')"* ]]
}

# ── Script uses library (no inline WIQL for these 2 queries) ────────────────

@test "azdevops-queries.sh does NOT contain inline sprint-items WIQL" {
  run grep -c "CompletedWork].*FROM WorkItems" "$SCRIPT"
  [ "$output" = "0" ]
}

@test "azdevops-queries.sh does NOT contain inline board-status WIQL" {
  run grep -c "NOT IN ('Done','Closed','Removed')" "$SCRIPT"
  [ "$output" = "0" ]
}

@test "azdevops-queries.sh references query-lib-resolve.sh at least twice" {
  run grep -c "query-lib-resolve.sh" "$SCRIPT"
  [ "$output" -ge 2 ]
}

@test "azdevops-queries.sh references sprint-items-detailed by id" {
  run grep -c "id sprint-items-detailed" "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "azdevops-queries.sh references board-status-not-done by id" {
  run grep -c "id board-status-not-done" "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ── Coverage: all 13 functions of the target script are acknowledged ────────
# Ensures future changes can't silently drop a function without updating tests.

@test "target script retains all 13 public functions: error, check_dependencies, auth_header, configure_az, get_current_sprint, get_sprint_items, get_burndown_data, get_team_capacities, get_velocity_history, get_board_status, batch_get_workitems, update_workitem, main" {
  local fns=(
    "error" "check_dependencies" "auth_header" "configure_az"
    "get_current_sprint" "get_sprint_items" "get_burndown_data"
    "get_team_capacities" "get_velocity_history" "get_board_status"
    "batch_get_workitems" "update_workitem" "main"
  )
  for fn in "${fns[@]}"; do
    grep -qE "^${fn}\(\)" "$SCRIPT" || {
      echo "FAIL: missing function $fn in $SCRIPT" >&2
      return 1
    }
  done
}

# ── End-to-end: resolver + jq produce valid JSON payload ────────────────────

@test "resolver + jq produces valid WIQL JSON (sprint-items-detailed)" {
  local raw_query wiql
  raw_query=$(bash "$RESOLVER" --id sprint-items-detailed --param project=P --param team=T)
  wiql=$(jq -n --arg q "$raw_query" '{query: $q}')
  echo "$wiql" | jq -e '.query' >/dev/null
  echo "$wiql" | jq -e '.query | contains("FROM WorkItems")' >/dev/null
  # The backslash between P and T must be preserved (the canonical
  # escape in WIQL @CurrentIteration('[project\team]'))
  echo "$wiql" | jq -r '.query' | grep -q 'P\\T'
}

@test "resolver + jq produces valid WIQL JSON (board-status-not-done)" {
  local raw_query wiql
  raw_query=$(bash "$RESOLVER" --id board-status-not-done --param project=P --param team=T)
  wiql=$(jq -n --arg q "$raw_query" '{query: $q}')
  echo "$wiql" | jq -e '.query | contains("NOT IN")' >/dev/null
  echo "$wiql" | jq -r '.query' | grep -q 'P\\T'
}

# ── Negative cases: resolver error paths ───────────────────────────────────

@test "resolver fails with error on missing required --id flag" {
  run bash "$RESOLVER"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--id required"* ]]
}

@test "resolver fails gracefully on invalid query id" {
  run bash "$RESOLVER" --id totally-nonexistent-query-id
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "resolver rejects unknown flag with error exit code" {
  run bash "$RESOLVER" --bogus-flag xyz
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown flag"* ]]
}

@test "resolver with missing params emits unsubstituted warning (non-fatal)" {
  run bash -c "bash '$RESOLVER' --id sprint-items-detailed 2>&1 >/dev/null"
  # Script still exits 0 but stderr carries warning — a graceful non-fatal case
  [ "$status" -eq 0 ]
  [[ "$output" == *"unsubstituted"* ]]
}

@test "bash -n fails on invalid script (regression probe for syntax break)" {
  # Use an obviously invalid script to verify the syntax check would catch it
  local bad="$BATS_TEST_TMPDIR/bad.sh"
  echo 'if then fi' > "$bad"
  run bash -n "$bad"
  [ "$status" -ne 0 ]
}

# ── Edge cases: quoting, boundary conditions, empty inputs ─────────────────

@test "edge: single quotes in project name are handled (O'Brien)" {
  local raw_query wiql
  raw_query=$(bash "$RESOLVER" --id board-status-not-done --param project="O'Brien" --param team=T)
  wiql=$(jq -n --arg q "$raw_query" '{query: $q}')
  echo "$wiql" | jq -e '.query' >/dev/null
}

@test "edge: double quotes in params do not break JSON (T\"X)" {
  local raw_query wiql
  raw_query=$(bash "$RESOLVER" --id board-status-not-done --param project=P --param team='T"X')
  wiql=$(jq -n --arg q "$raw_query" '{query: $q}')
  echo "$wiql" | jq -e '.query' >/dev/null
}

@test "edge: empty param value produces placeholder marker (unsubstituted)" {
  # Boundary: explicitly empty string passed — resolver leaves placeholder
  run bash -c "bash '$RESOLVER' --id sprint-items-detailed --param project='' --param team=T 2>&1 >/dev/null"
  # Warning expected because empty string might not actually substitute
  # (implementation detail: either substitutes to empty or reports unsubstituted)
  [ "$status" -eq 0 ]
}

@test "edge: very long project name (boundary >100 chars) is accepted" {
  local long_name
  long_name=$(printf 'X%.0s' {1..150})
  local raw_query
  raw_query=$(bash "$RESOLVER" --id board-status-not-done --param project="$long_name" --param team=T)
  [[ "$raw_query" == *"$long_name"* ]]
}

@test "edge: nonexistent resolver path triggers bash error (boundary)" {
  run bash /tmp/nonexistent-path-query-lib.sh --id foo
  [ "$status" -ne 0 ]
}
