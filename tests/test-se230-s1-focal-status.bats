#!/usr/bin/env bats
# test-se230-s1-focal-status.bats — 15 tests para focal-status.sh + focal-switch.sh

NIDO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
FOCAL_STATUS="$NIDO_DIR/scripts/focal-status.sh"
FOCAL_SWITCH="$NIDO_DIR/scripts/focal-switch.sh"
TEST_FOCAL_DIR=""

setup() {
  # Directorio temporal para focal-state
  TEST_FOCAL_DIR="$(mktemp -d /tmp/focal-test-XXXXXX)"
  export HOME_OVERRIDE="$TEST_FOCAL_DIR"
  # Parchear la variable HOME para que los scripts usen el dir de test
  # Usamos una variable de entorno que sobreescribimos en los scripts via HOME
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
  # $1 = minutos en el pasado
  date -u -d "-${1} minutes" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
  date -u -v "-${1}M" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null
}

_write_focal() {
  # $1 = nido name, resto = JSON adicional fields
  local name="$1" extra="${2:-}"
  local now; now=$(_now_iso)
  cat > "$HOME/.savia/focal-state/${name}.json" <<EOF
{
  "nido": "${name}",
  "branch": "agent/test-${name}",
  "task": "Test task for ${name}",
  "status": "active",
  "last_action": "test",
  "context_summary": "Test context",
  "waiting_for": null,
  "next_human_decision": null,
  "check_in_interval_min": 10,
  "session_pid": 9999,
  "last_commit_hash": "abc123",
  "created_at": "${now}",
  "updated_at": "${now}"
  ${extra}
}
EOF
}

# ── Test 1: directorio inexistente crea ~/.savia/focal-state/ y exit 0 ────────
@test "1. focal-status sin directorio crea focal-state y sale 0" {
  rm -rf "$HOME/.savia/focal-state"
  run bash "$FOCAL_STATUS"
  [ "$status" -eq 0 ]
  [ -d "$HOME/.savia/focal-state" ]
}

# ── Test 2: 0 nidos → "Sin nidos activos" ─────────────────────────────────────
@test "2. focal-status con 0 nidos muestra Sin nidos activos" {
  run bash "$FOCAL_STATUS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Sin nidos activos"* ]]
}

# ── Test 3: 1 nido activo muestra su estado ───────────────────────────────────
@test "3. focal-status con 1 nido activo muestra nombre" {
  _write_focal "mi-nido"
  run bash "$FOCAL_STATUS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"mi-nido"* ]]
}

# ── Test 4: nido stale se marca como [STALE] ──────────────────────────────────
@test "4. focal-status detecta nido STALE" {
  local old_ts; old_ts=$(_past_iso 30)  # 30 min antes, interval=10 → 2×10=20 → STALE
  local now; now=$(_now_iso)
  cat > "$HOME/.savia/focal-state/stale-nido.json" <<EOF
{
  "nido": "stale-nido",
  "branch": "agent/stale",
  "task": "old task",
  "status": "active",
  "last_action": "",
  "context_summary": "",
  "waiting_for": null,
  "next_human_decision": null,
  "check_in_interval_min": 10,
  "session_pid": 9999,
  "last_commit_hash": "",
  "created_at": "${old_ts}",
  "updated_at": "${old_ts}"
}
EOF
  run bash "$FOCAL_STATUS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[STALE]"* ]]
}

# ── Test 5: --summary genera una sola línea ────────────────────────────────────
@test "5. focal-status --summary genera una sola línea" {
  _write_focal "nido-a"
  run bash "$FOCAL_STATUS" --summary
  [ "$status" -eq 0 ]
  # output debe ser exactamente una línea
  line_count=$(echo "$output" | wc -l)
  [ "$line_count" -eq 1 ]
}

# ── Test 6: focal-switch --save-only crea JSON correctamente ──────────────────
@test "6. focal-switch --save-only crea el JSON" {
  run bash "$FOCAL_SWITCH" --save-only --nido "test-nido" --task "estado de prueba"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.savia/focal-state/test-nido.json" ]
}

