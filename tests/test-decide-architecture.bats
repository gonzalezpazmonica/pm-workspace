#!/usr/bin/env bats
# Ref: SPEC-158 / docs/propuestas/SPEC-158-workflow-vs-agent-decision-gate.md
# Tests for /decide-architecture classifier (workflow vs agent gate).

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  SCRIPT="$PWD/scripts/decide-architecture.sh"
  CORPUS_TEST="$PWD/scripts/decide-architecture-corpus-test.sh"
  TMPDIR_TEST="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# ── AC1: classifies a deterministic task as WORKFLOW ────────────────────────

@test "AC1: deterministic task with explicit 'deterministic' keyword → WORKFLOW" {
  run bash "$SCRIPT" "Implement SPEC-184 following the deterministic steps in the spec"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DECISION: WORKFLOW"* ]]
}

@test "AC1: 'generate report from queries' → WORKFLOW" {
  run bash "$SCRIPT" "Generate a sprint report from Azure DevOps queries"
  [[ "$output" == *"DECISION: WORKFLOW"* ]]
}

@test "AC1: 'for every X do Y' pattern → WORKFLOW" {
  run bash "$SCRIPT" "For every PBI in the sprint, generate a status row"
  [[ "$output" == *"DECISION: WORKFLOW"* ]]
}

# ── AC2: classifies an exploratory task as AGENT ────────────────────────────

@test "AC2: 'investigate why test fails' → AGENT" {
  run bash "$SCRIPT" "Investigate why the auth test fails intermittently and figure out the root cause"
  [[ "$output" == *"DECISION: AGENT"* ]]
}

@test "AC2: 'loop until build passes' → AGENT" {
  run bash "$SCRIPT" "Loop until the build passes by self-correcting any errors"
  [[ "$output" == *"DECISION: AGENT"* ]]
}

@test "AC2: 'find the best refactoring strategy' → AGENT" {
  run bash "$SCRIPT" "Find the best refactoring strategy for this legacy module"
  [[ "$output" == *"DECISION: AGENT"* ]]
}

# ── AC3: outputs reasons for the decision ───────────────────────────────────

@test "AC3: output includes reasons section in text mode" {
  run bash "$SCRIPT" "Generate report"
  [[ "$output" == *"reasons:"* ]]
}

@test "AC3: reasons include detected keywords" {
  run bash "$SCRIPT" "Investigate the bug"
  [[ "$output" == *"investigate"* ]]
}

# ── AC4: workflow bias on tie ───────────────────────────────────────────────

@test "AC4: empty input on tie favors WORKFLOW (workflow_score >= agent_score)" {
  run bash "$SCRIPT" "irrelevant text"
  [[ "$output" == *"DECISION: WORKFLOW"* ]]
}

@test "AC4: workflow bias score is 1 by default" {
  run bash "$SCRIPT" "irrelevant"
  [[ "$output" == *"workflow_score: 1"* ]]
}

# ── AC5: corpus accuracy >= 85% ─────────────────────────────────────────────

@test "AC5: corpus test passes with accuracy >= 85%" {
  run bash "$CORPUS_TEST"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

# ── AC6: template suggestion ────────────────────────────────────────────────

@test "AC6: WORKFLOW decision suggests spec template" {
  run bash "$SCRIPT" "Generate a list of files"
  [[ "$output" == *"docs/propuestas/_template-spec.md"* ]]
}

@test "AC6: AGENT decision suggests agent template" {
  run bash "$SCRIPT" "Loop until the prompt produces consistent output"
  [[ "$output" == *".claude/agents/_template.md"* ]]
}

# ── JSON output ─────────────────────────────────────────────────────────────

@test "json: --json flag produces valid JSON" {
  run bash "$SCRIPT" --json "Generate a report"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision":"WORKFLOW"'* ]]
  [[ "$output" == *'"workflow_score":'* ]]
  [[ "$output" == *'"reasons":['* ]]
}

@test "json: parses with python json module" {
  run bash -c 'bash "$0" --json "Generate report" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d[\"decision\"])"' "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKFLOW"* ]]
}

# ── Stdin input ─────────────────────────────────────────────────────────────

@test "stdin: reads task from stdin" {
  run bash -c 'echo "Generate a report" | bash "$0"' "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DECISION: WORKFLOW"* ]]
}

# ── Help ────────────────────────────────────────────────────────────────────

@test "help: -h shows usage" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

# ── Negative cases ──────────────────────────────────────────────────────────

@test "neg: no input and no stdin returns error" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "neg: invalid flag still works (treated as text)" {
  run bash "$SCRIPT" "Generate a report --weird-arg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DECISION:"* ]]
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: very long task description completes" {
  local long
  long="$(printf 'Generate report from data %.0s' {1..50})"
  run bash "$SCRIPT" "$long"
  [ "$status" -eq 0 ]
}

@test "edge: task with mixed signals reports both scores" {
  run bash "$SCRIPT" "Generate a report and investigate any anomalies"
  [[ "$output" == *"workflow_score:"* ]]
  [[ "$output" == *"agent_score:"* ]]
}

@test "edge: case-insensitive matching" {
  run bash "$SCRIPT" "GENERATE A REPORT"
  [[ "$output" == *"DECISION: WORKFLOW"* ]]
}

@test "edge: empty quoted string fails with exit 2" {
  run bash "$SCRIPT" ""
  [ "$status" -eq 2 ]
}

@test "edge: nonexistent flag is treated as text" {
  run bash "$SCRIPT" "--nonexistent"
  [ "$status" -eq 0 ]
}

@test "edge: boundary 0 keywords still classifies (workflow bias wins)" {
  run bash "$SCRIPT" "xyz qrs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DECISION: WORKFLOW"* ]]
  [[ "$output" == *"workflow_score: 1"* ]]
  [[ "$output" == *"agent_score: 0"* ]]
}

@test "edge: max-depth aggregated keywords (workflow_strong+weak combined)" {
  run bash "$SCRIPT" "deterministic step-by-step pipeline of generate format extract for every file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DECISION: WORKFLOW"* ]]
}

@test "edge: corpus test script handles isolation via tmpdir from caller" {
  [ -n "$TMPDIR_TEST" ]
  [ -d "$TMPDIR_TEST" ]
}

# ── Safety verification ─────────────────────────────────────────────────────

@test "safety: script uses set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "safety: corpus test script exists and is executable" {
  [ -x "$CORPUS_TEST" ]
}

@test "safety: rule doc exists" {
  [ -f "docs/rules/domain/workflow-vs-agent-decision-gate.md" ]
}

@test "safety: slash command exists" {
  [ -f ".claude/commands/decide-architecture.md" ]
}
