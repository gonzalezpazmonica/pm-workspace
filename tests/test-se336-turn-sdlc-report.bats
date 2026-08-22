#!/usr/bin/env bats
# SE-336 S4 — turn-sdlc-report: consolidación por ventana
# Spec: docs/specs/SE-336-turn-sdlc.spec.md (AC-08)

SCRIPT="scripts/turn-sdlc-report.sh"

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
  FIXDIR=$(mktemp -d)
  export SAVIA_REPORT_FIXDIR="$FIXDIR"
}

teardown() {
  # el reporte escribe en output/ del repo: limpiar artefactos de test
  rm -f output/turn-sdlc-report-WTEST.md
  rm -rf "$FIXDIR"
}

@test "AC-08a: reporte con contadores coherentes con JSONL de fixture" {
  # fixture: 4 turnos true, 2 false, 1 na + 1 block DOD + 2 warn DOD
  local disc="$FIXDIR/disc.jsonl" dod="$FIXDIR/dod.jsonl"
  cat > "$disc" << 'EOF'
{"ts":"2026-08-22T10:00:00Z","query_hash":"aaa","first_tools":"savia-vaults_vault_search,","order_ok":"true"}
{"ts":"2026-08-22T10:01:00Z","query_hash":"bbb","first_tools":"memory-store.sh,","order_ok":"true"}
{"ts":"2026-08-22T10:02:00Z","query_hash":"ccc","first_tools":"codegraph_explore,","order_ok":"true"}
{"ts":"2026-08-22T10:03:00Z","query_hash":"ddd","first_tools":"savia-vaults_vault_read,","order_ok":"true"}
{"ts":"2026-08-22T10:04:00Z","query_hash":"eee","first_tools":"grep,grep,grep,savia-vaults_vault_search,","order_ok":"false"}
{"ts":"2026-08-22T10:05:00Z","query_hash":"fff","first_tools":"glob,read,grep,","order_ok":"false"}
{"ts":"2026-08-22T10:06:00Z","query_hash":"ggg","first_tools":"edit,bash,","order_ok":"na"}
EOF
  cat > "$dod" << 'EOF'
{"ts":"2026-08-22T10:07:00Z","rule":"DOD-001","severity":"block","detail":"x","query_hash":"hhh"}
{"ts":"2026-08-22T10:08:00Z","rule":"DOD-002","severity":"warn","detail":"y","query_hash":"iii"}
{"ts":"2026-08-22T10:09:00Z","rule":"DOD-003","severity":"warn","detail":"z","query_hash":"jjj"}
EOF

  SAVIA_TURN_SDLC_DISCOVERY_LOG="$disc" SAVIA_TURN_SDLC_DOD_LOG="$dod" \
    SAVIA_TURN_SDLC_OUT_DIR="$FIXDIR/out" \
    run bash "$SCRIPT" --window WTEST
  [[ "$status" -eq 0 ]]
  [[ -f "$FIXDIR/out/turn-sdlc-report-WTEST.md" ]]
  grep -q "Turnos observados | 7" "$FIXDIR/out/turn-sdlc-report-WTEST.md"
  grep -q "order_ok=true | 4" "$FIXDIR/out/turn-sdlc-report-WTEST.md"
  grep -q "order_ok=false | 2" "$FIXDIR/out/turn-sdlc-report-WTEST.md"
  grep -q "DOD bloqueos | 1" "$FIXDIR/out/turn-sdlc-report-WTEST.md"
  grep -q "DOD warnings | 2" "$FIXDIR/out/turn-sdlc-report-WTEST.md"
}

@test "AC-08b: --json produce contadores correctos" {
  # generar logs reales mínimos para el modo por defecto
  mkdir -p output/learning-loop output/turn-sdlc
  local disc="output/learning-loop/discovery-order.jsonl"
  local dod="output/turn-sdlc/dod-gate.jsonl"
  cp "$disc" "$FIXDIR/disc.bak" 2>/dev/null || true
  cp "$dod" "$FIXDIR/dod.bak" 2>/dev/null || true

  printf '%s\n' '{"ts":"t","query_hash":"a","first_tools":"grep,","order_ok":"false"}' > "$disc"
  printf '%s\n' '{"ts":"t","query_hash":"a","first_tools":"vault_search,","order_ok":"true"}' >> "$disc"

  run bash "$SCRIPT" --window WTEST --json
  [[ "$status" -eq 0 ]]
  # extraer solo la línea JSON (el modo json imprime una única línea)
  local jsonline
  jsonline=$(echo "$output" | grep '^{' | head -1)
  echo "$jsonline" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
assert d['turns'] == 2, d
assert d['order_false'] == 1, d
assert d['order_ok'] == 1, d
assert d['pct_order_ok'] == 50, d
"
  # restaurar logs reales si existían
  if [[ -f "$FIXDIR/disc.bak" ]]; then cp "$FIXDIR/disc.bak" "$disc"; else rm -f "$disc"; fi
  if [[ -f "$FIXDIR/dod.bak" ]]; then cp "$FIXDIR/dod.bak" "$dod"; else rm -f "$dod"; fi
  rm -f output/turn-sdlc-report-WTEST.md
}

@test "sin logs existentes → reporte vacío pero válido (exit 0)" {
  mkdir -p output/learning-loop output/turn-sdlc
  local disc="output/learning-loop/discovery-order.jsonl"
  local dod="output/turn-sdlc/dod-gate.jsonl"
  cp "$disc" "$FIXDIR/disc.bak" 2>/dev/null || true
  cp "$dod" "$FIXDIR/dod.bak" 2>/dev/null || true
  rm -f "$disc" "$dod"

  run bash "$SCRIPT" --window WTEST
  [[ "$status" -eq 0 ]]
  [[ -f output/turn-sdlc-report-WTEST.md ]]
  grep -q "Turnos observados | 0" output/turn-sdlc-report-WTEST.md

  if [[ -f "$FIXDIR/disc.bak" ]]; then cp "$FIXDIR/disc.bak" "$disc"; else rm -f "$disc"; fi
  if [[ -f "$FIXDIR/dod.bak" ]]; then cp "$FIXDIR/dod.bak" "$dod"; else rm -f "$dod"; fi
  rm -f output/turn-sdlc-report-WTEST.md
}

@test "input inválido → exit 2" {
  run bash "$SCRIPT" --badflag
  [[ "$status" -eq 2 ]]
}
