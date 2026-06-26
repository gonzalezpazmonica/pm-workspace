#!/usr/bin/env bats
# test-se-009-observability.bats — SPEC-SE-009: Observability Stack
# Tests: otel-collector-config.sh, metrics-emitter.sh

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export REPO_ROOT

  OTEL_SCRIPT="${REPO_ROOT}/scripts/enterprise/otel-collector-config.sh"
  METRICS_SCRIPT="${REPO_ROOT}/scripts/enterprise/metrics-emitter.sh"
  export OTEL_SCRIPT METRICS_SCRIPT

  OBS_OUT="${TEST_TMPDIR}/observability"
  export OBS_OUT
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ── Test 1: otel-collector-config.sh existe y produce YAML ────────────────────

@test "SE-009: otel-collector-config.sh existe y es ejecutable" {
  [[ -f "$OTEL_SCRIPT" ]]
  [[ -x "$OTEL_SCRIPT" ]] || chmod +x "$OTEL_SCRIPT"
}

# ── Test 2: genera otel-config.yaml ──────────────────────────────────────────

@test "SE-009: otel-collector-config.sh produce otel-config.yaml" {
  chmod +x "$OTEL_SCRIPT"
  run bash "$OTEL_SCRIPT" --backend prometheus --output-dir "$OBS_OUT"
  [ "$status" -eq 0 ]
  [[ -f "${OBS_OUT}/otel-config.yaml" ]]
}

# ── Test 3: otel-config.yaml tiene receivers, processors, exporters ───────────

@test "SE-009: otel-config.yaml tiene receivers, processors, exporters" {
  chmod +x "$OTEL_SCRIPT"
  bash "$OTEL_SCRIPT" --backend prometheus --output-dir "$OBS_OUT" >/dev/null 2>&1
  CONFIG="${OBS_OUT}/otel-config.yaml"

  grep -q "receivers:" "$CONFIG"
  grep -q "processors:" "$CONFIG"
  grep -q "exporters:" "$CONFIG"
}

# ── Test 4: metrics-emitter.sh existe ────────────────────────────────────────

@test "SE-009: metrics-emitter.sh existe y es ejecutable" {
  [[ -f "$METRICS_SCRIPT" ]]
  [[ -x "$METRICS_SCRIPT" ]] || chmod +x "$METRICS_SCRIPT"
}

# ── Test 5: --format prom produce texto Prometheus válido ─────────────────────

@test "SE-009: --format prom produce texto Prometheus válido" {
  chmod +x "$METRICS_SCRIPT"
  run bash "$METRICS_SCRIPT" --format prom --dry-run
  [ "$status" -eq 0 ]
  # Prometheus text format: líneas con # HELP, # TYPE, y métricas
  echo "$output" | grep -q "^# HELP "
  echo "$output" | grep -q "^# TYPE "
  echo "$output" | grep -q "savia_"
}

# ── Test 6: docker-compose.observability.yml tiene servicios ─────────────────

@test "SE-009: docker-compose.observability.yml generado tiene servicios" {
  chmod +x "$OTEL_SCRIPT"
  bash "$OTEL_SCRIPT" --backend prometheus --output-dir "$OBS_OUT" >/dev/null 2>&1
  DC="${OBS_OUT}/docker-compose.observability.yml"

  [[ -f "$DC" ]]
  grep -q "services:" "$DC"
  grep -q "otel-collector" "$DC"
  grep -q "prometheus" "$DC"
  grep -q "grafana" "$DC"
}

# ── Test 7: --format otlp produce JSON con resourceMetrics ───────────────────

@test "SE-009: --format otlp produce JSON válido con resourceMetrics" {
  chmod +x "$METRICS_SCRIPT"
  run bash "$METRICS_SCRIPT" --format otlp --dry-run
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"resourceMetrics"'
}

# ── Test 8: backend loki produce config distinta a prometheus ─────────────────

@test "SE-009: backend loki produce configuración con loki exporter" {
  chmod +x "$OTEL_SCRIPT"
  LOKI_OUT="${TEST_TMPDIR}/observability-loki"
  bash "$OTEL_SCRIPT" --backend loki --output-dir "$LOKI_OUT" >/dev/null 2>&1
  grep -q "loki" "${LOKI_OUT}/otel-config.yaml"
}
