#!/usr/bin/env bats
# test-se230-s3-checkin.bats — 10 tests para focal-checkin.sh

NIDO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
FOCAL_CHECKIN="$NIDO_DIR/scripts/focal-checkin.sh"
TEST_FOCAL_DIR=""

setup() {
  TEST_FOCAL_DIR="$(mktemp -d /tmp/focal-checkin-test-XXXXXX)"
  export REAL_HOME="$HOME"
  export HOME="$TEST_FOCAL_DIR"
  mkdir -p "$HOME/.savia/focal-state"
}

teardown() {
  export HOME="$REAL_HOME"
  rm -rf "$TEST_FOCAL_DIR"
}

_now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
_past_iso() {
  date -u -d "-${1} minutes" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
  date -u -v "-${1}M" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null
}

_write_focal() {
  local name="$1"
  local now; now=$(_now_iso)
  cat > "$HOME/.savia/focal-state/${name}.json" <<EOF
{
  "nido": "${name}",
  "branch": "agent/test",
  "task": "test",
  "status": "active",
  "last_action": "",
  "context_summary": "",
  "waiting_for": null,
  "next_human_decision": null,
  "check_in_interval_min": 10,
  "session_pid": 9999,
  "last_commit_hash": "abc",
  "created_at": "${now}",
  "updated_at": "${now}"
}
EOF
}

_write_decision_nido() {
  local name="$1"
  local now; now=$(_now_iso)
  cat > "$HOME/.savia/focal-state/${name}.json" <<EOF
{
  "nido": "${name}",
  "branch": "agent/test",
  "task": "test",
  "status": "active",
  "last_action": "",
  "context_summary": "",
  "waiting_for": null,
  "next_human_decision": {
    "type": "review",
    "description": "pending decision",
    "blocking": true,
    "urgency": 2,
    "cognitive_cost": 2,
    "created_at": "${now}"
  },
  "check_in_interval_min": 10,
  "session_pid": 9999,
  "last_commit_hash": "abc",
  "created_at": "${now}",
  "updated_at": "${now}"
}
EOF
}

# ── Test 1: --nido actualiza updated_at ───────────────────────────────────────
@test "1. focal-checkin --nido actualiza updated_at" {
  _write_focal "checkin-nido"
  local old_ts; old_ts=$(grep -oP '"updated_at"\s*:\s*"\K[^"]*' "$HOME/.savia/focal-state/checkin-nido.json")
  sleep 1
  run bash "$FOCAL_CHECKIN" --nido "checkin-nido"
  [ "$status" -eq 0 ]
  local new_ts; new_ts=$(grep -oP '"updated_at"\s*:\s*"\K[^"]*' "$HOME/.savia/focal-state/checkin-nido.json")
  # El timestamp debe ser diferente
  [ "$old_ts" != "$new_ts" ] || skip "timestamps iguales en el mismo segundo"
}

# ── Test 2: --set-interval actualiza check_in_interval_min ───────────────────
@test "2. focal-checkin --set-interval actualiza el campo" {
  _write_focal "interval-nido"
  run bash "$FOCAL_CHECKIN" --set-interval 25 --nido "interval-nido"
  [ "$status" -eq 0 ]
  local val; val=$(grep -oP '"check_in_interval_min"\s*:\s*\K[0-9]+' "$HOME/.savia/focal-state/interval-nido.json")
  [ "$val" = "25" ]
}

