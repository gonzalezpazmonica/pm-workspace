#!/usr/bin/env bats
# test-se253-agent-sync.bats — SE-253 Slice 3: Agent sync guard
# AC-3.1: --check exits 0 in <5s with clean state
# AC-3.2: drift causes exit 1 naming the file
# AC-3.3: CI job exists
# AC-3.4: all single-side agents are in allowlist

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
SYNC_SCRIPT="$REPO_ROOT/scripts/agents-catalog-sync.sh"
ALLOWLIST="$REPO_ROOT/docs/agents-sync-allowlist.md"
CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

@test "AC-3.1: agents-catalog-sync.sh --check exists and is executable" {
  [ -f "$SYNC_SCRIPT" ]
  [ -x "$SYNC_SCRIPT" ]
}

@test "AC-3.1: --check with clean repo state exits 0" {
  run bash "$SYNC_SCRIPT" --check
  [ "$status" -eq 0 ]
}

@test "AC-3.1: --check completes in under 5 seconds" {
  start=$(date +%s%N 2>/dev/null || date +%s)
  run bash "$SYNC_SCRIPT" --check
  end=$(date +%s%N 2>/dev/null || date +%s)
  # Accept nanoseconds or seconds
  if [[ ${#start} -gt 10 ]]; then
    elapsed_ms=$(( (end - start) / 1000000 ))
    [ "$elapsed_ms" -lt 5000 ]
  else
    elapsed=$(( end - start ))
    [ "$elapsed" -lt 5 ]
  fi
}

@test "AC-3.1: --check reports PASS or VERDICT: PASS on clean state" {
  run bash "$SYNC_SCRIPT" --check
  [[ "$output" =~ PASS ]]
}

@test "AC-3.3: ci.yml exists" {
  [ -f "$CI_WORKFLOW" ]
}

@test "AC-3.3: ci.yml contains agents-catalog-sync --check reference" {
  grep -q "agents-catalog-sync" "$CI_WORKFLOW" || grep -q "agent.sync" "$CI_WORKFLOW"
}

@test "AC-3.4: allowlist file exists" {
  [ -f "$ALLOWLIST" ]
}

@test "AC-3.4: allowlist contains archive-digest (known single-side agent)" {
  grep -q "archive-digest" "$ALLOWLIST"
}

@test "AC-3.4: allowlist contains authority-claim-judge (known single-side agent)" {
  grep -q "authority-claim-judge" "$ALLOWLIST"
}

@test "AC-3.4: allowlist contains code-twin-agent (known single-side agent)" {
  grep -q "code-twin-agent" "$ALLOWLIST"
}

@test "AC-3.4: allowlist contains configurator (known single-side agent)" {
  grep -q "configurator" "$ALLOWLIST"
}

@test "AC-3.4: allowlist contains criterion-simulation-judge (known single-side agent)" {
  grep -q "criterion-simulation-judge" "$ALLOWLIST"
}

@test "AC-3.4: allowlist contains fiction-framing-judge (known single-side agent)" {
  grep -q "fiction-framing-judge" "$ALLOWLIST"
}

@test "AC-3.4: allowlist contains structural-framing-judge (known single-side agent)" {
  grep -q "structural-framing-judge" "$ALLOWLIST"
}

@test "AC-3.4: allowlist has a table header with required columns" {
  grep -q "| Agente" "$ALLOWLIST" || grep -q "| Agent" "$ALLOWLIST"
}

@test "AC-3.4: allowlist documents decision-trees/ subdirectory" {
  grep -q "decision-trees" "$ALLOWLIST"
}

@test "AC-3.4: allowlist documents references/ subdirectory" {
  grep -q "references/" "$ALLOWLIST" || grep -q "References" "$ALLOWLIST"
}

@test "AC-3.4: both .claude/agents and .opencode/agents dirs exist" {
  [ -d "$REPO_ROOT/.claude/agents" ]
  [ -d "$REPO_ROOT/.opencode/agents" ]
}

@test "AC-3.4: .claude/agents has at least 70 agent files" {
  count=$(ls "$REPO_ROOT/.claude/agents/"*.md 2>/dev/null | wc -l)
  [ "$count" -ge 70 ]
}
