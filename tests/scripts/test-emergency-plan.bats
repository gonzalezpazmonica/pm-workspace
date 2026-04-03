#!/usr/bin/env bats
# Tests for emergency-plan.sh — Offline LLM pre-download

SCRIPT="$BATS_TEST_DIRNAME/../../scripts/emergency-plan.sh"

setup() {
  export TMPDIR_TEST=$(mktemp -d)
  export HOME="$TMPDIR_TEST/home"
  mkdir -p "$HOME/.pm-workspace-emergency"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

@test "emergency-plan: script is valid bash" {
  bash -n "$SCRIPT"
}

@test "emergency-plan: uses set -euo pipefail" {
  grep -q "set -euo pipefail" "$SCRIPT"
}

@test "emergency-plan: --help shows usage and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Emergency Plan"* ]] || [[ "$output" == *"emergency"* ]]
}

@test "emergency-plan: --check without marker exits 1" {
  rm -f "$HOME/.pm-workspace-emergency/.plan-executed"
  run bash "$SCRIPT" --check
  [ "$status" -eq 1 ]
}

@test "emergency-plan: --check with marker exits 0" {
  echo "2026-04-03" > "$HOME/.pm-workspace-emergency/.plan-executed"
  run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"ejecutado"* ]] || [[ "$output" == *"plan"* ]]
}

@test "emergency-plan: cache dir constant is correct" {
  grep -q 'CACHE_DIR=.*pm-workspace-emergency' "$SCRIPT"
}

@test "emergency-plan: model selection logic exists" {
  grep -q 'qwen2.5:3b' "$SCRIPT"
  grep -q 'qwen2.5:7b' "$SCRIPT"
  grep -q 'qwen2.5:14b' "$SCRIPT"
}

@test "emergency-plan: RAM-based model selection thresholds" {
  # 8GB → 3b, 16GB → 7b, 32GB+ → 14b
  grep -q 'RAM_GB.*32.*14b' "$SCRIPT" || grep -q 'ge 32.*14b' "$SCRIPT"
  grep -q 'RAM_GB.*16.*7b' "$SCRIPT" || grep -q 'ge 16.*7b' "$SCRIPT"
}

@test "emergency-plan: supports --model override" {
  grep -q '\-\-model' "$SCRIPT"
}
