#!/usr/bin/env bats
# Ref: scripts/emergency-plan.sh — Offline LLM pre-download
# Tests for emergency-plan.sh

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/emergency-plan.sh"
  TMPDIR_EP=$(mktemp -d)
}

teardown() {
  rm -rf "$TMPDIR_EP"
}

@test "help shows usage" {
  run bash "$SCRIPT" --help
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Emergency Plan"* ]]
  [[ "$output" == *"--model"* ]]
}

@test "check without prior execution fails" {
  export HOME="$TMPDIR_EP"
  run bash "$SCRIPT" --check
  [[ "$status" -eq 1 ]]
}

@test "check with marker file succeeds" {
  export HOME="$TMPDIR_EP"
  mkdir -p "$TMPDIR_EP/.pm-workspace-emergency"
  echo "2026-04-04T10:00:00Z" > "$TMPDIR_EP/.pm-workspace-emergency/.plan-executed"
  run bash "$SCRIPT" --check
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"ejecutado"* ]]
}

@test "script has set -euo pipefail" {
  head -5 "$SCRIPT" | grep -q "set -euo pipefail"
}

@test "script detects OS and RAM" {
  # The script prints hardware info early — verify it contains detection logic
  grep -q "uname -s" "$SCRIPT"
  grep -q "MemTotal\|hw.memsize" "$SCRIPT"
}

@test "model selection thresholds exist" {
  grep -q "8.*3b\|16.*7b\|32.*14b" "$SCRIPT"
}

@test "supports --model override" {
  grep -q "\-\-model" "$SCRIPT"
}

@test "cache directory uses HOME" {
  grep -q 'HOME.*emergency' "$SCRIPT"
}

@test "edge: check with empty HOME dir returns failure" {
  export HOME="$TMPDIR_EP"
  mkdir -p "$TMPDIR_EP"
  run bash "$SCRIPT" --check
  [[ "$status" -ne 0 ]]
}

@test "edge: iso_date function exists" {
  grep -q "iso_date()" "$SCRIPT"
}

@test "edge: _extract_ollama function exists" {
  grep -q "_extract_ollama()" "$SCRIPT"
}

@test "edge: _pull_small function exists" {
  grep -q "_pull_small()" "$SCRIPT"
}
