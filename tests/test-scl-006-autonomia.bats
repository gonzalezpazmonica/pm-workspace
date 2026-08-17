#!/usr/bin/env bats
# SCL-006 — Autonomía graduada por p_consistent
# Ref: docs/specs/SCL-006-autonomia-graduada.spec.md

set -uo pipefail

setup_file() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  export REPO_ROOT
}

setup() {
  AUT="$REPO_ROOT/scripts/learning-autonomy.sh"
}

@test "AC-1: p_consistent bajo (<0.5) restringe a L0 — L1 denegado" {
  run bash "$AUT" --p-consistent 0.4 --requested L1
  [ "$status" -ne 0 ]
  [[ "$output" == *"L0"* ]]
}

@test "AC-2: p 0.5-0.7 permite L1" {
  run bash "$AUT" --p-consistent 0.6 --requested L1
  [ "$status" -eq 0 ]
  [[ "$output" == *"GRANTED"* ]]
}

@test "AC-3: p 0.7-0.85 permite L2, no L3" {
  run bash "$AUT" --p-consistent 0.8 --requested L2
  [ "$status" -eq 0 ]
  run bash "$AUT" --p-consistent 0.8 --requested L3
  [ "$status" -ne 0 ]
}

@test "AC-4: p >= 0.85 degrada a L2 sin historial+aprobacion (gates loop-phasing)" {
  run bash "$AUT" --p-consistent 0.9 --requested L3
  [ "$status" -ne 0 ]
  [[ "$output" == *"L2"* ]]
}

@test "AC-5: p >= 0.85 + historial + humano permite L3" {
  run bash "$AUT" --p-consistent 0.9 --requested L3 --history-ok --human-ok
  [ "$status" -eq 0 ]
  [[ "$output" == *"L3"* ]]
  [[ "$output" == *"GRANTED"* ]]
}

@test "AC-6: pedir menos de lo permitido siempre se concede" {
  run bash "$AUT" --p-consistent 0.9 --requested L1 --history-ok --human-ok
  [ "$status" -eq 0 ]
}

@test "AC-7: --json emite JSON valido" {
  run bash "$AUT" --p-consistent 0.65 --requested L1 --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['granted'] == True, d; assert d['allowed'] == 'L1', d"
}

@test "AC-8: valor fuera de rango es error (exit 3)" {
  run bash "$AUT" --p-consistent 1.5
  [ "$status" -eq 3 ]
}
