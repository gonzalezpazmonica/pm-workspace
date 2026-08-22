#!/usr/bin/env bats
# L13 F2 — meta-control (control metacognitivo sobre SAGI)
# Linea: labs/roadmaps/l13-savia-metacognition.md (F2) / protocolo L13

CONTROL="scripts/meta-control.sh"

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
  FIXDIR=$(mktemp -d)
}

teardown() {
  rm -rf "$FIXDIR"
}

@test "existe, bash -n, sin vendor cloud, PURE_BASH" {
  [[ -x "$CONTROL" ]]
  bash -n "$CONTROL"
  run grep -niE "api\.openai\.com|api\.anthropic\.com|api\.deepseek\.com|api\.google\.com|api\.mistral\.ai" "$CONTROL"
  [[ "$status" -ne 0 ]]
}

@test "M3a: confianza alta + divergencia baja + calibracion buena → EMIT" {
  run bash "$CONTROL" --adjusted 80 --divergence 0.2 --calibration 0.9
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import sys,json;assert json.load(sys.stdin)['action']=='EMIT'"
}

@test "M3b: confianza baja → POSTPONE (pedir evidencia)" {
  run bash "$CONTROL" --adjusted 30 --divergence 0.3 --calibration 0.6
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import sys,json;assert json.load(sys.stdin)['action']=='POSTPONE'"
}

@test "M3c: divergencia alta (L1 predice error) → REPLAN" {
  run bash "$CONTROL" --adjusted 80 --divergence 0.85 --calibration 0.9
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import sys,json;assert json.load(sys.stdin)['action']=='REPLAN'"
}

@test "M3d: calibracion historica mala → REDUCE (bajar autonomia)" {
  run bash "$CONTROL" --adjusted 70 --divergence 0.2 --calibration 0.2
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "import sys,json;assert json.load(sys.stdin)['action']=='REDUCE'"
}

@test "M3: prioridad REPLAN > REDUCE > POSTPONE (divergencia manda sobre calibracion)" {
  # divergencia alta y calibracion mala (ambos gatillos) → REPLAN manda (L1)
  run bash "$CONTROL" --adjusted 40 --divergence 0.9 --calibration 0.1
  echo "$output" | python3 -c "import sys,json;assert json.load(sys.stdin)['action']=='REPLAN'"
}

@test "CRIT-031: dry-run nunca ejecuta (executed=false) y nunca auto-activa" {
  run bash "$CONTROL" --adjusted 80 --divergence 0.2 --calibration 0.9 --dry-run
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert d.get('dry_run') is True
assert d.get('executed') is False
"
}

@test "integracion: orquestador --meta muestra monitor + control (POSTPONE cuando confianza baja)" {
  run bash scripts/savia-orchestrator.sh --task "tarea de prueba" --meta --iterations 1 --dry-run
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "\[meta\] confianza"
  echo "$output" | grep -q "\[meta\] control"
  echo "$output" | grep -q "CRIT-031"
}

@test "input invalido → exit 2 (sin --adjusted)" {
  run bash "$CONTROL"
  [[ "$status" -eq 2 ]]
  run bash "$CONTROL" --adjusted abc
  [[ "$status" -eq 2 ]]
}

@test "CRIT-031/CRIT-001: no toca CRITERIO/CONSTITUCION; sin red" {
  h1=$(sha256sum CRITERIO.md | cut -d' ' -f1)
  h2=$(sha256sum .claude/CONSTITUCION.md | cut -d' ' -f1)
  bash "$CONTROL" --adjusted 50 --divergence 0.5 --calibration 0.5 >/dev/null
  [[ "$(sha256sum CRITERIO.md | cut -d' ' -f1)" == "$h1" ]]
  [[ "$(sha256sum .claude/CONSTITUCION.md | cut -d' ' -f1)" == "$h2" ]]
}