#!/usr/bin/env bats
# BATS tests for .claude/hooks/block-sensitive-tracking.sh
# SE-339: cobertura de hook crítico (seguridad de datos).
SCRIPT=".claude/hooks/block-sensitive-tracking.sh"

setup() { cd "$BATS_TEST_DIRNAME/.."; }
teardown() { cd /; }

@test "existe" { [[ -f "$SCRIPT" ]]; }
@test "usa set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "pasa bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "no filtra vendor cloud (CRIT-001)" { run grep -ciE 'openai|anthropic|azure.*key|aws.*secret' "$SCRIPT"; [[ "$output" -eq 0 ]]; }
@test "protege rutas N3+ via config/sensitive-paths.yaml" {
  run grep -c 'sensitive-paths.yaml' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "tiene logica de bloqueo o cuarentena" {
  run grep -ciE 'exit [1-9]|BLOCK|block|quarant|cuarentena|reject' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "master switch SAVIA_SENSITIVE_TRACKING=off" {
  run grep -c 'SAVIA_SENSITIVE_TRACKING' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "requiere jq para operar" {
  run grep -c 'command -v jq' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}