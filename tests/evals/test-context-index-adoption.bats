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
    ".opencode/agents/meeting-digest.md"
    ".opencode/agents/pdf-digest.md"
    ".opencode/agents/word-digest.md"
    ".opencode/agents/excel-digest.md"
    ".opencode/agents/pptx-digest.md"
    ".opencode/agents/visual-digest.md"
    ".opencode/agents/meeting-risk-analyst.md"
    ".opencode/agents/meeting-confidentiality-judge.md"
  )
  for agent in "${writers[@]}"; do
    grep -qiE '(context-index|\.ctx)' "$agent" || {
      echo "FAIL: $agent missing context-index reference"; return 1
    }
  done
}

@test "Group B reader agents (batch 1 of 2) reference context-index or .ctx" {
  local readers=(
    ".opencode/agents/architect.md"
    ".opencode/agents/business-analyst.md"
    ".opencode/agents/sdd-spec-writer.md"
    ".opencode/agents/code-reviewer.md"
    ".opencode/agents/security-guardian.md"
    ".opencode/agents/security-attacker.md"
    ".opencode/agents/security-defender.md"
    ".opencode/agents/security-auditor.md"
  )
  for agent in "${readers[@]}"; do
    grep -qiE '(context-index|\.ctx)' "$agent" || {
      echo "FAIL: $agent missing context-index reference"; return 1
    }
  done
}

@test "Group B reader agents (batch 2 of 2) reference context-index or .ctx" {
  local readers=(
    ".opencode/agents/coherence-validator.md"
    ".opencode/agents/reflection-validator.md"
    ".opencode/agents/dev-orchestrator.md"
    ".opencode/agents/diagram-architect.md"
    ".opencode/agents/drift-auditor.md"
    ".opencode/agents/feasibility-probe.md"
    ".opencode/agents/test-engineer.md"
    ".opencode/agents/confidentiality-auditor.md"
    ".opencode/agents/tech-writer.md"
  )
  for agent in "${readers[@]}"; do
    grep -qiE '(context-index|\.ctx)' "$agent" || {
      echo "FAIL: $agent missing context-index reference"; return 1
    }
  done
}

@test "all 12 Group C (developer) agents reference context-index or .ctx" {
  local devs=(
    ".opencode/agents/dotnet-developer.md"
    ".opencode/agents/typescript-developer.md"
    ".opencode/agents/frontend-developer.md"
    ".opencode/agents/java-developer.md"
    ".opencode/agents/python-developer.md"
    ".opencode/agents/go-developer.md"
    ".opencode/agents/rust-developer.md"
    ".opencode/agents/php-developer.md"
    ".opencode/agents/ruby-developer.md"
    ".opencode/agents/mobile-developer.md"
    ".opencode/agents/cobol-developer.md"
    ".opencode/agents/terraform-developer.md"
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
    ".opencode/agents/architect.md"
    ".opencode/agents/business-analyst.md"
    ".opencode/agents/sdd-spec-writer.md"
    ".opencode/agents/code-reviewer.md"
    ".opencode/agents/security-guardian.md"
    ".opencode/agents/dotnet-developer.md"
    ".opencode/agents/confidentiality-auditor.md"
    ".opencode/agents/meeting-digest.md"
    ".opencode/agents/terraform-developer.md"
    ".opencode/agents/cobol-developer.md"
    ".opencode/agents/mobile-developer.md"
  )
  for agent in "${agents[@]}"; do
    lines=$(wc -l < "$agent")
    [ "$lines" -le 150 ] || {
      echo "FAIL: $agent has $lines lines (max 150)"; return 1
    }
  done
}
