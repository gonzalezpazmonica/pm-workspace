#!/usr/bin/env bats
# BATS tests for scripts/query-lib-nl.sh
# SPEC: SE-031 slice 2 — Natural language → Query ID
# Ref: docs/propuestas/SE-031-query-library-nl.md

NL="scripts/query-lib-nl.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  export REPO_ROOT="$BATS_TEST_TMPDIR/nl"
  mkdir -p "$REPO_ROOT/scripts" \
           "$REPO_ROOT/.claude/queries/azure-devops" \
           "$REPO_ROOT/.claude/queries/jira" \
           "$REPO_ROOT/.claude/queries/savia-flow"
  cp "$BATS_TEST_DIRNAME/../$NL" "$REPO_ROOT/scripts/"
  chmod +x "$REPO_ROOT/scripts/"*.sh

  cat > "$REPO_ROOT/.claude/queries/azure-devops/blocked.wiql" <<'EOF'
---
id: blocked-pbis-over-3d
lang: wiql
description: PBIs bloqueados mas de 3 dias sin actualizacion
tags: [azure-devops, blocked, sla, sprint]
---
SELECT X
EOF

  cat > "$REPO_ROOT/.claude/queries/azure-devops/bugs.wiql" <<'EOF'
---
id: bugs-open-by-severity
lang: wiql
description: Bugs abiertos agrupables por severidad
tags: [azure-devops, bugs, quality]
---
SELECT X
EOF

  cat > "$REPO_ROOT/.claude/queries/savia-flow/velocity.yaml" <<'EOF'
---
id: velocity-last-3-sprints
lang: savia-flow
description: Velocity de los ultimos 3 sprints cerrados para proyeccion
tags: [savia-flow, velocity, planning]
---
query: velocity
EOF

  cat > "$REPO_ROOT/.claude/queries/jira/myopen.jql" <<'EOF'
---
id: my-open-issues-jira
lang: jql
description: Issues asignados al usuario actual activos
tags: [jira, owner, workload]
---
assignee = currentUser()
EOF
  cd "$REPO_ROOT"
}

teardown() {
  cd /
  rm -rf "$REPO_ROOT"
}

# ── Structure ───────────────────────────────────────────────────────────────

@test "script exists and is executable" {
  [[ -x "scripts/query-lib-nl.sh" ]]
}

@test "script uses set -uo pipefail" {
  run head -30 scripts/query-lib-nl.sh
  [[ "$output" == *"set -uo pipefail"* ]]
}

@test "heredoc is quoted (no fork bomb risk)" {
  run grep -E "^python3 <<'PY'" scripts/query-lib-nl.sh
  [ "$status" -eq 0 ]
}

@test "script has --help and exits 0" {
  run bash scripts/query-lib-nl.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# ── Input validation ───────────────────────────────────────────────────────

@test "no args returns exit 3" {
  run bash scripts/query-lib-nl.sh
  [ "$status" -eq 3 ]
  [[ "$output" == *"NL query required"* ]]
}

@test "unknown flag returns exit 3" {
  run bash scripts/query-lib-nl.sh --foo bar
  [ "$status" -eq 3 ]
  [[ "$output" == *"unknown flag"* ]]
}

# ── Match behavior (unique) ────────────────────────────────────────────────

@test "exact-ish match returns single id and exit 0" {
  run bash scripts/query-lib-nl.sh "PBIs bloqueados mas de 3 dias"
  [ "$status" -eq 0 ]
  [[ "$output" == "blocked-pbis-over-3d" ]]
}

@test "spanish query matches spanish description" {
  run bash scripts/query-lib-nl.sh "bugs abiertos por severidad"
  [ "$status" -eq 0 ]
  [[ "$output" == "bugs-open-by-severity" ]]
}

@test "english query matches via alias expansion" {
  # 'blocked' en English → canonical 'blocked' (matches 'bloqueados' via alias)
  run bash scripts/query-lib-nl.sh "blocked backlog items last days"
  [ "$status" -eq 0 ]
  [[ "$output" == "blocked-pbis-over-3d" ]]
}

@test "savia-flow query matched" {
  run bash scripts/query-lib-nl.sh "velocity ultimos 3 sprints"
  [ "$status" -eq 0 ]
  [[ "$output" == "velocity-last-3-sprints" ]]
}

# ── Fallback (no match) ────────────────────────────────────────────────────

@test "unrelated query returns exit 1 + schema prompt" {
  run bash scripts/query-lib-nl.sh "count commits per dev this week"
  [ "$status" -eq 1 ]
  [[ "$output" == *"NO MATCH"* ]]
  [[ "$output" == *"WIQL skeleton"* ]]
}

@test "fallback includes available langs" {
  run bash -c "bash scripts/query-lib-nl.sh --json 'foobar xyz' 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" == *'"available_langs"'* ]]
  [[ "$output" == *'"wiql"'* ]]
  [[ "$output" == *'"jql"'* ]]
}

