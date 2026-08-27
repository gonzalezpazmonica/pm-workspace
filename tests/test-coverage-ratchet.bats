#!/usr/bin/env bats
# Ref: SE-339 — test-coverage-ratchet.sh (AC-4: conteo, umbral, detección)

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  RATCHET="$ROOT_DIR/scripts/test-coverage-ratchet.sh"
  TMPD="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPD" 2>/dev/null || true
}

@test "SE-339: cuenta los hooks críticos de la allowlist" {
  n=$(grep -vcE '^\s*#|^\s*$' "$ROOT_DIR/tests/hooks/critical-hooks.txt")
  run bash "$RATCHET"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "$n/$n hooks críticos"
}

@test "SE-339: --ci falla si el umbral supera la cobertura (no-decreciente)" {
  run bash "$RATCHET" --threshold 101 --ci
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "FAIL"
}

@test "SE-339: detecta hook sin test con allowlist custom" {
  echo "hook-inexistente-xyz" > "$TMPD/crit.txt"
  SAVIA_CRITICAL_HOOKS_FILE="$TMPD/crit.txt" run bash "$RATCHET" --ci --threshold 100
  [ "$status" -eq 1 ]
  echo "$output" | grep -qi "hook-inexistente-xyz"
}

@test "SE-339: PURE_BASH y sin red (CRIT-001)" {
  bash -n "$RATCHET"
  ! grep -rniE 'http://|https://|curl |wget |requests\.' "$RATCHET"
}
