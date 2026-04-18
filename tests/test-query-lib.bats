#!/usr/bin/env bats
# BATS tests for scripts/query-lib-resolve.sh and scripts/query-lib-index.sh
# SPEC: SE-031 Query Library + NL-to-WIQL/JQL
# Ref: docs/propuestas/SE-031-query-library-nl.md

RESOLVE="scripts/query-lib-resolve.sh"
INDEX="scripts/query-lib-index.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export REPO_ROOT="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO_ROOT/scripts" "$REPO_ROOT/.claude/queries/azure-devops" \
           "$REPO_ROOT/.claude/queries/jira" "$REPO_ROOT/.claude/queries/savia-flow"
  cp "$BATS_TEST_DIRNAME/../$RESOLVE" "$REPO_ROOT/scripts/"
  cp "$BATS_TEST_DIRNAME/../$INDEX"   "$REPO_ROOT/scripts/"
  chmod +x "$REPO_ROOT/scripts/"*.sh

  # Seed fixtures
  cat > "$REPO_ROOT/.claude/queries/azure-devops/blocked.wiql" <<'EOF'
---
id: blocked-test
lang: wiql
description: Blocked items for sprint
params:
  - sprint: Iteration path
returns: [id, title]
tags: [azure-devops, blocked]
---
SELECT [System.Id], [System.Title]
FROM WorkItems
WHERE [System.IterationPath] UNDER '{{sprint}}'
  AND [System.State] = 'Blocked'
EOF

  cat > "$REPO_ROOT/.claude/queries/jira/myopen.jql" <<'EOF'
---
id: myopen-jira
lang: jql
description: My open jira issues
tags: [jira, owner]
---
assignee = currentUser() AND resolution = Unresolved
EOF

  cat > "$REPO_ROOT/.claude/queries/savia-flow/velocity.yaml" <<'EOF'
---
id: velocity-test
lang: savia-flow
description: Velocity last sprints
tags: [savia-flow, velocity]
---
query:
  type: velocity
  last: 3
EOF
  cd "$REPO_ROOT"
}

teardown() {
  cd /
  rm -rf "$REPO_ROOT"
}

# ── Structure and safety ────────────────────────────────────────────────────

@test "resolve script exists and is executable" {
  [[ -x "scripts/query-lib-resolve.sh" ]]
}

@test "index script exists and is executable" {
  [[ -x "scripts/query-lib-index.sh" ]]
}

@test "resolve script uses set -uo pipefail" {
  run head -20 scripts/query-lib-resolve.sh
  [[ "$output" == *"set -uo pipefail"* ]]
}

@test "index script uses set -uo pipefail" {
  run head -10 scripts/query-lib-index.sh
  [[ "$output" == *"set -uo pipefail"* ]]
}

@test "index script heredoc is quoted (no fork bomb)" {
  # SAFETY: backticks inside python heredoc MUST NOT be expanded by bash
  run grep -E "^python3 <<'PY'" scripts/query-lib-index.sh
  [ "$status" -eq 0 ]
}

# ── Resolve: basic ──────────────────────────────────────────────────────────

@test "resolve --help returns 0" {
  run bash scripts/query-lib-resolve.sh --help
  [ "$status" -eq 0 ]
}

@test "resolve without args errors cleanly" {
  run bash scripts/query-lib-resolve.sh
  [ "$status" -eq 2 ]
  [[ "$output" == *"--id required"* ]]
}

@test "resolve unknown flag returns exit 2" {
  run bash scripts/query-lib-resolve.sh --foo bar
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown flag"* ]]
}

@test "resolve unknown id returns exit 1" {
  run bash scripts/query-lib-resolve.sh --id does-not-exist
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "resolve by id returns WIQL body" {
  run bash scripts/query-lib-resolve.sh --id blocked-test
  [ "$status" -eq 0 ]
  [[ "$output" == *"SELECT"* ]]
  [[ "$output" == *"FROM WorkItems"* ]]
}

@test "resolve strips frontmatter" {
  run bash scripts/query-lib-resolve.sh --id blocked-test
  [ "$status" -eq 0 ]
  [[ "$output" != *"---"* ]]
  [[ "$output" != *"description:"* ]]
  [[ "$output" != *"tags:"* ]]
}

@test "resolve jql id returns jql body" {
  run bash scripts/query-lib-resolve.sh --id myopen-jira
  [ "$status" -eq 0 ]
  [[ "$output" == *"assignee = currentUser()"* ]]
}

@test "resolve savia-flow yaml id returns yaml body" {
  run bash scripts/query-lib-resolve.sh --id velocity-test
  [ "$status" -eq 0 ]
  [[ "$output" == *"type: velocity"* ]]
}

# ── Resolve: param substitution ─────────────────────────────────────────────

@test "resolve substitutes single param" {
  run bash scripts/query-lib-resolve.sh --id blocked-test --param sprint=SprintA
  [ "$status" -eq 0 ]
  [[ "$output" == *"UNDER 'SprintA'"* ]]
  [[ "$output" != *"{{sprint}}"* ]]
}

@test "resolve substitutes param with spaces" {
  run bash scripts/query-lib-resolve.sh --id blocked-test --param sprint="Project\\Sprint 2026-04"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Sprint 2026-04"* ]]
}

@test "resolve warns on unsubstituted placeholders to stderr" {
  run bash -c "bash scripts/query-lib-resolve.sh --id blocked-test 2>&1 >/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unsubstituted"* ]]
}

@test "resolve with all params: no warning on stderr" {
  run bash -c "bash scripts/query-lib-resolve.sh --id blocked-test --param sprint=X 2>&1 >/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" != *"unsubstituted"* ]]
}

