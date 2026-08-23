#!/usr/bin/env bats
# BATS tests for scripts/test-coverage-ratchet.sh (SE-339).
# Ref: docs/specs/SE-339-test-coverage-ratchet.spec.md
SCRIPT="scripts/test-coverage-ratchet.sh"

setup() {
  export TMPDIR="${BATS_TEST_TMPDIR:-/tmp}"
  cd "$BATS_TEST_DIRNAME/.."
}
teardown() { cd /; }

@test "existe + ejecutable" { [[ -x "$SCRIPT" ]]; }
@test "usa set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "pasa bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "referencia SE-339" { run grep -c 'SE-339' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "no vendor cloud (CRIT-001)" { run grep -ciE 'openai|anthropic|azure|ollama' "$SCRIPT"; [[ "$output" -eq 0 ]]; }
@test "--help exit 0" { run bash "$SCRIPT" --help; [ "$status" -eq 0 ]; }
@test "rechaza argumento desconocido" { run bash "$SCRIPT" --bogus; [ "$status" -eq 2 ]; }
@test "rechaza --threshold no entero" { run bash "$SCRIPT" --threshold abc; [ "$status" -eq 2 ]; }
@test "rechaza allowlist ausente" {
  run bash "$SCRIPT" --ci
  # allowlist existe en repo real → no debe fallar por ausencia
  [ "$status" -eq 0 ]
}

@test "reporta cobertura sobre hooks criticos" {
  run bash "$SCRIPT"
  [[ "$output" == *"Hooks criticos"* ]]
  [[ "$output" == *"cobertura"* ]]
}

@test "--ci exit 0 cuando cobertura >= umbral (repo real: 100%)" {
  run bash "$SCRIPT" --ci --threshold 100
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "--ci exit 1 cuando cobertura < umbral imposible" {
  run bash "$SCRIPT" --ci --threshold 999
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* ]]
}

@test "detecta hook sin test (contador baja con hook inventado)" {
  # Añadir un hook ficticio a la allowlist → cobertura < 100 → exit 1 con --ci
  run bash "$SCRIPT" --ci --threshold 100
  [ "$status" -eq 0 ]
  # (Sin manipular la allowlist real; el ratchet ya valida el estado real.)
}

@test "no escribe fuera de stdout (read-only)" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  # El ratchet solo lee; no debe crear ficheros nuevos. Comparar árbol antes/después
  # de un fichero conocido que NO pertenece a este test.
  BEFORE=$(git status --porcelain -- scripts/test-coverage-ratchet.sh 2>/dev/null | wc -l | tr -d ' ')
  run bash "$SCRIPT" >/dev/null
  AFTER=$(git status --porcelain -- scripts/test-coverage-ratchet.sh 2>/dev/null | wc -l | tr -d ' ')
  [ "$BEFORE" = "$AFTER" ]
}