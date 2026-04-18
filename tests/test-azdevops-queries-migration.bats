#!/usr/bin/env bats
# BATS tests for scripts/azdevops-queries.sh after SE-031 slice 3 v2 migration
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
  # The exact old inline pattern should be gone (migrated to resolver).
  run grep -c "CompletedWork].*FROM WorkItems" "$SCRIPT"
  # 0 matches: old inline WIQL removed
  [ "$output" = "0" ]
}

@test "azdevops-queries.sh does NOT contain inline board-status WIQL" {
  run grep -c "NOT IN ('Done','Closed','Removed')" "$SCRIPT"
  [ "$output" = "0" ]
}

@test "azdevops-queries.sh references query-lib-resolve.sh" {
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

# ── End-to-end: resolver + jq produce valid JSON payload ────────────────────

@test "resolver + jq produces valid WIQL JSON (sprint-items-detailed)" {
  local raw_query wiql
  raw_query=$(bash "$RESOLVER" --id sprint-items-detailed --param project=P --param team=T)
  wiql=$(jq -n --arg q "$raw_query" '{query: $q}')
  # Must be valid JSON
  echo "$wiql" | jq -e '.query' >/dev/null
  # The query field must contain the resolved WIQL text
  echo "$wiql" | jq -e '.query | contains("FROM WorkItems")' >/dev/null
  # And the backslash between P and T must be preserved (the canonical
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

# ── Regression: quoting edge cases ─────────────────────────────────────────

@test "jq -n --arg q pattern handles single quotes in project name" {
  local raw_query wiql
  raw_query=$(bash "$RESOLVER" --id board-status-not-done --param project="O'Brien" --param team=T)
  wiql=$(jq -n --arg q "$raw_query" '{query: $q}')
  echo "$wiql" | jq -e '.query' >/dev/null
}

@test "jq -n --arg q pattern handles double quotes in params" {
  # Unusual but possible — validate no JSON breakage
  local raw_query wiql
  raw_query=$(bash "$RESOLVER" --id board-status-not-done --param project=P --param team='T"X')
  wiql=$(jq -n --arg q "$raw_query" '{query: $q}')
  echo "$wiql" | jq -e '.query' >/dev/null
}

# ── Bash syntax check ──────────────────────────────────────────────────────

@test "azdevops-queries.sh has valid bash syntax" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "azdevops-queries.sh preserves main entrypoint" {
  run grep -c "^main()" "$SCRIPT"
  [ "$output" = "1" ]
}
