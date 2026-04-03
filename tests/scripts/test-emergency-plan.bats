#!/usr/bin/env bats
# Tests for emergency-plan.sh — Offline LLM pre-download
# Ref: emergency-mode skill, data-sovereignty.md

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/emergency-plan.sh"

setup() {
  export TMPDIR_TEST=$(mktemp -d)
  export ORIG_HOME="$HOME"
  export HOME="$TMPDIR_TEST/home"
  mkdir -p "$HOME/.pm-workspace-emergency"
}

teardown() {
  export HOME="$ORIG_HOME"
  rm -rf "$TMPDIR_TEST"
}

# ── Structure ──

@test "emergency: script is valid bash" {
  bash -n "$SCRIPT"
}

@test "emergency: uses set -euo pipefail" {
  grep -q "set -euo pipefail" "$SCRIPT"
}

# ── Positive cases ──

@test "emergency: --help shows usage and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Emergency Plan"* ]] || [[ "$output" == *"emergency"* ]]
}

@test "emergency: --check with marker exits 0" {
  echo "2026-04-03" > "$HOME/.pm-workspace-emergency/.plan-executed"
  run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
}

# ── Negative cases ──

@test "emergency: --check without marker exits 1" {
  rm -f "$HOME/.pm-workspace-emergency/.plan-executed"
  run bash "$SCRIPT" --check
  [ "$status" -eq 1 ]
}

# ── Edge cases ──

@test "emergency: --check with empty marker dir" {
  rm -rf "$HOME/.pm-workspace-emergency"
  mkdir -p "$HOME/.pm-workspace-emergency"
  run bash "$SCRIPT" --check
  [ "$status" -eq 1 ]
}

@test "emergency: cache dir constant is correct" {
  grep -q 'pm-workspace-emergency' "$SCRIPT"
}

@test "emergency: marker file path is .plan-executed" {
  grep -q 'plan-executed' "$SCRIPT"
}

# ── Coverage breadth ──

@test "emergency: model selection for 3 RAM tiers" {
  grep -q 'qwen2.5:3b' "$SCRIPT"
  grep -q 'gemma4:e2b' "$SCRIPT"
  grep -q 'gemma4:e4b' "$SCRIPT"
}

@test "emergency: RAM thresholds at 16GB and 32GB" {
  grep -qE 'ge 32|RAM.*32' "$SCRIPT"
  grep -qE 'ge 16|RAM.*16' "$SCRIPT"
}

@test "emergency: supports --model override" {
  grep -q '\-\-model' "$SCRIPT"
}

@test "emergency: generates plan-info.json metadata" {
  grep -q 'plan-info.json' "$SCRIPT"
}

@test "emergency: detects OS and architecture" {
  grep -q 'uname -s' "$SCRIPT"
  grep -q 'uname -m' "$SCRIPT"
}

@test "emergency: supports Linux and macOS" {
  grep -q 'Linux' "$SCRIPT"
  grep -q 'Darwin' "$SCRIPT"
}

@test "emergency: show_help function exists" {
  grep -q 'show_help' "$SCRIPT"
}

@test "emergency: check_plan function exists" {
  grep -q 'check_plan' "$SCRIPT"
}

@test "emergency: iso_date function exists" {
  grep -q 'iso_date' "$SCRIPT"
}
