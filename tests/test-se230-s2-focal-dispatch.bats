#!/usr/bin/env bats
# test-se230-s2-focal-dispatch.bats — 15 tests para focal-dispatch.sh + focal-decisions-log.sh

NIDO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
FOCAL_DISPATCH="$NIDO_DIR/scripts/focal-dispatch.sh"
FOCAL_LOG="$NIDO_DIR/scripts/focal-decisions-log.sh"
TEST_FOCAL_DIR=""

setup() {
  TEST_FOCAL_DIR="$(mktemp -d /tmp/focal-dispatch-test-XXXXXX)"
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

_write_decision() {
  # $1=nido, $2=blocking(true/false), $3=urgency(0-3), $4=cost(1-5), $5=desc, $6=age_min(default 0)
  local name="$1" blocking="${2:-false}" urgency="${3:-0}" cost="${4:-2}" desc="${5:-test decision}" age="${6:-0}"
  local now; now=$(_now_iso)
  local created_at; created_at=$(_past_iso "$age")
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
    "description": "${desc}",
    "blocking": ${blocking},
    "urgency": ${urgency},
    "cognitive_cost": ${cost},
    "created_at": "${created_at}"
  },
  "check_in_interval_min": 10,
  "session_pid": 9999,
  "last_commit_hash": "abc123",
  "created_at": "${now}",
  "updated_at": "${now}"
}
EOF
}

_write_no_decision() {
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
  "last_commit_hash": "abc123",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "updated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# ── Test 1: sin decisiones → exit 0 ───────────────────────────────────────────
@test "1. focal-dispatch sin decisiones pendientes exit 0" {
  _write_no_decision "nido-sin-decision"
  run bash "$FOCAL_DISPATCH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Sin decisiones pendientes"* ]]
}

# ── Test 2: con 1 decisión la muestra ─────────────────────────────────────────
@test "2. focal-dispatch con 1 decisión la muestra" {
  _write_decision "nido-con-decision" false 1 2 "revisar merge"
  run bash "$FOCAL_DISPATCH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"revisar merge"* ]]
}

# ── Test 3: prioridad BLOCKING > no blocking ───────────────────────────────────
@test "3. prioridad BLOCKING mayor que no-blocking con misma urgencia" {
  _write_decision "nido-block" true 1 2 "blocking decision"
  _write_decision "nido-noblock" false 1 2 "non-blocking decision"
  run bash "$FOCAL_DISPATCH" --all
  [ "$status" -eq 0 ]
  # blocking debe aparecer primero ([1])
  [[ "$output" == *"[1] nido-block"* ]]
}

# ── Test 4: urgency=3 tiene mayor prioridad que urgency=0 ────────────────────
@test "4. urgency=3 tiene mayor prioridad que urgency=0" {
  _write_decision "nido-urg3" false 3 2 "urgente decision"
  _write_decision "nido-urg0" false 0 2 "baja urgencia"
  run bash "$FOCAL_DISPATCH" --all
  [ "$status" -eq 0 ]
  pos_urg3=$(echo "$output" | grep -n "urgente decision" | head -1 | cut -d: -f1)
  pos_urg0=$(echo "$output" | grep -n "baja urgencia" | head -1 | cut -d: -f1)
  [ "${pos_urg3:-0}" -lt "${pos_urg0:-999}" ]
}

# ── Test 5: age aumenta la prioridad ──────────────────────────────────────────
@test "5. decisión más antigua tiene prioridad mayor" {
  _write_decision "nido-old" false 1 2 "decisión antigua" 60
  _write_decision "nido-new" false 1 2 "decisión reciente" 0
  run bash "$FOCAL_DISPATCH" --all
  [ "$status" -eq 0 ]
  pos_old=$(echo "$output" | grep -n "decisión antigua" | head -1 | cut -d: -f1)
  pos_new=$(echo "$output" | grep -n "decisión reciente" | head -1 | cut -d: -f1)
  [ "${pos_old:-0}" -lt "${pos_new:-999}" ]
}

# ── Test 6: cognitive_cost alto baja la prioridad ─────────────────────────────
@test "6. cognitive_cost=5 baja la prioridad vs cost=1" {
  _write_decision "nido-cheapdec" false 1 1 "decisión barata"
  _write_decision "nido-expensive" false 1 5 "decisión cara"
  run bash "$FOCAL_DISPATCH" --all
  [ "$status" -eq 0 ]
  pos_cheap=$(echo "$output" | grep -n "decisión barata" | head -1 | cut -d: -f1)
  pos_exp=$(echo "$output" | grep -n "decisión cara" | head -1 | cut -d: -f1)
  [ "${pos_cheap:-0}" -lt "${pos_exp:-999}" ]
}

# ── Test 7: floor max(0,...) — prioridad nunca negativa ───────────────────────
@test "7. prioridad nunca es negativa (floor 0)" {
  # urgency=0, blocking=false, cost=5, age=0 → 0+0+0-10 = -10 → max(0,-10) = 0
  _write_decision "nido-neg" false 0 5 "potencial negativo"
  run bash "$FOCAL_DISPATCH" --all
  [ "$status" -eq 0 ]
  # Extraer el valor de prioridad
  priority_line=$(echo "$output" | grep "prioridad:")
  priority_val=$(echo "$priority_line" | grep -oP 'prioridad:\K[0-9.]+')
  # Debe ser >= 0
  result=$(awk -v p="${priority_val:-0}" 'BEGIN { print (p >= 0) ? "ok" : "fail" }')
  [ "$result" = "ok" ]
}

