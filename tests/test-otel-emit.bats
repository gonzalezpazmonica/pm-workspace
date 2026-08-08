#!/usr/bin/env bats
# BATS tests for scripts/otel-emit.sh
# SE-313 S1 — emisor de eventos de telemetría estándar (savia.event/1.0).
# Ref: docs/propuestas/SE-313-observabilidad-trazabilidad-agentes-eu-ai-act.md

SCRIPT="scripts/otel-emit.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export SAVIA_TELEMETRY_FILE="${BATS_TEST_TMPDIR:-/tmp}/telemetry-events.jsonl"
  rm -f "$SAVIA_TELEMETRY_FILE" 2>/dev/null || true
}

teardown() {
  rm -f "${SAVIA_TELEMETRY_FILE:-}" 2>/dev/null || true
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

@test "emite evento válido con trace_id y span_id" {
  run bash "$SCRIPT" agent.started agent_name=drift-auditor tier=heavy duration_ms=42
  [ "$status" -eq 0 ]
  [[ -f "$SAVIA_TELEMETRY_FILE" ]]
  run jq -e '.schema == "savia.event/1.0" and .event == "agent.started" and .trace_id and .span_id' "$SAVIA_TELEMETRY_FILE"
  [ "$status" -eq 0 ]
}

@test "campos numéricos se emiten sin comillas" {
  run bash "$SCRIPT" agent.completed agent_name=test exit_code=0 duration_ms=1234
  [ "$status" -eq 0 ]
  run jq -e '.duration_ms == 1234' "$SAVIA_TELEMETRY_FILE"
  [ "$status" -eq 0 ]
  # exit_code debe ser entero, no string
  run jq -e '.exit_code | type == "number"' "$SAVIA_TELEMETRY_FILE"
  [ "$status" -eq 0 ]
}

@test "evento vacío no escribe nada y falla" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ ! -f "$SAVIA_TELEMETRY_FILE" ]]
}

@test "hereda traceparent si se propaga" {
  export SAVIA_TRACEPARENT="00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
  run bash "$SCRIPT" dispatch.resolved agent_name=x
  [ "$status" -eq 0 ]
  run jq -e '.trace_id == "4bf92f3577b34da6a3ce929d0e0e4736" and .parent_span_id == "00f067aa0ba902b7"' "$SAVIA_TELEMETRY_FILE"
  [ "$status" -eq 0 ]
  unset SAVIA_TRACEPARENT
}

@test "escape de comillas en valores string" {
  run bash "$SCRIPT" dispatch.failed agent_name=x error="Model not found: deepseek/deepseek-v4-pro"
  [ "$status" -eq 0 ]
  run jq -e '.error == "Model not found: deepseek/deepseek-v4-pro"' "$SAVIA_TELEMETRY_FILE"
  [ "$status" -eq 0 ]
}
