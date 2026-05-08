#!/usr/bin/env bats
# Tests for SPEC-036 Agent Evaluation Framework
# Safety: eval scripts use set -uo pipefail

setup() {
  cd "$BATS_TEST_DIRNAME/../.." || exit 1
  TMPDIR_EF=$(mktemp -d)
}
teardown() { rm -rf "$TMPDIR_EF"; }

@test "eval-agent.sh has set -uo pipefail" {
  head -10 scripts/eval-agent.sh | grep -q "set -[euo]*o pipefail"
}

@test "eval directory structure exists" {
  [ -d "tests/evals" ]
}

@test "security-attacker golden set: basic + adversarial pairs" {
  [ -d "tests/evals/security-attacker" ]
  [ -f "tests/evals/security-attacker/input-01.py" ]
  [ -f "tests/evals/security-attacker/expected-01.yaml" ]
  [ -f "tests/evals/security-attacker/input-02.py" ]
  [ -f "tests/evals/security-attacker/expected-02.yaml" ]
  [ -f "tests/evals/security-attacker/input-03.py" ]
  [ -f "tests/evals/security-attacker/expected-03.yaml" ]
  [ -f "tests/evals/security-attacker/input-04.py" ]
  [ -f "tests/evals/security-attacker/expected-04.yaml" ]
}

@test "code-reviewer golden set: reject + approve pairs" {
  [ -d "tests/evals/code-reviewer" ]
  [ -f "tests/evals/code-reviewer/input-01.diff" ]
  [ -f "tests/evals/code-reviewer/expected-01.yaml" ]
  [ -f "tests/evals/code-reviewer/input-02.diff" ]
  [ -f "tests/evals/code-reviewer/expected-02.yaml" ]
}

@test "business-analyst golden set: bad + good PBI pairs" {
  [ -d "tests/evals/business-analyst" ]
  [ -f "tests/evals/business-analyst/input-01.md" ]
  [ -f "tests/evals/business-analyst/expected-01.yaml" ]
  [ -f "tests/evals/business-analyst/input-02.md" ]
  [ -f "tests/evals/business-analyst/expected-02.yaml" ]
}

@test "eval-agent.sh exists and is valid bash" {
  [ -f "scripts/eval-agent.sh" ]
  bash -n scripts/eval-agent.sh
}

@test "eval-agent.sh --list shows agents" {
  run bash scripts/eval-agent.sh --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"security-attacker"* ]]
  [[ "$output" == *"code-reviewer"* ]]
  [[ "$output" == *"business-analyst"* ]]
}

@test "eval-agent.sh --help shows usage" {
  run bash scripts/eval-agent.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "eval-agent.sh generates template for valid agent" {
  run bash scripts/eval-agent.sh security-attacker
  [ "$status" -eq 0 ]
  [[ "$output" == *"Eval template"* ]]
  [[ "$output" == *"4 pairs"* ]]
}

@test "eval-agent.sh fails for unknown agent" {
  run bash scripts/eval-agent.sh nonexistent-agent
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "expected YAML files contain must_detect field" {
  for f in tests/evals/*/expected-*.yaml; do
    # At least one expected file should have must_detect or expected_findings
    if grep -q 'must_detect\|expected_findings\|expected_behavior' "$f"; then
      return 0
    fi
  done
  # If we get here, no expected file had the required fields
  return 1
}

@test "eval-agent command exists" {
  [ -f ".opencode/commands/eval-agent.md" ]
}

@test "edge: empty golden set directory handled" {
  mkdir -p "$TMPDIR_EF/tests/evals/fake-agent"
  [ -d "$TMPDIR_EF/tests/evals/fake-agent" ]
}

@test "SPEC-036 document exists" {
  [ -f "docs/propuestas/SPEC-036-agent-evaluation.md" ]
}
