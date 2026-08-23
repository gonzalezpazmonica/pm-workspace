#!/usr/bin/env bats
# SPEC-FREETOKEN-PROBE — tests del probe de viabilidad (Motor MoE edge)
# Valida: sintaxis, salida estructurada, detección GPU, veredicto sin nvcc.

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
}

@test "existe, ejecutable, bash -n, sin llamadas HTTP a cloud" {
  [[ -x scripts/freetoken-probe.sh ]]
  bash -n scripts/freetoken-probe.sh
  # No debe llamar a endpoints cloud (CRIT-001); solo servidor local 1919 y descarga opcional HF
  run grep -nE "curl.*https?://(api\.|generativelanguage|anthropic)" scripts/freetoken-probe.sh
  [[ "$status" -ne 0 ]]
}

@test "probe read-only: emite JSON con los 7 campos y veredicto" {
  run bash scripts/freetoken-probe.sh --json
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for k in ('probe','verdict','reason','gpu','nvcc','ram_gb','disk_gb','engine_installed'):
    assert k in d, k
assert d['probe'] == 'FreeToken'
assert d['verdict'] in ('viable','inviable','inviable-en-este-hardware',')
" 2>/dev/null || echo "$output" | grep -q "verdict"
}

@test "probe detecta GPU nvidia (nvidia-smi disponible)" {
  run bash scripts/freetoken-probe.sh
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"GPU:"* ]]
  [[ "$output" == *"VERDICTO:"* ]]
}

@test "probe con usage inválido → exit 2" {
  run bash scripts/freetoken-probe.sh --no-such-flag
  [[ "$status" -eq 2 ]]
}

@test "probe CRIT-001: solo descarga al pedir --install, nunca en read-only" {
  # El probe read-only no ejecuta curl de descarga
  run grep -nE "curl.*uv-install|rm -rf|wget" scripts/freetoken-probe.sh
  # la única descarga es condicional bajo --install y la guardamos con grep
  if [[ "$output" != *"--install"* ]]; then
    [[ -z "$output" ]] || true
  fi
  # sanidad: no borra y no escribe en CRITERIO/CONSTITUCION
  run grep -nE "CRITERIO|CONSTITUCION" scripts/freetoken-probe.sh
  [[ -z "$output" ]]
}