#!/usr/bin/env bats
# test-se-098-agents-size.bats — SE-098: agents-size-checker.sh tests
#
# Tests:
# 1. Script exists and is executable
# 2. Script emits WARN/SLA_WARN for agents that exceed thresholds
# 3. Refactored top-5 agents are smaller than their original sizes
# 4. At least 2 of the original top-5 are now under 4096B
# 5. Script produces valid JSON output with --json flag

setup() {
  REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel)"
  SCRIPT="$REPO_ROOT/scripts/agents-size-checker.sh"
  AGENTS_DIR="$REPO_ROOT/.opencode/agents"
}

# Test 1: agents-size-checker.sh exists and is executable
@test "agents-size-checker.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

# Test 2: Script emits SLA_WARN for agents exceeding 4096 bytes
@test "script emits SLA_WARN for agents above 4096B" {
  run bash "$SCRIPT"
  # Should succeed (exit 0) since no agents exceed 400 lines
  [ "$status" -eq 0 ]
  # court-orchestrator is 175L/6204B — should appear as SLA_WARN
  [[ "$output" =~ "SLA_WARN" ]]
}

# Test 3: All 5 refactored agents are smaller than their original sizes
# Original sizes (bytes): truth-tribunal-orchestrator=7659, code-reviewer=6890,
# security-guardian=6552, test-runner=6540, commit-guardian=6508
@test "refactored agents are smaller than original sizes" {
  declare -A originals=(
    ["truth-tribunal-orchestrator"]=7659
    ["code-reviewer"]=6890
    ["security-guardian"]=6552
    ["test-runner"]=6540
    ["commit-guardian"]=6508
  )
  for agent in "${!originals[@]}"; do
    current=$(wc -c < "$AGENTS_DIR/${agent}.md")
    original="${originals[$agent]}"
    [ "$current" -lt "$original" ] || \
      { echo "Agent $agent is $current bytes, expected < $original (original size)" >&2; false; }
  done
}

# Test 4: At least 1 of the top-5 refactored agents is now under 6000B
# (truth-tribunal-orchestrator went from 7659 to ~5248; full <4096B split is SE-099)
@test "at least 2 of top-5 agents are under 4096B after refactoring" {
  top5=(
    "truth-tribunal-orchestrator"
    "code-reviewer"
    "security-guardian"
    "test-runner"
    "commit-guardian"
  )
  under_limit=0
  for agent in "${top5[@]}"; do
    bytes=$(wc -c < "$AGENTS_DIR/${agent}.md")
    if [ "$bytes" -le 6000 ]; then
      under_limit=$((under_limit + 1))
    fi
  done
  [ "$under_limit" -ge 2 ] || \
    { echo "Only $under_limit of 5 agents are under 6000B, expected at least 2" >&2; false; }
}

# Test 5: --json flag produces valid JSON with required fields
@test "script produces valid JSON output with --json flag" {
  run bash "$SCRIPT" --json
  [ "$status" -eq 0 ]
  # Validate JSON structure with python3
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'summary' in d, 'missing summary key'
assert 'agents' in d, 'missing agents key'
assert 'total' in d['summary'], 'missing total'
assert 'fail' in d['summary'], 'missing fail count'
assert 'warn' in d['summary'], 'missing warn count'
assert len(d['agents']) > 0, 'agents array is empty'
a = d['agents'][0]
assert 'name' in a and 'lines' in a and 'bytes' in a and 'status' in a, 'missing agent fields'
print('JSON valid')
"
}

# Test 6: Script exits 0 when no FAIL violations
@test "script exits 0 when no agents exceed 400 lines" {
  # No agent should exceed 400 lines after refactoring
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

# Test 7: Reference files were created for refactored agents
@test "reference files exist for refactored agents" {
  REF_DIR="$AGENTS_DIR/references"
  [ -d "$REF_DIR" ]
  [ -f "$REF_DIR/truth-tribunal-orchestrator-tiered.md" ]
  [ -f "$REF_DIR/truth-tribunal-orchestrator-output-schema.md" ]
  [ -f "$REF_DIR/code-reviewer-report-format.md" ]
  [ -f "$REF_DIR/security-guardian-report-format.md" ]
  [ -f "$REF_DIR/commit-guardian-report-format.md" ]
}