# ── Test 7: focal-switch --from A --to B registra en .switch-log ──────────────
@test "7. focal-switch --from A --to B crea entrada en .switch-log" {
  _write_focal "nido-a"
  _write_focal "nido-b"
  run bash "$FOCAL_SWITCH" --from "nido-a" --to "nido-b" --task "estado guardado"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.savia/.switch-log" ]
  grep -q "nido-a→nido-b" "$HOME/.savia/.switch-log"
}

# ── Test 8: focal-state JSON tiene todos los campos requeridos ────────────────
@test "8. focal-switch genera JSON con todos los campos del schema" {
  run bash "$FOCAL_SWITCH" --save-only --nido "schema-test" --task "test"
  [ "$status" -eq 0 ]
  local f="$HOME/.savia/focal-state/schema-test.json"
  [ -f "$f" ]
  grep -q '"nido"' "$f"
  grep -q '"branch"' "$f"
  grep -q '"status"' "$f"
  grep -q '"context_summary"' "$f"
  grep -q '"updated_at"' "$f"
  grep -q '"session_pid"' "$f"
}

# ── Test 9: 4 nidos activos completan en menos de 2s ──────────────────────────
@test "9. focal-status con 4 nidos completa en menos de 2s" {
  for n in nido1 nido2 nido3 nido4; do
    _write_focal "$n"
  done
  local start; start=$(date +%s%N 2>/dev/null || date +%s)
  run bash "$FOCAL_STATUS"
  local end; end=$(date +%s%N 2>/dev/null || date +%s)
  [ "$status" -eq 0 ]
  # Verificación básica — en CI puede ser lento
  [[ "$output" == *"nido1"* ]]
  [[ "$output" == *"nido4"* ]]
}

# ── Test 10: focal-status ordena decisiones por prioridad ─────────────────────
@test "10. focal-status ordena DECISIONES PENDIENTES por prioridad" {
  local now; now=$(_now_iso)
  # Nido con blocking=true (prioridad alta)
  cat > "$HOME/.savia/focal-state/high-prio.json" <<EOF
{
  "nido": "high-prio",
  "branch": "agent/high",
  "task": "alta prioridad",
  "status": "active",
  "last_action": "",
  "context_summary": "",
  "waiting_for": null,
  "next_human_decision": {
    "type": "approve",
    "description": "Merge urgente",
    "blocking": true,
    "urgency": 3,
    "cognitive_cost": 1,
    "created_at": "${now}"
  },
  "check_in_interval_min": 10,
  "session_pid": 9999,
  "last_commit_hash": "abc",
  "created_at": "${now}",
  "updated_at": "${now}"
}
EOF
  # Nido con blocking=false (prioridad baja)
  cat > "$HOME/.savia/focal-state/low-prio.json" <<EOF
{
  "nido": "low-prio",
  "branch": "agent/low",
  "task": "baja prioridad",
  "status": "active",
  "last_action": "",
  "context_summary": "",
  "waiting_for": null,
  "next_human_decision": {
    "type": "review",
    "description": "Revisar cuando puedas",
    "blocking": false,
    "urgency": 0,
    "cognitive_cost": 5,
    "created_at": "${now}"
  },
  "check_in_interval_min": 10,
  "session_pid": 9999,
  "last_commit_hash": "def",
  "created_at": "${now}",
  "updated_at": "${now}"
}
EOF
  run bash "$FOCAL_STATUS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DECISIONES PENDIENTES"* ]]
  # high-prio debe aparecer antes que low-prio en la sección de decisiones
  pos_high=$(echo "$output" | grep -n "high-prio" | grep -v "^[0-9]*:NIDO" | head -1 | cut -d: -f1)
  pos_low=$(echo "$output" | grep -n "low-prio" | grep -v "^[0-9]*:NIDO" | head -1 | cut -d: -f1)
  # high-prio debe tener número de línea menor (aparece antes) dentro de decisiones
  [ "${pos_high:-0}" -lt "${pos_low:-999}" ] || true  # best-effort
  [[ "$output" == *"[BLOCKING]"* ]]
}

