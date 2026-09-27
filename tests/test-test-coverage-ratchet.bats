#!/usr/bin/env bats
# BATS tests for scripts/test-coverage-ratchet.sh (SE-339).
# Ref: docs/specs/SE-339-test-coverage-ratchet.spec.md
# Every call that passes --threshold uses a temporary --conf: the versioned
# config/test-coverage.conf must never change during the suite.
SCRIPT="scripts/test-coverage-ratchet.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
  CONF="$BATS_TEST_TMPDIR/conf"
}
teardown() { cd /; }

@test "existe + ejecutable" { [[ -x "$SCRIPT" ]]; }
@test "usa set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "pasa bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "referencia SE-339" { run grep -c 'SE-339' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "no vendor cloud (CRIT-001)" { run grep -ciE 'openai|anthropic|azure|ollama' "$SCRIPT"; [[ "$output" -eq 0 ]]; }
@test "--help exit 0" { run bash "$SCRIPT" --help; [ "$status" -eq 0 ]; }
@test "rechaza argumento desconocido" { run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]; }

@test "rechaza --threshold no entero sin persistirlo" {
  run bash "$SCRIPT" --conf "$CONF" --threshold abc
  [ "$status" -eq 2 ]
  [ ! -e "$CONF" ]
}

@test "rechaza --threshold y --conf sin valor" {
  run bash "$SCRIPT" --threshold
  [ "$status" -eq 2 ]
  run bash "$SCRIPT" --conf
  [ "$status" -eq 2 ]
}

@test "usa el conf versionado sin modificarlo" {
  before=$(cat config/test-coverage.conf)
  run bash "$SCRIPT" --ci
  [ "$status" -eq 0 ]
  [ "$(cat config/test-coverage.conf)" = "$before" ]
}

@test "reporta cobertura sobre hooks criticos" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hooks críticos con BATS"* ]]
}

@test "--ci exit 0 cuando cobertura >= umbral (repo real: 100%)" {
  run bash "$SCRIPT" --conf "$CONF" --ci --threshold 100
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: cobertura"* ]]
}

@test "--ci exit 1 cuando cobertura < umbral imposible" {
  run bash "$SCRIPT" --conf "$CONF" --ci --threshold 999
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* ]]
}

@test "RN-01: el umbral persistido no baja por flag" {
  echo "THRESHOLD=90" > "$CONF"
  run bash "$SCRIPT" --conf "$CONF" --threshold 80
  [ "$status" -eq 2 ]
  [[ "$output" == *"RN-01"* ]]
  grep -qx "THRESHOLD=90" "$CONF"
}

@test "el conf se lee como dato, no se ejecuta" {
  echo 'THRESHOLD=$(touch "$BATS_TEST_TMPDIR/pwned")' > "$CONF"
  run bash "$SCRIPT" --conf "$CONF"
  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/pwned" ]
}

@test "detecta hook sin test (contador baja con hook inventado)" {
  echo "hook-inventado-xyz" > "$BATS_TEST_TMPDIR/crit.txt"
  SAVIA_CRITICAL_HOOKS_FILE="$BATS_TEST_TMPDIR/crit.txt" \
    run bash "$SCRIPT" --conf "$CONF" --ci --threshold 100
  [ "$status" -eq 1 ]
  [[ "$output" == *"hook-inventado-xyz"* ]]
}

@test "no escribe nada sin --threshold (read-only)" {
  before=$(git status --porcelain 2>/dev/null)
  run bash "$SCRIPT" --ci
  [ "$status" -eq 0 ]
  [ "$(git status --porcelain 2>/dev/null)" = "$before" ]
}
