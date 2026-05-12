#!/usr/bin/env bats
# tests/flow-otel-wrapper.bats — Tests del wrapper bash flow-otel-exporter.sh
# Requiere: bats-core

WRAPPER="$BATS_TEST_DIRNAME/../scripts/flow-otel-exporter.sh"
FIXTURE_TRACE="$BATS_TEST_DIRNAME/python/fixtures/sample-trace.jsonl"

# ─── TC-B1: Sin SAVIA_OTEL_ENABLED=true, el wrapper sale con exit 0 ──────────

@test "wrapper sale silenciosamente si SAVIA_OTEL_ENABLED no es true" {
  unset SAVIA_OTEL_ENABLED
  run bash "$WRAPPER" "$FIXTURE_TRACE"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ─── TC-B2: Sin argumento de traza, error con mensaje claro ──────────────────

@test "wrapper falla con mensaje claro si no se pasa traza" {
  export SAVIA_OTEL_ENABLED=true
  run bash "$WRAPPER"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Usage" ]]
}

# ─── TC-B3: Con SAVIA_OTEL_DRYRUN=true, wrapper invoca python y sale 0 ───────

@test "wrapper con dry-run invoca python y sale exitosamente" {
  export SAVIA_OTEL_ENABLED=true
  export SAVIA_OTEL_DRYRUN=true
  export SAVIA_OTEL_MAX_CONFIDENTIALITY=N2
  run bash "$WRAPPER" "$FIXTURE_TRACE"
  # Puede ser 0 (exportado) o cualquier código limpio (no colapso)
  # El wrapper propaga el código de python3
  [ "$status" -eq 0 ] || [ "$status" -eq 0 ]
  unset SAVIA_OTEL_ENABLED SAVIA_OTEL_DRYRUN SAVIA_OTEL_MAX_CONFIDENTIALITY
}
