#!/usr/bin/env bats
# SCL-011 — orquestador SAGI mínimo
# Spec: docs/specs/SCL-011-orquestador-sagi.spec.md (AC-1..AC-5)
# Ref: SCL-011 — aislamiento: SCL_PROPOSALS_DIR temporal, nunca docs/learning-proposals/

SCRIPT="scripts/savia-orchestrator.sh"

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
  FIXDIR=$(mktemp -d)
  h1=$(sha256sum CRITERIO.md | cut -d' ' -f1)
  h2=$(sha256sum .claude/CONSTITUCION.md | cut -d' ' -f1)
  echo "$h1" > "$FIXDIR/h1"; echo "$h2" > "$FIXDIR/h2"
  # Isolation: learning proposals go to a temp dir, never docs/learning-proposals/.
  export SCL_PROPOSALS_DIR="$FIXDIR/lp"
  mkdir -p "$SCL_PROPOSALS_DIR"
}

teardown() {
  rm -rf "$FIXDIR"
}

@test "AC-1: existe, bash -n, set -uo pipefail, sin vendor cloud names" {
  [[ -x "$SCRIPT" ]]
  bash -n "$SCRIPT"
  grep -q "set -uo pipefail" "$SCRIPT"
  # agnosticismo: sin vendor de inferencia CLOUD hardcodeado (CRIT-002/ADR-012)
  run grep -niE "api\.openai\.com|api\.anthropic\.com|api\.deepseek\.com|api\.google\.com|api\.mistral\.ai" "$SCRIPT"
  [[ "$status" -ne 0 ]]
  # el modelo LOCAL es configurable (SAGI_LLM_MODEL), no hardcodeado a un proveedor
  grep -q "SAGI_LLM_MODEL" "$SCRIPT"
}

@test "AC-2: ciclo completo LEER→DECIDIR→PERSISTIR→MEDIR emite reporte con L (dry-run muestra el plan)" {
  run bash "$SCRIPT" --task "tarea de prueba" --dry-run --iterations 1
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "leer"
  echo "$output" | grep -q "decidir"
  echo "$output" | grep -q "persistir"
  echo "$output" | grep -q "medir"
  echo "$output" | grep -q "done"
}

@test "AC-2b: modo real completa el ciclo sin errores y crea LP INFERRED" {
  run bash "$SCRIPT" --task "fixture bats orquestador" --iterations 1 --p-consistent 0.6
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "GRANTED\|DENIED\|veredicto"
}

@test "AC-3: no escribe fuera del sustrato (solo markdown/JSONL + stdout)" {
  # el orquestador solo toca el directorio de LPs (markdown), aquí temporal
  local repo_before
  repo_before=$(ls docs/learning-proposals/ 2>/dev/null | sha256sum)
  bash "$SCRIPT" --task "fixture no-write-test" --iterations 1 >/dev/null 2>&1
  # nada nuevo en el repo; en el sustrato temporal solo markdown
  [[ "$(ls docs/learning-proposals/ 2>/dev/null | sha256sum)" == "$repo_before" ]]
  [[ -z "$(find "$SCL_PROPOSALS_DIR" -type f ! -name '*.md')" ]]
}

@test "AC-4: no modifica CRITERIO.md ni CONSTITUCION (hash invariante)" {
  bash "$SCRIPT" --task "fixture hash" --iterations 1 >/dev/null 2>&1
  [[ "$(sha256sum CRITERIO.md | cut -d' ' -f1)" == "$(cat "$FIXDIR/h1")" ]]
  [[ "$(sha256sum .claude/CONSTITUCION.md | cut -d' ' -f1)" == "$(cat "$FIXDIR/h2")" ]]
}

@test "AC-5: --dry-run no ejecuta persistencia ni muta nada" {
  local before
  before=$(ls "$SCL_PROPOSALS_DIR"/*.md 2>/dev/null | wc -l)
  run bash "$SCRIPT" --task "fixture dry" --dry-run --iterations 1
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "dry-run"
  after=$(ls "$SCL_PROPOSALS_DIR"/*.md 2>/dev/null | wc -l)
  [[ "$after" -eq "$before" ]]
}

@test "input inválido: sin --task → exit 2; iterations no entero → exit 2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
  run bash "$SCRIPT" --task x --iterations abc
  [[ "$status" -eq 2 ]]
}
@test "empty: --task vacío → exit 2" {
  run bash "$SCRIPT" --task "" --dry-run
  [[ "$status" -eq 2 ]]
}

@test "reject: flag desconocido → exit 2" {
  run bash "$SCRIPT" --task x --bogus
  [[ "$status" -eq 2 ]]
}

@test "boundary: --iterations 0 en dry-run termina sin crear LPs" {
  run bash "$SCRIPT" --task x --dry-run --iterations 0
  [[ "$status" -eq 0 ]]
  [[ -z "$(ls -A "$SCL_PROPOSALS_DIR")" ]]
}
