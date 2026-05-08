#!/usr/bin/env bats
# Tests for SPEC-054 Context Index System

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  SCRIPT="scripts/generate-context-index.sh"
  TMPDIR_IDX=$(mktemp -d)
  mkdir -p "$TMPDIR_IDX/docs/rules/domain" "$TMPDIR_IDX/docs/rules/languages" \
           "$TMPDIR_IDX/.opencode/agents" "$TMPDIR_IDX/.opencode/commands" "$TMPDIR_IDX/.opencode/hooks" \
           "$TMPDIR_IDX/.claude/agents" "$TMPDIR_IDX/.claude/skills/test-skill" \
           "$TMPDIR_IDX/.claude/commands" "$TMPDIR_IDX/.claude/hooks" \
           "$TMPDIR_IDX/docs" "$TMPDIR_IDX/scripts" "$TMPDIR_IDX/tests" "$TMPDIR_IDX/output"
  touch "$TMPDIR_IDX/docs/rules/domain/test-rule.md"
  touch "$TMPDIR_IDX/.claude/agents/test-agent.md"
  touch "$TMPDIR_IDX/.claude/commands/test-cmd.md"
  touch "$TMPDIR_IDX/.claude/hooks/test-hook.sh"
  touch "$TMPDIR_IDX/.claude/skills/test-skill/SKILL.md"
}
teardown() { rm -rf "$TMPDIR_IDX"; }

@test "script exists, executable, valid syntax, under 150 lines" {
  [ -f "$SCRIPT" ] && [ -x "$SCRIPT" ]
  bash -n "$SCRIPT"
  lines=$(wc -l < "$SCRIPT")
  [ "$lines" -le 150 ]
}

@test "script uses set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "workspace mode generates WORKSPACE.ctx with header" {
  bash "$SCRIPT" --workspace "$TMPDIR_IDX"
  [ -f "$TMPDIR_IDX/.context-index/WORKSPACE.ctx" ]
  grep -q '# Workspace Context Index' "$TMPDIR_IDX/.context-index/WORKSPACE.ctx"
  grep -q '# counts:' "$TMPDIR_IDX/.context-index/WORKSPACE.ctx"
}

@test "WORKSPACE.ctx contains accurate counts" {
  bash "$SCRIPT" --workspace "$TMPDIR_IDX"
  local idx="$TMPDIR_IDX/.context-index/WORKSPACE.ctx"
  grep -q 'counts:' "$idx"
  grep -q 'rules=1' "$idx"
  grep -q 'agents=1' "$idx"
  grep -q 'skills=1' "$idx"
  grep -q 'commands=1' "$idx"
}

@test "WORKSPACE.ctx contains required sections" {
  bash "$SCRIPT" --workspace "$TMPDIR_IDX"
  local idx="$TMPDIR_IDX/.context-index/WORKSPACE.ctx"
  grep -q '## Rules & Governance' "$idx"
  grep -q '## Agents' "$idx"
  grep -q '## Skills & Commands' "$idx"
  grep -q '## Agent Memory' "$idx"
  grep -q '## Projects' "$idx"
}

@test "WORKSPACE.ctx contains location, intent, and digest-target entries" {
  bash "$SCRIPT" --workspace "$TMPDIR_IDX"
  local idx="$TMPDIR_IDX/.context-index/WORKSPACE.ctx"
  grep -q '\[location\]' "$idx"
  grep -q '\[intent:' "$idx"
  grep -q '\[digest-target\]' "$idx"
}

@test "WORKSPACE.ctx is under 200 lines" {
  bash "$SCRIPT" --workspace "$TMPDIR_IDX"
  lines=$(wc -l < "$TMPDIR_IDX/.context-index/WORKSPACE.ctx")
  [ "$lines" -le 200 ]
}