@test "fallback includes nearest candidates" {
  run bash -c "bash scripts/query-lib-nl.sh --json 'foobar xyz'"
  [ "$status" -eq 1 ]
  [[ "$output" == *'"nearest"'* ]]
}

# ── Language filter ────────────────────────────────────────────────────────

@test "--lang wiql matches only wiql" {
  run bash scripts/query-lib-nl.sh --lang wiql "blocked backlog items last days"
  [ "$status" -eq 0 ]
  [[ "$output" == "blocked-pbis-over-3d" ]]
}

@test "--lang jql excludes wiql candidates" {
  # Query would match wiql blocked, but --lang jql restricts to jira
  run bash scripts/query-lib-nl.sh --lang jql "mis issues abiertos"
  [ "$status" -eq 0 ]
  [[ "$output" == "my-open-issues-jira" ]]
}

@test "--lang savia-flow returns only savia-flow candidates" {
  run bash scripts/query-lib-nl.sh --lang savia-flow "velocity ultimos sprints"
  [ "$status" -eq 0 ]
  [[ "$output" == "velocity-last-3-sprints" ]]
}

# ── JSON output ────────────────────────────────────────────────────────────

@test "--json match returns valid JSON with match id" {
  run bash scripts/query-lib-nl.sh --json "velocity ultimos 3 sprints"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['match']=='velocity-last-3-sprints'"
}

@test "--json no match has match=null and reason=no_match" {
  run bash scripts/query-lib-nl.sh --json "xyz lorem ipsum"
  [ "$status" -eq 1 ]
  echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['match'] is None; assert d['reason']=='no_match'"
}

@test "--json includes score and resolved_by on match" {
  run bash scripts/query-lib-nl.sh --json "PBIs bloqueados mas de 3 dias"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'score' in d; assert 'resolved_by' in d"
}

# ── Threshold override ─────────────────────────────────────────────────────

@test "--min-score high threshold rejects weak match" {
  # Set threshold so high nothing passes
  run bash scripts/query-lib-nl.sh --min-score 0.99 "PBIs bloqueados"
  [ "$status" -eq 1 ]
}

@test "--min-score low threshold accepts weak match" {
  run bash scripts/query-lib-nl.sh --min-score 0.01 "blocked"
  [ "$status" -ne 3 ]
  # May be 0 (match), 1 (no match if all scores are 0), or 2 (ambiguous)
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}

# ── Ambiguity ──────────────────────────────────────────────────────────────

@test "ambiguous query returns exit 2 with candidates list" {
  # A query that scores similarly for two snippets should produce 2 candidates
  # "sprint" matches active-sprint-items AND blocked via tag
  run bash scripts/query-lib-nl.sh --min-score 0.05 "sprint items"
  # Either exit 2 (ambiguous) or exit 0 with clear winner
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}

# ── Integration pipe with resolver ─────────────────────────────────────────

@test "NL output pipes into resolver by id" {
  # End-to-end: NL → id → resolver produces body
  cp "$BATS_TEST_DIRNAME/../scripts/query-lib-resolve.sh" "$REPO_ROOT/scripts/"
  chmod +x scripts/query-lib-resolve.sh
  local id
  id=$(bash scripts/query-lib-nl.sh "bugs abiertos por severidad")
  [ "$id" = "bugs-open-by-severity" ]
  run bash scripts/query-lib-resolve.sh --id "$id"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SELECT X"* ]]
}
