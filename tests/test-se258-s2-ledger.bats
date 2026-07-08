#!/usr/bin/env bats
# tests/test-se258-s2-ledger.bats
# Ref: SE-258 Slice 2 — verify-ledger-chain

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/verify-ledger-chain.sh"
}

teardown() {
  true
}

@test "se258-s2: script is valid bash" {
  bash -n "$SCRIPT"
}

@test "se258-s2: has set -uo pipefail" {
  grep -q "set -uo pipefail" "$SCRIPT"
}

@test "se258-s2: runs without errors" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Chain integrity: OK"* ]]
}
