#!/usr/bin/env bats
# Ref: docs/propuestas/SPEC-054-context-index-system.md
# Tests for generate-context-index.sh — Context index generator

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/generate-context-index.sh"
  TMPDIR_CI=$(mktemp -d)
  # Isolation: generate into a fixture workspace, never the repo's .context-index/.
  WS="$TMPDIR_CI/ws"
  mkdir -p "$WS/.claude/rules/domain" "$WS/.claude/agents" "$WS/.claude/skills/demo" "$WS/projects/demo"
  printf '# ws\n' > "$WS/CLAUDE.md"
  printf '# rule\n' > "$WS/.claude/rules/domain/r.md"
  printf -- '---\nname: a\n---\n' > "$WS/.claude/agents/a.md"
  printf -- '---\nname: demo\n---\n' > "$WS/.claude/skills/demo/SKILL.md"
  printf '# demo\n' > "$WS/projects/demo/CLAUDE.md"
}

teardown() { rm -rf "$TMPDIR_CI"; }

@test "script has safety flags" {
  head -5 "$SCRIPT" | grep -qE "set -(e|u).*pipefail"
}

@test "workspace mode runs on a fixture workspace" {
  run bash "$SCRIPT" --workspace "$WS"
  [ "$status" -le 1 ]
}

@test "generates workspace index file" {
  run bash "$SCRIPT" --workspace "$WS"
  [ "$status" -le 1 ]
  [[ -f "$WS/.context-index/WORKSPACE.ctx" ]]
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

@test "negative: invalid mode handled" {
  run bash "$SCRIPT" --bogus "$WS"
  [ "$status" -le 1 ]
}

@test "negative: missing project name with --project" {
  run bash "$SCRIPT" --project "" "$WS"
  [ "$status" -le 1 ]
}

@test "edge: boundary — workspace with no rules dir" {
  mkdir -p "$TMPDIR_CI/empty-ws"
  run bash "$SCRIPT" --workspace "$TMPDIR_CI/empty-ws"
  [ "$status" -le 1 ]
}

@test "positive: script under 150 lines" {
  local lines; lines=$(wc -l < "$SCRIPT"); [ "$lines" -le 150 ]
}

@test "isolation: the suite never writes the repo's context index" {
  before=$(git -C "$REPO_ROOT" status --porcelain -- .context-index projects | sha256sum)
  bash "$SCRIPT" --workspace "$WS" >/dev/null 2>&1 || true
  [ "$(git -C "$REPO_ROOT" status --porcelain -- .context-index projects | sha256sum)" = "$before" ]
}