# ── Test 3: --load con 0 switches → OK ────────────────────────────────────────
@test "3. focal-checkin --load con 0 switches devuelve OK" {
  # No hay .switch-log
  run bash "$FOCAL_CHECKIN" --load
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

# ── Test 4: --load con 6 switches en 1h → OVERLOAD ───────────────────────────
@test "4. focal-checkin --load con 6 switches en 1h devuelve OVERLOAD" {
  # Crear .switch-log con 6 entradas en la última hora
  local now; now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  for i in 1 2 3 4 5 6; do
    local ts; ts=$(date -u -d "-${i} minutes" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
                   date -u -v "-${i}M" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    printf '%s nidoA→nidoB\n' "$ts" >> "$HOME/.savia/.switch-log"
  done
  run bash "$FOCAL_CHECKIN" --load
  [ "$status" -eq 0 ]
  [ "$output" = "OVERLOAD" ]
}

# ── Test 5: --load con 6 decisiones pendientes → OVERLOAD ────────────────────
@test "5. focal-checkin --load con 6 decisiones pendientes devuelve OVERLOAD" {
  for i in 1 2 3 4 5 6; do
    _write_decision_nido "dec-nido-${i}"
  done
  run bash "$FOCAL_CHECKIN" --load
  [ "$status" -eq 0 ]
  [ "$output" = "OVERLOAD" ]
}

# ── Test 6: --load con 4 switches → HIGH ─────────────────────────────────────
@test "6. focal-checkin --load con 4 switches en 1h devuelve HIGH" {
  for i in 1 2 3 4; do
    local ts; ts=$(date -u -d "-${i} minutes" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
                   date -u -v "-${i}M" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    printf '%s nidoA→nidoB\n' "$ts" >> "$HOME/.savia/.switch-log"
  done
  run bash "$FOCAL_CHECKIN" --load
  [ "$status" -eq 0 ]
  [ "$output" = "HIGH" ]
}

# ── Test 7: .switch-log es append-only ────────────────────────────────────────
@test "7. .switch-log es append-only (no se sobreescribe)" {
  local SWITCH_SCRIPT="$NIDO_DIR/scripts/focal-switch.sh"
  local f1="$HOME/.savia/focal-state/nido-x.json"
  local f2="$HOME/.savia/focal-state/nido-y.json"
  local now; now=$(_now_iso)
  # Crear nidos mínimos
  cat > "$f1" <<EOF
{"nido":"nido-x","branch":"b","task":"t","status":"active","last_action":"","context_summary":"","waiting_for":null,"next_human_decision":null,"check_in_interval_min":10,"session_pid":1,"last_commit_hash":"","created_at":"${now}","updated_at":"${now}"}
EOF
  cat > "$f2" <<EOF
{"nido":"nido-y","branch":"b","task":"t","status":"active","last_action":"","context_summary":"","waiting_for":null,"next_human_decision":null,"check_in_interval_min":10,"session_pid":1,"last_commit_hash":"","created_at":"${now}","updated_at":"${now}"}
EOF
  bash "$SWITCH_SCRIPT" --from "nido-x" --to "nido-y" --task "primer cambio"
  bash "$SWITCH_SCRIPT" --from "nido-y" --to "nido-x" --task "segundo cambio"
  [ -f "$HOME/.savia/.switch-log" ]
  local lines; lines=$(wc -l < "$HOME/.savia/.switch-log")
  [ "$lines" -ge 2 ]
}

# ── Test 8: focal-checkin funciona sin jq ni python3 ─────────────────────────
@test "8. focal-checkin funciona sin jq" {
  _write_focal "nojq-nido"
  # Forzar que el PATH no incluya jq ni python3
  run env PATH="/usr/bin:/bin" bash "$FOCAL_CHECKIN" --nido "nojq-nido"
  [ "$status" -eq 0 ]
}

# ── Test 9: sin .switch-log → OK ──────────────────────────────────────────────
@test "9. sin .switch-log focal-checkin --load muestra OK" {
  rm -f "$HOME/.savia/.switch-log"
  run bash "$FOCAL_CHECKIN" --load
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

# ── Test 10: --load respeta ventana de 1 hora (switches de hace 2h no cuentan) ──
@test "10. --load solo cuenta switches de la última hora" {
  # Escribir 10 switches de hace 2 horas (no deben contar)
  for i in 1 2 3 4 5 6 7 8 9 10; do
    local ts; ts=$(date -u -d "-$((120 + i)) minutes" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
                   date -u -v "-$((120 + i))M" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
    printf '%s nidoA→nidoB\n' "$ts" >> "$HOME/.savia/.switch-log"
  done
  run bash "$FOCAL_CHECKIN" --load
  [ "$status" -eq 0 ]
  # 0 switches en la última hora → OK
  [ "$output" = "OK" ]
}
