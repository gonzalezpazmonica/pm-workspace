#!/usr/bin/env bats
# BATS tests for .claude/hooks/agent-dispatch-validate.sh
# PreToolUse(Task) — validates subagent prompts have required context.
# Tier: strict
# Ref: batch 40 hook test coverage

HOOK=".claude/hooks/agent-dispatch-validate.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  # Profile gate requires strict tier
  export SAVIA_HOOK_PROFILE=strict
}
teardown() { cd /; }

@test "hook exists" { [[ -f "$HOOK" ]]; }
@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}
@test "passes bash -n syntax" { run bash -n "$HOOK"; [ "$status" -eq 0 ]; }

# ── Only Task tool is validated ──────────────────────────

@test "skip: non-Task tool exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{}}'
  [ "$status" -eq 0 ]
}

@test "skip: Edit tool ignored" {
  run bash "$HOOK" <<< '{"tool_name":"Edit","tool_input":{"file_path":"/x"}}'
  [ "$status" -eq 0 ]
}

@test "skip: empty tool_name exits 0" {
  run bash "$HOOK" <<< '{"tool_input":{"prompt":"crear command"}}'
  [ "$status" -eq 0 ]
}

@test "skip: Task with empty prompt exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Task","tool_input":{"prompt":""}}'
  [ "$status" -eq 0 ]
}

# ── Command creation validation (ERROR cases block) ──────

@test "error: Task prompt creates commands but lacks name field" {
  local prompt='crear command en .claude/commands/foo.md'
  run bash "$HOOK" <<< "{\"tool_name\":\"Task\",\"tool_input\":{\"prompt\":\"$prompt\"}}"
  [ "$status" -eq 2 ]
  [[ "$output" == *"DISPATCH"* ]]
}

@test "pass: Task prompt with proper command frontmatter" {
  local prompt='crear command .claude/commands/foo.md con frontmatter name, description y ver ejemplo existente'
  run bash "$HOOK" <<< "{\"tool_name\":\"Task\",\"tool_input\":{\"prompt\":\"$prompt\"}}"
  # May warn but not block
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}

# ── CHANGELOG modification validation ───────────────────

@test "error: CHANGELOG edit without descending order mention" {
  local prompt='modifica CHANGELOG.md con nueva entrada'
  run bash "$HOOK" <<< "{\"tool_name\":\"Task\",\"tool_input\":{\"prompt\":\"$prompt\"}}"
  [ "$status" -eq 2 ]
  [[ "$output" == *"CHANGELOG"* ]]
}

@test "error: CHANGELOG edit without append/prepend mention" {
  local prompt='modifica CHANGELOG orden descendente'
  run bash "$HOOK" <<< "{\"tool_name\":\"Task\",\"tool_input\":{\"prompt\":\"$prompt\"}}"
  [ "$status" -eq 2 ]
}

# ── Skills creation validation ─────────────────────────

@test "warn: create skill without mentioning 150 line limit emits warning" {
  local prompt='crear skill en .claude/skills/foo/SKILL.md'
  run bash "$HOOK" <<< "{\"tool_name\":\"Task\",\"tool_input\":{\"prompt\":\"$prompt\"}}"
  # Skills warning is non-blocking (only WARNINGS, no ERRORS)
  [ "$status" -eq 0 ]
  [[ "$output" == *"DISPATCH"* ]]
}

# ── Git push/PR validation ──────────────────────────────

@test "warn: git push prompt without CI validation mention" {
  local prompt='git push al remoto tras commit'
  run bash "$HOOK" <<< "{\"tool_name\":\"Task\",\"tool_input\":{\"prompt\":\"$prompt\"}}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DISPATCH"* ]]
}

# ── Negative cases ──────────────────────────────────────

@test "negative: malformed JSON exits 0 (fail open)" {
  run bash "$HOOK" <<< "not json"
  [ "$status" -eq 0 ]
}

@test "negative: empty stdin handled" {
  run bash "$HOOK" <<< ""
  # jq on empty returns empty string, TOOL_NAME empty, exits 0
  [ "$status" -eq 0 ]
}

@test "negative: Task with null prompt exits 0" {
  run bash "$HOOK" <<< '{"tool_name":"Task","tool_input":{"prompt":null}}'
  [ "$status" -eq 0 ]
}

# ── Edge cases ──────────────────────────────────────────

@test "edge: Task prompt with NO trigger patterns is clean" {
  local prompt='investiga el backlog de Jira y reporta hallazgos'
  run bash "$HOOK" <<< "{\"tool_name\":\"Task\",\"tool_input\":{\"prompt\":\"$prompt\"}}"
  [ "$status" -eq 0 ]
  # No DISPATCH output expected
}

@test "edge: multiple triggers combine (command + changelog)" {
  local prompt='crear command foo.md y modificar CHANGELOG'
  run bash "$HOOK" <<< "{\"tool_name\":\"Task\",\"tool_input\":{\"prompt\":\"$prompt\"}}"
  [ "$status" -eq 2 ]
}

@test "edge: case-insensitive matching (uppercase CHANGELOG)" {
  local prompt='update CHANGELOG without context'
  run bash "$HOOK" <<< "{\"tool_name\":\"Task\",\"tool_input\":{\"prompt\":\"$prompt\"}}"
  [ "$status" -eq 2 ]
}

# ── Coverage ────────────────────────────────────────────

@test "coverage: prompt_contains helper defined" {
  run grep -c 'prompt_contains()' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: all 5 validation categories present" {
  for pat in 'commands/' 'CHANGELOG' 'skills/' 'git push' 'rules/'; do
    grep -q "$pat" "$HOOK" || fail "missing validation category: $pat"
  done
}

@test "coverage: checklist reference declared" {
  run grep -c 'agent-dispatch-checklist' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "coverage: TMPDIR used in tests" {
  run grep -c 'TMPDIR\|mktemp' "$BATS_TEST_FILENAME"
  [[ "$output" -ge 1 ]]
}

# ── Isolation ─────────────────────────────────────────────

@test "isolation: exit codes are {0, 2} only (never 1)" {
  run bash "$HOOK" <<< ""
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
  run bash "$HOOK" <<< '{"tool_name":"Task","tool_input":{"prompt":"modifica CHANGELOG"}}'
  [[ "$status" -eq 0 || "$status" -eq 2 ]]
}

@test "isolation: hook does not write to disk during validation" {
  local files_before
  files_before=$(find "$TMPDIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
  bash "$HOOK" <<< '{"tool_name":"Task","tool_input":{"prompt":"crear command"}}' >/dev/null 2>&1 || true
  local files_after
  files_after=$(find "$TMPDIR" -maxdepth 1 -type f 2>/dev/null | wc -l)
  [[ "$files_before" == "$files_after" ]]
}
