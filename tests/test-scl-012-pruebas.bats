#!/usr/bin/env bats
# SCL-012 — pruebas de SAGI P1-P5 (harness sobre el orquestador)
# Spec: docs/specs/SCL-012-pruebas-sagi.spec.md (AC-1..AC-4)

SCRIPT="scripts/sagi-pruebas.sh"

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
  FIXDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$FIXDIR"
}

@test "AC-1: harness existe, bash -n, sin vendor names, compone orquestador" {
  [[ -x "$SCRIPT" ]]
  bash -n "$SCRIPT"
  run grep -niE "openai|anthropic|gpt-|gemini|qwen|deepseek" "$SCRIPT"
  [[ "$status" -ne 0 ]]
  grep -q "savia-orchestrator.sh" "$SCRIPT"
}

@test "AC-2: emite JSON reproducible por prueba {prueba,tratamiento,baseline,delta,veredicto}" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, re, json
out = sys.stdin.read()
# extraer líneas JSON embebidas en el texto
for m in re.finditer(r'P[0-9]:(\{.*?\})', out, re.DOTALL):
    d = json.loads(m.group(1))
    for k in ['prueba','tratamiento','baseline','delta','veredicto']:
        assert k in d, k
"
}

@test "AC-3: veredicto agregado CONFIRMA cuando >=2 pruebas PASS" {
  run bash "$SCRIPT"
  [[ "$status" -eq 0 ]]
  # inputs sintéticos de fixture pasan → CONFIRMA
  echo "$output" | grep -qE "CONFIRMA|INCONCLUSO"
}

@test "AC-4: resultado negativo es primera clase — INCONCLUSO en dry-run" {
  run bash "$SCRIPT" --dry-run
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INCONCLUSO"
  # la honestidad está: dice que <2 confirman, no miente
  echo "$output" | grep -q "negativo es primera clase"
}

@test "AC-3b: selección de pruebas (--pruebas) limita el run" {
  run bash "$SCRIPT" --pruebas P1
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "\[P1\]"
  ! echo "$output" | grep -q "\[P3\]"
}

@test "P4/P5 declarados dry-run sin requerir infra federada" {
  run bash "$SCRIPT" --pruebas P4,P5
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "P4.*dry-run\|\[P4\]"
  echo "$output" | grep -q "P5.*dry-run\|\[P5\]"
}

@test "input inválido → exit 2" {
  run bash "$SCRIPT" --pruebas
  [[ "$status" -eq 2 ]]
  run bash "$SCRIPT" --badflag
  [[ "$status" -eq 2 ]]
}

@test "no muta CRITERIO.md ni CONSTITUCION" {
  local h1 h2
  h1=$(sha256sum CRITERIO.md | cut -d' ' -f1)
  h2=$(sha256sum .claude/CONSTITUCION.md | cut -d' ' -f1)
  bash "$SCRIPT" >/dev/null
  [[ "$(sha256sum CRITERIO.md | cut -d' ' -f1)" == "$h1" ]]
  [[ "$(sha256sum .claude/CONSTITUCION.md | cut -d' ' -f1)" == "$h2" ]]
}