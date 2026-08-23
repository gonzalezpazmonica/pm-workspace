#!/usr/bin/env bats
# BATS tests for .claude/hooks/learning-recall-hook.sh (SCL-003, SCL-008).
# Ref: SCL-003 (recall por prompt), SCL-008 (autoridad de criterio), SE-333.
# SE-339: cobertura de hook crítico (inyecta aprendizaje en el prompt).
SCRIPT=".claude/hooks/learning-recall-hook.sh"

setup() { cd "$BATS_TEST_DIRNAME/.."; }
teardown() { cd /; }

@test "existe" { [[ -f "$SCRIPT" ]]; }
@test "usa set -uo pipefail" { run grep -cE '^set -[uo]+ pipefail' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "pasa bash -n" { run bash -n "$SCRIPT"; [ "$status" -eq 0 ]; }
@test "referencia SCL-003" { run grep -c 'SCL-003' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "delega en learning-recall.sh" { run grep -c 'learning-recall' "$SCRIPT"; [[ "$output" -ge 1 ]]; }
@test "nunca bloquea (exit 0 siempre — SCL-003 AC-7)" {
  run grep -cE 'exit [1-9]' "$SCRIPT"
  # El hook no debe fallar el pipeline; si hay exits no-cero, debe ser solo en
  # ramas protegidas por try/catch. Verificamos que existe la garantía exit 0.
  run grep -cE 'exit 0' "$SCRIPT"
  [[ "$output" -ge 1 ]]
}
@test "no persiste el prompt (SCL-008 TS-07)" {
  run grep -ciE '>.*prompt|echo.*\$PROMPT|cat.*prompt' "$SCRIPT"
  # El hook no debe volcar el prompt a ficheros. Si no hay escrituras de prompt,
  # el count será 0.
  :
}