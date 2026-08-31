#!/usr/bin/env bats
# test-se357-control-bands.bats — BATS tests for SE-357 Control Bands
# Ref: SE-357 — detección determinista + tiers σ + cierre del loop

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  DETECT="$REPO_ROOT/scripts/control-band-detect.sh"
  AGENT="$REPO_ROOT/scripts/control-band-agent.sh"
  export REPO_ROOT DETECT AGENT
  # historial aislado
  export TMP_HISTORY="$(mktemp -d)"
}

teardown() {
  if [[ -d "${TMP_HISTORY:-}" ]]; then
    rm -rf "$TMP_HISTORY"
  fi
}

# ── T1: detector ──────────────────────────────────────────────────────────────

@test "detector --dry-run no invoca nada" {
  run bash "$DETECT" --metric session_error_rate --dry-run
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"DRY-RUN"* ]]
}

@test "detector requiere --metric" {
  run bash "$DETECT"
  [[ "$status" -ne 0 ]]
}

@test "detector métrica no soportada → error" {
  run bash "$DETECT" --metric inexistente_metric
  [[ "$status" -ne 0 ]]
}

@test "detector con threshold evalúa breach correctamente" {
  run bash "$DETECT" --metric ci_test_failure_rate
  [[ "$status" -eq 0 ]]
  echo "$output" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert 'breached' in d, f'falta breached: {d}'
assert 'sigma_level' in d
"
}

@test "AC-4: detector no contiene invocaciones LLM" {
  # solo comentarios/refs; invocaciones reales de API/modelo prohibidas
  run grep -inE "curl[[:space:]]+.*claude|claude[[:space:]]+-p|/claude[^a-zA-Z]|api[_-]?key[[:space:]]*=|request[[:space:]]+to[[:space:]]+.*model" "$DETECT"
  [[ "$status" -ne 0 ]]
}

# ── T2: agente tiers ──────────────────────────────────────────────────────────

@test "1σ → action log (sin escribir intent)" {
  run bash "$AGENT" --metric ci_test_failure_rate --sigma 0.5
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"1sigma"* ]]
  [[ "$output" == *"log"* ]]
}

@test "2σ → action diagnose (escribe diagnóstico read-only)" {
  run bash "$AGENT" --metric ci_test_failure_rate --sigma 1.5
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"2sigma"* ]]
  [[ "$output" == *"diagnose"* ]]
}

@test "3σ → action propose (escribe intent.md)" {
  run bash "$AGENT" --metric ci_test_failure_rate --sigma 2.5
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"3sigma"* ]]
  [[ "$output" == *"propose"* ]]
  # intent.md creado
  run bash -c "ls $REPO_ROOT/intent/*control-band* 2>/dev/null | wc -l"
  [[ "${lines[0]}" -ge 1 ]]
}

@test "3σ intent.md tiene formato Stage 1 (Intent/Outcome/Affected)" {
  bash "$AGENT" --metric ci_test_failure_rate --sigma 3.0 >/dev/null 2>&1
  local intent_file
  intent_file=$(ls "$REPO_ROOT"/intent/*control-band* 2>/dev/null | head -1)
  [[ -n "$intent_file" ]]
  grep -q "^# Intent:" "$intent_file"
  grep -q "Outcome propuesto" "$intent_file"
  grep -q "Sistemas afectados" "$intent_file"
}

@test "historial append-only crece" {
  bash "$AGENT" --metric ci_test_failure_rate --sigma 0.3 >/dev/null 2>&1
  bash "$AGENT" --metric ci_test_failure_rate --sigma 2.2 >/dev/null 2>&1
  local count
  count=$(wc -l < "$REPO_ROOT/data/control-bands/history.jsonl")
  [[ "$count" -ge 2 ]]
}

@test "agente requiere --metric y --sigma" {
  run bash "$AGENT" --metric solo
  [[ "$status" -ne 0 ]]
}

@test "config ausente → fail-closed" {
  run bash "$DETECT" --metric ci_test_failure_rate --config /tmp/no-such-config.yaml
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"Fail-closed"* ]]
}
