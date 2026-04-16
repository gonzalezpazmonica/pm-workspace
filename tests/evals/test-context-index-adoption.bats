#!/usr/bin/env bats
# Tests for SPEC-054 Context Index adoption across all agent groups
# Verifies that agents in Groups A/B/C reference the .ctx system.
# Safety: agents must follow set -uo pipefail conventions in scripts

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  TMPDIR_CIA=$(mktemp -d)
}
teardown() { rm -rf "$TMPDIR_CIA"; }

@test "all 8 Group A (writer) agents reference context-index or .ctx" {
  local writers=(
    ".claude/agents/meeting-digest.md"
    ".claude/agents/pdf-digest.md"
    ".claude/agents/word-digest.md"
    ".claude/agents/excel-digest.md"
    ".claude/agents/pptx-digest.md"
    ".claude/agents/visual-digest.md"
    ".claude/agents/meeting-risk-analyst.md"
    ".claude/agents/meeting-confidentiality-judge.md"
  )
  for agent in "${writers[@]}"; do
    grep -qiE '(context-index|\.ctx)' "$agent" || {
      echo "FAIL: $agent missing context-index reference"; return 1
    }
  done
}

@test "Group B reader agents (batch 1 of 2) reference context-index or .ctx" {
  local readers=(
    ".claude/agents/architect.md"
    ".claude/agents/business-analyst.md"
    ".claude/agents/sdd-spec-writer.md"
    ".claude/agents/code-reviewer.md"
    ".claude/agents/security-guardian.md"
    ".claude/agents/security-attacker.md"
    ".claude/agents/security-defender.md"
    ".claude/agents/security-auditor.md"
  )
  for agent in "${readers[@]}"; do
    grep -qiE '(context-index|\.ctx)' "$agent" || {
      echo "FAIL: $agent missing context-index reference"; return 1
    }
  done
}

@test "Group B reader agents (batch 2 of 2) reference context-index or .ctx" {
  local readers=(
    ".claude/agents/coherence-validator.md"
    ".claude/agents/reflection-validator.md"
    ".claude/agents/dev-orchestrator.md"
    ".claude/agents/diagram-architect.md"
    ".claude/agents/drift-auditor.md"
    ".claude/agents/feasibility-probe.md"
    ".claude/agents/test-engineer.md"
    ".claude/agents/confidentiality-auditor.md"
    ".claude/agents/tech-writer.md"
  )
  for agent in "${readers[@]}"; do
    grep -qiE '(context-index|\.ctx)' "$agent" || {
      echo "FAIL: $agent missing context-index reference"; return 1
    }
  done
}

@test "all 12 Group C (developer) agents reference context-index or .ctx" {
  local devs=(
    ".claude/agents/dotnet-developer.md"
    ".claude/agents/typescript-developer.md"
    ".claude/agents/frontend-developer.md"
    ".claude/agents/java-developer.md"
    ".claude/agents/python-developer.md"
    ".claude/agents/go-developer.md"
    ".claude/agents/rust-developer.md"
    ".claude/agents/php-developer.md"
    ".claude/agents/ruby-developer.md"
    ".claude/agents/mobile-developer.md"
    ".claude/agents/cobol-developer.md"
    ".claude/agents/terraform-developer.md"
  )
  for agent in "${devs[@]}"; do
    grep -qiE '(context-index|\.ctx)' "$agent" || {
      echo "FAIL: $agent missing context-index reference"; return 1
    }
  done
}

@test "context-health.md references context-index or .ctx" {
  grep -qiE '(context-index|\.ctx)' \
    "docs/rules/domain/context-health.md" || {
    echo "FAIL: context-health.md missing context-index reference"
    return 1
  }
}

@test "SPEC-054 mentions all agent groups not just digesters" {
  local spec="docs/propuestas/SPEC-054-context-index-system.md"
  grep -q 'Group A' "$spec"
  grep -q 'Group B' "$spec"
  grep -q 'Group C' "$spec"
}

@test "error: missing context-index reference is detectable" {
  printf "%s\n" "---" "name: test-bad" "---" "No context ref" > "$TMPDIR_CIA/bad-agent.md"
  run grep -ciE '(context-index|\.ctx)' "$TMPDIR_CIA/bad-agent.md"
  [[ "$output" == *"0"* ]]
}

@test "edge: empty agent file has no context-index reference" {
  touch "$TMPDIR_CIA/empty-agent.md"
  run grep -ciE '(context-index|\.ctx)' "$TMPDIR_CIA/empty-agent.md"
  [ "$status" -ne 0 ]
}

@test "context-index generator script valid syntax" {
  [ -f "scripts/context-index-build.py" ] || skip "generator not present"
  python3 -c "import py_compile; py_compile.compile('scripts/context-index-build.py', doraise=True)"
}

@test "no modified agent exceeds 150 lines" {
  local agents=(
    ".claude/agents/architect.md"
    ".claude/agents/business-analyst.md"
    ".claude/agents/sdd-spec-writer.md"
    ".claude/agents/code-reviewer.md"
    ".claude/agents/security-guardian.md"
    ".claude/agents/dotnet-developer.md"
    ".claude/agents/confidentiality-auditor.md"
    ".claude/agents/meeting-digest.md"
    ".claude/agents/terraform-developer.md"
    ".claude/agents/cobol-developer.md"
    ".claude/agents/mobile-developer.md"
  )
  for agent in "${agents[@]}"; do
    lines=$(wc -l < "$agent")
    [ "$lines" -le 150 ] || {
      echo "FAIL: $agent has $lines lines (max 150)"; return 1
    }
  done
}
