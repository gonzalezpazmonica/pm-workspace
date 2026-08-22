#!/usr/bin/env bats
# SCL-013 — flujo end-to-end (P6): objetivo multi-paso
# Spec: docs/specs/SCL-013-flujo-end-to-end.spec.md (AC-1..AC-7)

SCRIPT="scripts/sagi-e2e.sh"

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
  FIXDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$FIXDIR"
}

@test "AC-1: existe, bash -n, sin vendor names, set -uo pipefail" {
  [[ -x "$SCRIPT" ]]
  bash -n "$SCRIPT"
  grep -q "set -uo pipefail" "$SCRIPT"
  run grep -niE "openai|anthropic|gpt-|gemini|qwen|deepseek" "$SCRIPT"
  [[ "$status" -ne 0 ]]
}

@test "AC-2: goal alcanzable → completa ≤10 pasos con quality ≥80" {
  run bash "$SCRIPT" --goal "generar spec SDD valida desde un objetivo"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "veredicto.*PASS"
  echo "$output" | python3 -c "
import sys, json
out = sys.stdin.read()
line = [l for l in out.splitlines() if l.startswith('{')][-1]
d = json.loads(line)
assert d['steps_used'] <= d['max_steps']
assert d['quality'] >= 80
assert d['veredicto'] == 'PASS'
"
}

@test "AC-3: --dry-run muestra el plan sin ejecutar" {
  run bash "$SCRIPT" --goal "x" --dry-run
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "dry-run"
  echo "$output" | grep -q "LEER → DECIDIR → VALIDAR → PERSISTIR → MEDIR"
}

@test "AC-4: --max-steps 2 con goal complejo → FAIL (límite duro)" {
  run bash "$SCRIPT" --goal "objetivo complejo" --max-steps 2
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "veredicto.*FAIL"
}

@test "AC-5: emite JSON reproducible con métricas del contrato" {
  run bash "$SCRIPT" --goal "probar contrato"
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
out = sys.stdin.read()
line = [l for l in out.splitlines() if l.startswith('{')][-1]
d = json.loads(line)
for k in ['ts','goal','steps_used','max_steps','quality','delta_pass','veredicto']:
    assert k in d, k
"
}

@test "AC-6: no modifica CRITERIO.md ni CONSTITUCION" {
  local h1 h2
  h1=$(sha256sum CRITERIO.md | cut -d' ' -f1)
  h2=$(sha256sum .claude/CONSTITUCION.md | cut -d' ' -f1)
  bash "$SCRIPT" --goal "hash test" >/dev/null
  [[ "$(sha256sum CRITERIO.md | cut -d' ' -f1)" == "$h1" ]]
  [[ "$(sha256sum .claude/CONSTITUCION.md | cut -d' ' -f1)" == "$h2" ]]
}

@test "AC-7 + RN-04: veredicto FAIL nunca auto-activa; emite delegación CRIT-031" {
  run bash "$SCRIPT" --goal "probar delegacion" --max-steps 1
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "CRIT-031\|INFERRED"
}

@test "input inválido → exit 2 (sin goal; --goal sin valor; --max-steps no entero)" {
  run bash "$SCRIPT"
  [[ "$status" -eq 2 ]]
  run bash "$SCRIPT" --goal
  [[ "$status" -eq 2 ]]
  run bash "$SCRIPT" --goal x --max-steps abc
  [[ "$status" -eq 2 ]]
}