@test "project mode generates PROJECT.ctx" {
  mkdir -p "$TMPDIR_IDX/projects/alpha"
  touch "$TMPDIR_IDX/projects/alpha/CLAUDE.md"
  bash "$SCRIPT" --project alpha "$TMPDIR_IDX"
  [ -f "$TMPDIR_IDX/projects/alpha/.context-index/PROJECT.ctx" ]
}

@test "PROJECT.ctx marks existing as location, missing as optional" {
  mkdir -p "$TMPDIR_IDX/projects/beta"
  touch "$TMPDIR_IDX/projects/beta/CLAUDE.md"
  touch "$TMPDIR_IDX/projects/beta/reglas-negocio.md"
  bash "$SCRIPT" --project beta "$TMPDIR_IDX"
  local idx="$TMPDIR_IDX/projects/beta/.context-index/PROJECT.ctx"
  grep -q '\[location\] CLAUDE.md' "$idx"
  grep -q '\[location\] reglas-negocio.md' "$idx"
  grep -q '\[optional\].*ARCHITECTURE.md' "$idx"
}

@test "PROJECT.ctx contains digest-target and intent entries" {
  mkdir -p "$TMPDIR_IDX/projects/gamma"
  touch "$TMPDIR_IDX/projects/gamma/CLAUDE.md"
  bash "$SCRIPT" --project gamma "$TMPDIR_IDX"
  local idx="$TMPDIR_IDX/projects/gamma/.context-index/PROJECT.ctx"
  grep -q '\[digest-target\]' "$idx"
  grep -q '\[intent:' "$idx"
}

@test "PROJECT.ctx is under 100 lines and contains project name" {
  mkdir -p "$TMPDIR_IDX/projects/myproj"
  touch "$TMPDIR_IDX/projects/myproj/CLAUDE.md"
  bash "$SCRIPT" --project myproj "$TMPDIR_IDX"
  local idx="$TMPDIR_IDX/projects/myproj/.context-index/PROJECT.ctx"
  lines=$(wc -l < "$idx")
  [ "$lines" -le 100 ]
  grep -q 'myproj' "$idx"
}

@test "no-args mode generates both workspace and project indices" {
  mkdir -p "$TMPDIR_IDX/projects/one" "$TMPDIR_IDX/projects/two"
  touch "$TMPDIR_IDX/projects/one/CLAUDE.md"
  touch "$TMPDIR_IDX/projects/two/CLAUDE.md"
  bash "$SCRIPT" "$TMPDIR_IDX"
  [ -f "$TMPDIR_IDX/.context-index/WORKSPACE.ctx" ]
  [ -f "$TMPDIR_IDX/projects/one/.context-index/PROJECT.ctx" ]
  [ -f "$TMPDIR_IDX/projects/two/.context-index/PROJECT.ctx" ]
}

@test "missing project name with --project flag prints error" {
  run bash "$SCRIPT" --project
  [ "$status" -ne 0 ]
}

@test "nonexistent project is skipped with error" {
  run bash "$SCRIPT" --project nonexistent "$TMPDIR_IDX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"SKIP"* ]] || [[ "$output" == *"not found"* ]]
}

@test "static template files exist in .context-index" {
  [ -f ".context-index/PROJECT-TEMPLATE.ctx" ]
  [ -f ".context-index/WORKSPACE.ctx" ]
  grep -q '{project-name}' ".context-index/PROJECT-TEMPLATE.ctx"
}

@test "all 8 digester agents reference context-index or .ctx" {
  local digesters=(
    ".opencode/agents/meeting-digest.md"
    ".opencode/agents/pdf-digest.md"
    ".opencode/agents/word-digest.md"
    ".opencode/agents/excel-digest.md"
    ".opencode/agents/pptx-digest.md"
    ".opencode/agents/visual-digest.md"
    ".opencode/agents/meeting-risk-analyst.md"
    ".opencode/agents/meeting-confidentiality-judge.md"
  )
  for agent in "${digesters[@]}"; do
    grep -qiE '(context-index|\.ctx)' "$agent" || {
      echo "FAIL: $agent does not reference context-index or .ctx"
      return 1
    }
  done
}
