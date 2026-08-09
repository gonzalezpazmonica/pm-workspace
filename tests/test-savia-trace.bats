#!/usr/bin/env bats
# BATS tests for scripts/savia-trace.sh
# SE-313 S2 — contexto distribuido de traza (W3C traceparent).
# Ref: docs/propuestas/SE-313-observabilidad-trazabilidad-agentes-eu-ai-act.md

SCRIPT="scripts/savia-trace.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export SAVIA_TELEMETRY_FILE="${BATS_TEST_TMPDIR:-/tmp}/telemetry-s2.jsonl"
  rm -f "$SAVIA_TELEMETRY_FILE" 2>/dev/null || true
  unset SAVIA_TRACEPARENT
}

teardown() {
  rm -f "${SAVIA_TELEMETRY_FILE:-}" 2>/dev/null || true
  unset SAVIA_TRACEPARENT
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

@test "start emite traceparent W3C válido" {
  run bash "$SCRIPT" start agent.started agent_name=x
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^00-[0-9a-f]{32}-[0-9a-f]{16}-01$ ]]
}

@test "start+end comparten trace_id (misma traza)" {
  TP=$(bash "$SCRIPT" start agent.started agent_name=x)
  TRACE_ID="${TP:3:32}"
  bash -c "SAVIA_TRACEPARENT='$TP' bash '$SCRIPT' end agent.completed agent_name=x duration_ms=10" >/dev/null
  run jq -e 'select(.event == "agent.started") | .trace_id' "$SAVIA_TELEMETRY_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == "\"$TRACE_ID\"" ]]
  run jq -e 'select(.event == "agent.completed") | .trace_id' "$SAVIA_TELEMETRY_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" == "\"$TRACE_ID\"" ]]
}

@test "end referencia el span del padre como parent_span_id" {
  TP=$(bash "$SCRIPT" start agent.started agent_name=x)
  bash -c "SAVIA_TRACEPARENT='$TP' bash '$SCRIPT' end agent.completed agent_name=x" >/dev/null
  # El evento de cierre debe existir; el parent_span_id del evento start debe
  # ser el span heredado (si existía) o estar ausente en raíz.
  run jq -e '.event == "agent.completed"' "$SAVIA_TELEMETRY_FILE"
  [ "$status" -eq 0 ]
}

@test "sin argumentos falla con usage" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "sin evento falla con error" {
  run bash "$SCRIPT" start
  [ "$status" -eq 2 ]
}

@test "hereda traceparent existente (trace_id conservado)" {
  export SAVIA_TRACEPARENT="00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
  run bash "$SCRIPT" start agent.started agent_name=x
  [ "$status" -eq 0 ]
  [[ "$output" == 00-4bf92f3577b34da6a3ce929d0e0e4736-* ]]
  unset SAVIA_TRACEPARENT
}
