#!/usr/bin/env bats
# tests/test-se258-s2-ledger.bats
# Ref: SE-258 Slice 2 — verify-ledger-chain
set -uo pipefail

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export SCRIPT="$REPO_ROOT/scripts/verify-ledger-chain.sh"
  export LEDGER="$REPO_ROOT/data/relacion/ledger.jsonl"
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
  [[ "$output" == *"Chain integrity: OK"* || "$output" == *"ledger.jsonl not found"* ]]
}

@test "se258-s2: missing ledger file exits zero (destracking S1)" {
  run env LEDGER=/nonexistent/ledger.jsonl bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ledger.jsonl not found"* ]]
}

@test "se258-s2: handles empty ledger file gracefully" {
  TMP_LEDGER=$(mktemp)
  printf '' > "$TMP_LEDGER"
  run env LEDGER="$TMP_LEDGER" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  rm -f "$TMP_LEDGER"
}

@test "se258-s2: rejects invalid ledger with malformed JSON" {
  TMP_LEDGER=$(mktemp)
  printf 'not-json\n' > "$TMP_LEDGER"
  run env LEDGER="$TMP_LEDGER" bash "$SCRIPT"
  [ "$status" -ne 0 ]
  rm -f "$TMP_LEDGER"
}

@test "se258-s2: handles large ledger file without timeout" {
  if [[ -f "$LEDGER" ]]; then
    run timeout 10 bash "$SCRIPT"
    [ "$status" -eq 0 ]
  else
    true
  fi
}

@test "se258-s2: verify script exits with zero on null input device" {
  run bash "$SCRIPT" < /dev/null
  [ "$status" -eq 0 ]
}