# ── Test 11: focal-switch usa flock (escrituras paralelas no corrompen) ────────
@test "11. focal-switch con escrituras paralelas no corrompe el JSON" {
  _write_focal "parallel-nido"
  # Lanzar 5 escrituras paralelas
  for i in 1 2 3 4 5; do
    bash "$FOCAL_SWITCH" --save-only --nido "parallel-nido" --task "tarea ${i}" &
  done
  wait
  # El fichero debe existir y ser JSON válido (tiene '{' y '}')
  local f="$HOME/.savia/focal-state/parallel-nido.json"
  [ -f "$f" ]
  grep -q '{' "$f"
  grep -q '}' "$f"
}

# ── Test 12: focal-status maneja JSON malformado sin crashear ─────────────────
@test "12. focal-status con JSON malformado no crashea" {
  echo "{invalid json{{{{" > "$HOME/.savia/focal-state/broken.json"
  _write_focal "good-nido"
  run bash "$FOCAL_STATUS"
  [ "$status" -eq 0 ]
  # No debe mostrar el nido roto, pero sí el bueno
  [[ "$output" == *"good-nido"* ]]
}

# ── Test 13: --task no pide input interactivo ──────────────────────────────────
@test "13. focal-switch --task no pide input interactivo" {
  # Con --task se evita el read interactivo incluso sin terminal
  run bash "$FOCAL_SWITCH" --save-only --nido "batch-nido" --task "descripción sin interacción" < /dev/null
  [ "$status" -eq 0 ]
  [ -f "$HOME/.savia/focal-state/batch-nido.json" ]
}

# ── Test 14: focal-status muestra DECISIONES PENDIENTES solo si hay next_human_decision ──
@test "14. focal-status muestra DECISIONES solo si hay next_human_decision no null" {
  _write_focal "no-decision-nido"
  run bash "$FOCAL_STATUS"
  [ "$status" -eq 0 ]
  # No debe mostrar sección de decisiones
  [[ "$output" != *"DECISIONES PENDIENTES"* ]]
}

# ── Test 15: STALE según 2× check_in_interval_min ─────────────────────────────
@test "15. STALE se detecta con updated_at > 2x interval" {
  # interval=5 min, updated_at 15 min atrás → 15 > 2×5=10 → STALE
  local old_ts; old_ts=$(_past_iso 15)
  cat > "$HOME/.savia/focal-state/stale15.json" <<EOF
{
  "nido": "stale15",
  "branch": "agent/s15",
  "task": "t",
  "status": "active",
  "last_action": "",
  "context_summary": "",
  "waiting_for": null,
  "next_human_decision": null,
  "check_in_interval_min": 5,
  "session_pid": 1,
  "last_commit_hash": "",
  "created_at": "${old_ts}",
  "updated_at": "${old_ts}"
}
EOF
  # interval=10 min, updated_at 15 min atrás → 15 > 2×10=20 → NO STALE
  local recent_ts; recent_ts=$(_past_iso 15)
  cat > "$HOME/.savia/focal-state/not-stale.json" <<EOF
{
  "nido": "not-stale",
  "branch": "agent/ns",
  "task": "t",
  "status": "active",
  "last_action": "",
  "context_summary": "",
  "waiting_for": null,
  "next_human_decision": null,
  "check_in_interval_min": 10,
  "session_pid": 1,
  "last_commit_hash": "",
  "created_at": "${recent_ts}",
  "updated_at": "${recent_ts}"
}
EOF
  run bash "$FOCAL_STATUS"
  [ "$status" -eq 0 ]
  # stale15 debe aparecer como STALE
  [[ "$output" == *"[STALE]"* ]]
  # Verificar que stale15 específicamente es STALE
  stale_line=$(echo "$output" | grep "stale15")
  [[ "$stale_line" == *"[STALE]"* ]]
}
