#!/usr/bin/env bats
# SE-336 S3 — discovery-order-telemetry: orden de descubrimiento por turno
# Spec: docs/specs/SE-336-turn-sdlc.spec.md (AC-06, AC-07)

HOOK=".claude/hooks/discovery-order-telemetry.sh"

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
  export SAVIA_DISCOVERY_TELEMETRY=on
  FIXDIR=$(mktemp -d)
  export SAVIA_DISCOVERY_TELEMETRY_LOG_DIR="$FIXDIR/log"
  export TMPDIR="$FIXDIR/tmp"
  mkdir -p "$TMPDIR"
}

teardown() {
  rm -rf "$FIXDIR"
}

tool_call() {
  local tool="$1" prompt="$2" session="$3"
  echo "{\"tool_name\":\"$tool\",\"session_id\":\"$session\",\"prompt_text\":\"$prompt\"}"
}

@test "AC-06a: turno grep-first → order_ok=false" {
  local s="t1"
  rm -f "$TMPDIR"/discovery-order-$s.state
  bash "$HOOK" <<< "$(tool_call grep "buscar SAGI" $s)" >/dev/null
  bash "$HOOK" <<< "$(tool_call grep "buscar SAGI" $s)" >/dev/null
  bash "$HOOK" <<< "$(tool_call grep "buscar SAGI" $s)" >/dev/null
  bash "$HOOK" <<< "$(tool_call savia-vaults_vault_search "buscar SAGI" $s)" >/dev/null
  [[ -f "$SAVIA_DISCOVERY_TELEMETRY_LOG_DIR/discovery-order.jsonl" ]]
  grep -q '"order_ok":"false"' "$SAVIA_DISCOVERY_TELEMETRY_LOG_DIR/discovery-order.jsonl"
}

@test "AC-06b: turno vault-first → order_ok=true" {
  local s="t2"
  rm -f "$TMPDIR"/discovery-order-$s.state
  bash "$HOOK" <<< "$(tool_call savia-vaults_vault_search "buscar SAGI" $s)" >/dev/null
  [[ -f "$SAVIA_DISCOVERY_TELEMETRY_LOG_DIR/discovery-order.jsonl" ]]
  grep -q '"order_ok":"true"' "$SAVIA_DISCOVERY_TELEMETRY_LOG_DIR/discovery-order.jsonl"
}

@test "AC-06c: turno solo-escritura → n/a (consolidado por ventana)" {
  local s="t3"
  rm -f "$TMPDIR"/discovery-order-$s.state
  bash "$HOOK" <<< "$(tool_call edit "editar fichero" $s)" >/dev/null
  bash "$HOOK" <<< "$(tool_call bash "correr tests" $s)" >/dev/null
  # sin knowledge tool: no consolida línea todavía (espera ventana o knowledge)
  # al superar MAX_TOOLS con puro write/exec, el siguiente turno arranca limpio
  for i in $(seq 1 13); do
    bash "$HOOK" <<< "$(tool_call bash "correr tests $i" $s)" >/dev/null
  done
  # tras ventana agotada, siguiente tool knowledge en turno nuevo → ok
  bash "$HOOK" <<< "$(tool_call savia-vaults_vault_search "nueva pregunta" $s)" >/dev/null
  grep -q '"order_ok":"true"' "$SAVIA_DISCOVERY_TELEMETRY_LOG_DIR/discovery-order.jsonl"
}

@test "AC-06d: 3 filesearch seguidos sin knowledge → order_ok=false" {
  local s="t4"
  rm -f "$TMPDIR"/discovery-order-$s.state
  bash "$HOOK" <<< "$(tool_call glob "buscar md" $s)" >/dev/null
  bash "$HOOK" <<< "$(tool_call read "fichero" $s)" >/dev/null
  bash "$HOOK" <<< "$(tool_call grep "patron" $s)" >/dev/null
  grep -q '"order_ok":"false"' "$SAVIA_DISCOVERY_TELEMETRY_LOG_DIR/discovery-order.jsonl"
}

@test "AC-07: JSONL no contiene el prompt en claro (solo query_hash)" {
  local s="t5"
  rm -f "$TMPDIR"/discovery-order-$s.state
  bash "$HOOK" <<< "$(tool_call savia-vaults_vault_search "SECRETO-MARCADOR-QWERTY789" $s)" >/dev/null
  [[ -f "$SAVIA_DISCOVERY_TELEMETRY_LOG_DIR/discovery-order.jsonl" ]]
  ! grep -q "SECRETO-MARCADOR-QWERTY789" "$SAVIA_DISCOVERY_TELEMETRY_LOG_DIR/discovery-order.jsonl"
  grep -q '"query_hash"' "$SAVIA_DISCOVERY_TELEMETRY_LOG_DIR/discovery-order.jsonl"
}

@test "master switch off → exit 0 sin log" {
  local s="t6"
  rm -f "$TMPDIR"/discovery-order-$s.state
  run env SAVIA_DISCOVERY_TELEMETRY=off bash "$HOOK" <<< "$(tool_call grep "x" $s)"
  [[ "$status" -eq 0 ]]
  [[ ! -f "$SAVIA_DISCOVERY_TELEMETRY_LOG_DIR/discovery-order.jsonl" ]]
}

@test "tool_name vacío → exit 0 silencioso" {
  run bash "$HOOK" <<< '{"session_id":"t7"}'
  [[ "$status" -eq 0 ]]
}