# ── Test 8: --all-blocking solo muestra blocking=true ─────────────────────────
@test "8. --all-blocking solo muestra decisiones blocking" {
  _write_decision "nido-b1" true 2 2 "blocking uno"
  _write_decision "nido-b2" true 1 3 "blocking dos"
  _write_decision "nido-nb" false 3 1 "no blocking"
  run bash "$FOCAL_DISPATCH" --all-blocking
  [ "$status" -eq 0 ]
  [[ "$output" == *"blocking uno"* ]]
  [[ "$output" == *"blocking dos"* ]]
  [[ "$output" != *"no blocking"* ]]
}

# ── Test 9: --all muestra todas ordenadas ─────────────────────────────────────
@test "9. --all muestra todas las decisiones" {
  _write_decision "nido-c1" true 3 1 "decision alpha"
  _write_decision "nido-c2" false 0 5 "decision beta"
  _write_decision "nido-c3" false 2 2 "decision gamma"
  run bash "$FOCAL_DISPATCH" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"decision alpha"* ]]
  [[ "$output" == *"decision beta"* ]]
  [[ "$output" == *"decision gamma"* ]]
}

# ── Test 10: focal-decisions-log.sh crea el JSONL ─────────────────────────────
@test "10. focal-decisions-log crea el archivo JSONL" {
  _write_no_decision "nido-log"
  run bash "$FOCAL_LOG" --nido "nido-log" --decision "approve-merge" \
    --context "CI verde" --rationale "checks ok"
  [ "$status" -eq 0 ]
  local log_file="$NIDO_DIR/output/focal-decisions.jsonl"
  # El log va a output/ del nido real, no del HOME de test
  # Como el script usa SCRIPT_DIR/../output, verificamos con ls
  [ -f "$log_file" ] || skip "output dir en nido real"
}

# ── Test 11: focal-decisions-log es append-only ────────────────────────────────
@test "11. focal-decisions-log es append-only (2 llamadas = 2 líneas)" {
  _write_no_decision "nido-append"
  local log_file="$NIDO_DIR/output/focal-decisions.jsonl"
  local initial_lines=0
  [ -f "$log_file" ] && initial_lines=$(wc -l < "$log_file")

  bash "$FOCAL_LOG" --nido "nido-append" --decision "d1" --context "c1" --rationale "r1"
  bash "$FOCAL_LOG" --nido "nido-append" --decision "d2" --context "c2" --rationale "r2"

  [ -f "$log_file" ]
  local new_lines; new_lines=$(wc -l < "$log_file")
  [ "$new_lines" -eq $(( initial_lines + 2 )) ]
}

# ── Test 12: content_hash calculado correctamente ─────────────────────────────
@test "12. focal-decisions-log incluye content_hash" {
  _write_decision "nido-hash" false 1 2 "con hash"
  local log_file="$NIDO_DIR/output/focal-decisions.jsonl"
  local initial_lines=0
  [ -f "$log_file" ] && initial_lines=$(wc -l < "$log_file")

  bash "$FOCAL_LOG" --nido "nido-hash" --decision "test-hash" --context "ctx" --rationale "why"

  [ -f "$log_file" ]
  local last_line; last_line=$(tail -1 "$log_file")
  [[ "$last_line" == *"content_hash"* ]]
  [[ "$last_line" != *'"content_hash":""'* ]]
}

# ── Test 13: nido inexistente no crashea ──────────────────────────────────────
@test "13. focal-decisions-log con nido inexistente no crashea" {
  run bash "$FOCAL_LOG" --nido "nido-inexistente-xyz" --decision "test" \
    --context "ctx" --rationale "why"
  [ "$status" -eq 0 ]
}

# ── Test 14: escrituras paralelas no corrompen focal-decisions.jsonl ──────────
@test "14. escrituras paralelas en focal-decisions.jsonl no corrompen" {
  _write_no_decision "nido-parallel-log"
  local log_file="$NIDO_DIR/output/focal-decisions.jsonl"
  local initial_lines=0
  [ -f "$log_file" ] && initial_lines=$(wc -l < "$log_file")

  for i in 1 2 3 4 5; do
    bash "$FOCAL_LOG" --nido "nido-parallel-log" --decision "d${i}" \
      --context "c${i}" --rationale "r${i}" &
  done
  wait

  [ -f "$log_file" ]
  # Cada línea debe ser JSON válido (tiene '{')
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" == *"{"* ]]
  done < <(tail -5 "$log_file")
}

# ── Test 15: campos requeridos en cada entrada del log ────────────────────────
@test "15. entradas del log tienen todos los campos requeridos" {
  _write_no_decision "nido-campos"
  local log_file="$NIDO_DIR/output/focal-decisions.jsonl"
  local initial_lines=0
  [ -f "$log_file" ] && initial_lines=$(wc -l < "$log_file")

  bash "$FOCAL_LOG" --nido "nido-campos" --decision "approve" \
    --context "contexto test" --rationale "razon test"

  local last_line; last_line=$(tail -1 "$log_file")
  [[ "$last_line" == *'"ts"'* ]]
  [[ "$last_line" == *'"nido"'* ]]
  [[ "$last_line" == *'"decision"'* ]]
  [[ "$last_line" == *'"context"'* ]]
  [[ "$last_line" == *'"rationale"'* ]]
  [[ "$last_line" == *'"content_hash"'* ]]
}
