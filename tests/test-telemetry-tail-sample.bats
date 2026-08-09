#!/usr/bin/env bats
# BATS tests for scripts/telemetry-tail-sample.sh
# SE-313 S4 — sampling tail + retención + rotación + redacción.
# Ref: docs/propuestas/SE-313-observabilidad-trazabilidad-agentes-eu-ai-act.md

SCRIPT="scripts/telemetry-tail-sample.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export SAVIA_TELEMETRY_FILE="${BATS_TEST_TMPDIR:-/tmp}/telemetry-s4.jsonl"
  rm -f "${SAVIA_TELEMETRY_FILE}" "${SAVIA_TELEMETRY_FILE}."* 2>/dev/null || true
}

teardown() {
  rm -f "${SAVIA_TELEMETRY_FILE:-}" "${SAVIA_TELEMETRY_FILE:-}."* 2>/dev/null || true
  cd /
}

@test "script exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

@test "passes bash -n syntax" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "check sin eventos no falla" {
  run bash "$SCRIPT" check
  [ "$status" -eq 0 ]
}

@test "check valida líneas con schema correcto" {
  bash scripts/otel-emit.sh agent.started agent_name=x >/dev/null
  bash scripts/otel-emit.sh dispatch.resolved agent_name=y >/dev/null
  run bash "$SCRIPT" check
  [ "$status" -eq 0 ]
  [[ "$output" == *"telemetry-events.jsonl: 2 lines"* ]]
}

@test "redact degrada a solo ts+event con SAVIA_TELEMETRY_REDACT=1" {
  bash scripts/otel-emit.sh agent.started agent_name=secret-agent tier=mid >/dev/null
  run bash "$SCRIPT" redact
  [ "$status" -eq 0 ]
  run jq -e '.event == "agent.started" and (has("agent_name") | not) and (has("tier") | not) and .schema == "savia.event/1.0" and .ts' "$SAVIA_TELEMETRY_FILE"
  [ "$status" -eq 0 ]
}

@test "rotate no muta cuando está bajo el umbral" {
  bash scripts/otel-emit.sh agent.started agent_name=x >/dev/null
  run bash "$SCRIPT" rotate
  [ "$status" -eq 0 ]
  # No debe haber fichero rotado
  [[ ! -f "${SAVIA_TELEMETRY_FILE}."* ]]
}

@test "usage inválido falla" {
  run bash "$SCRIPT" no-such-mode
  [ "$status" -eq 2 ]
}
