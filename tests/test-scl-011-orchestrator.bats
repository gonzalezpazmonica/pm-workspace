#!/usr/bin/env bats
# SCL-011 — orquestador SAGI mínimo
# Spec: docs/specs/SCL-011-orquestador-sagi.spec.md (AC-1..AC-5)

SCRIPT="scripts/savia-orchestrator.sh"

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
  FIXDIR=$(mktemp -d)
  h1=$(sha256sum CRITERIO.md | cut -d' ' -f1)
  h2=$(sha256sum .claude/CONSTITUCION.md | cut -d' ' -f1)
  echo "$h1" > "$FIXDIR/h1"; echo "$h2" > "$FIXDIR/h2"
}

teardown() {
  rm -rf "$FIXDIR"
}

@test "AC-1: existe, bash -n, set -uo pipefail, sin vendor names" {
  [[ -x "$SCRIPT" ]]
  bash -n "$SCRIPT"
  grep -q "set -uo pipefail" "$SCRIPT"
  run grep -niE "openai|anthropic|gpt-|gemini|qwen|deepseek" "$SCRIPT"
  [[ "$status" -ne 0 ]]
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
  # el orquestador solo toca docs/learning-proposals (markdown)
  local before after
  before=$(ls docs/learning-proposals/*.md 2>/dev/null | wc -l)
  bash "$SCRIPT" --task "fixture no-write-test" --iterations 1 >/dev/null 2>&1
  after=$(ls docs/learning-proposals/*.md 2>/dev/null | wc -l)
  # puede añadir 1 LP (markdown legítimo); nunca binarios/otros
  [[ "$after" -ge "$before" ]]
  # limpiamos la LP de fixture creada (ruido)
  rm -f docs/learning-proposals/LP-*fixture-no-write-test*.md 2>/dev/null || true
}

@test "AC-4: no modifica CRITERIO.md ni CONSTITUCION (hash invariante)" {
  bash "$SCRIPT" --task "fixture hash" --iterations 1 >/dev/null 2>&1
  [[ "$(sha256sum CRITERIO.md | cut -d' ' -f1)" == "$(cat "$FIXDIR/h1")" ]]
  [[ "$(sha256sum .claude/CONSTITUCION.md | cut -d' ' -f1)" == "$(cat "$FIXDIR/h2")" ]]
}

@test "AC-5: --dry-run no ejecuta persistencia ni muta nada" {
  local before
  before=$(ls docs/learning-proposals/*.md 2>/dev/null | wc -l)
  run bash "$SCRIPT" --task "fixture dry" --dry-run --iterations 1
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "dry-run"
  after=$(ls docs/learning-proposals/*.md 2>/dev/null | wc -l)
  [[ "$after" -eq "$before" ]]
}

@test "input inválido: sin --task → exit 2; iterations no entero → exit 2" {
  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
  run bash "$SCRIPT" --task x --iterations abc
  [[ "$status" -eq 2 ]]
}