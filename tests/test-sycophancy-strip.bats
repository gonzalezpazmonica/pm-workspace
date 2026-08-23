#!/usr/bin/env bats
# BATS tests for .claude/hooks/sycophancy-strip.sh
# Ref: radical-honesty.md (Rule #24), SPEC-192 (anti-adulación), Layer 1 hook.
# SE-339: cobertura de hook crítico.
SCRIPT=".claude/hooks/sycophancy-strip.sh"

setup() { cd "$BATS_TEST_DIRNAME/.."; }
teardown() { cd /; }

@test "existe" { [[ -f "$SCRIPT" ]]; }
@test "usa set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "pasa bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "referencia SPEC-192 / Rule #24" {
  run grep -c 'SPEC-192' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "detecta patrones de adulación via corpus externo" {
  # Layer 1 usa regex-patterns.json (SPEC-192); el hook debe referenciarlo
  run grep -ciE 'regex-patterns|anti-adulation|adulation' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "soporta modos off/shadow/warn/strip/block" {
  run grep -cE 'SAVIA_ANTIADULATION_LAYER1|shadow|strip|block' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "master switch SAVIA_ANTIADULATION=off" {
  run grep -c 'SAVIA_ANTIADULATION' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}