# ── Resolve: list mode ─────────────────────────────────────────────────────

@test "list returns table header" {
  run bash scripts/query-lib-resolve.sh --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"ID"* ]]
  [[ "$output" == *"LANG"* ]]
  [[ "$output" == *"DESCRIPTION"* ]]
}

@test "list shows all 3 seeded queries" {
  run bash scripts/query-lib-resolve.sh --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"blocked-test"* ]]
  [[ "$output" == *"myopen-jira"* ]]
  [[ "$output" == *"velocity-test"* ]]
}

@test "list --lang wiql shows only wiql" {
  run bash scripts/query-lib-resolve.sh --list --lang wiql
  [ "$status" -eq 0 ]
  [[ "$output" == *"blocked-test"* ]]
  [[ "$output" != *"myopen-jira"* ]]
  [[ "$output" != *"velocity-test"* ]]
}

@test "list --lang jql shows only jql" {
  run bash scripts/query-lib-resolve.sh --list --lang jql
  [ "$status" -eq 0 ]
  [[ "$output" == *"myopen-jira"* ]]
  [[ "$output" != *"blocked-test"* ]]
}

@test "list --json returns valid JSON" {
  run bash scripts/query-lib-resolve.sh --list --json
  [ "$status" -eq 0 ]
  [[ "$output" == \[* ]]
  [[ "$output" == *\] ]]
  echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)"
}

@test "list --json contains all entries" {
  run bash -c "bash scripts/query-lib-resolve.sh --list --json | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))'"
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

# ── Index generator ─────────────────────────────────────────────────────────

@test "index generates INDEX.md" {
  run bash scripts/query-lib-index.sh
  [ "$status" -eq 0 ]
  [[ -f .claude/queries/INDEX.md ]]
}

@test "index lists all seeded queries" {
  bash scripts/query-lib-index.sh
  run cat .claude/queries/INDEX.md
  [[ "$output" == *"blocked-test"* ]]
  [[ "$output" == *"myopen-jira"* ]]
  [[ "$output" == *"velocity-test"* ]]
}

@test "index --check passes when up-to-date" {
  bash scripts/query-lib-index.sh
  run bash scripts/query-lib-index.sh --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "index --check fails when stale" {
  bash scripts/query-lib-index.sh
  # Add a new snippet to make INDEX stale
  cat > .claude/queries/azure-devops/new.wiql <<'EOF'
---
id: new-test
lang: wiql
description: New query
tags: [azure-devops]
---
SELECT 1
EOF
  run bash scripts/query-lib-index.sh --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"stale"* ]]
}

@test "index contains counts and ID column" {
  bash scripts/query-lib-index.sh
  run cat .claude/queries/INDEX.md
  [[ "$output" == *"3 queries"* ]]
  [[ "$output" == *"| ID |"* ]]
}

@test "index script does NOT fork-bomb" {
  # SAFETY regression: run under timeout; if it recurses, timeout kills.
  run timeout 10 bash scripts/query-lib-index.sh
  [ "$status" -eq 0 ]
}

# ── Integration with real library (canonical fixtures) ──────────────────────

@test "canonical queries resolve without errors" {
  unset REPO_ROOT
  cd "$BATS_TEST_DIRNAME/.."
  run bash scripts/query-lib-resolve.sh --id blocked-pbis-over-3d --param sprint=X
  [ "$status" -eq 0 ]
  [[ "$output" == *"SELECT"* ]]
}

@test "canonical list returns at least 8 queries" {
  unset REPO_ROOT
  cd "$BATS_TEST_DIRNAME/.."
  run bash -c "bash scripts/query-lib-resolve.sh --list --json | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))'"
  [ "$status" -eq 0 ]
  [ "$output" -ge 8 ]
}

# ── SE-031 slice 3 — migrated commands/scripts ─────────────────────────────

@test "slice3: backlog-groom-open snippet resolves with project param" {
  unset REPO_ROOT
  cd "$BATS_TEST_DIRNAME/.."
  run bash scripts/query-lib-resolve.sh --id backlog-groom-open --param project=ProjectX
  [ "$status" -eq 0 ]
  [[ "$output" == *"FROM WorkItems"* ]]
  [[ "$output" == *"'ProjectX'"* ]]
  [[ "$output" == *"User Story"* ]]
}

@test "slice3: sprint-items-detailed has CurrentIteration placeholder" {
  unset REPO_ROOT
  cd "$BATS_TEST_DIRNAME/.."
  run bash scripts/query-lib-resolve.sh --id sprint-items-detailed --param project=P --param team=T
  [ "$status" -eq 0 ]
  [[ "$output" == *"@CurrentIteration"* ]]
  [[ "$output" == *"CompletedWork"* ]]
  [[ "$output" == *"StoryPoints"* ]]
}

@test "slice3: board-status-not-done excludes terminal states" {
  unset REPO_ROOT
  cd "$BATS_TEST_DIRNAME/.."
  run bash scripts/query-lib-resolve.sh --id board-status-not-done --param project=P --param team=T
  [ "$status" -eq 0 ]
  [[ "$output" == *"Done"* ]]
  [[ "$output" == *"NOT IN"* ]]
  [[ "$output" == *"Epic"* ]]
}

@test "slice3: backlog-groom.md references query-lib-resolve" {
  unset REPO_ROOT
  cd "$BATS_TEST_DIRNAME/.."
  run grep -c "query-lib-resolve.sh --id backlog-groom-open" .claude/commands/backlog-groom.md
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}
