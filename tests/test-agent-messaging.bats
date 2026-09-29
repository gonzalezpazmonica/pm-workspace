#!/usr/bin/env bats
# Skill agent-messaging — bus local agente→agente con receipts (SE-347 lección PMA).
# Ref: docs/propuestas/SE-376 quality debt burn-down; skill .claude/skills/agent-messaging/SKILL.md

SCRIPT="scripts/agent-messaging.sh"

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
  TMPD=$(mktemp -d)
  export SAVIA_MSG_DIR="$TMPD/msg"
}

teardown() {
  rm -rf "$TMPD"
  unset SAVIA_MSG_DIR
}

@test "script es estricto (set -uo pipefail) y sintácticamente válido" {
  bash -n "$SCRIPT"
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "send entrega en inbox y ledger con receipt queued y devuelve solo el id" {
  run bash "$SCRIPT" send --to worker --role child --message "hola" --from lead
  [ "$status" -eq 0 ]
  local id; id=$(printf '%s\n' "$output" | head -1)
  [[ "$id" == m-* ]]
  python3 -c "import json,sys; d=json.loads(open(sys.argv[1]).readline()); assert d['id']==sys.argv[2] and d['status']=='queued' and d['role']=='child' and d['from']=='lead'" \
    "$SAVIA_MSG_DIR/inbox/worker.jsonl" "$id"
  grep -q "\"id\":\"$id\"" "$SAVIA_MSG_DIR/ledger.jsonl"
}

@test "list muestra el mensaje y --unread lo oculta tras ack" {
  local id; id=$(bash "$SCRIPT" send --to worker --message "tarea 1" 2>/dev/null)
  run bash "$SCRIPT" list --inbox worker
  [[ "$output" == *"tarea 1"* ]]
  run bash "$SCRIPT" ack --id "$id"
  [ "$status" -eq 0 ]
  [[ "$output" == *"-> read"* ]]
  run bash "$SCRIPT" list --inbox worker --unread
  [[ "$output" == *"sin mensajes pendientes"* ]]
}

@test "ack actualiza el receipt canónico del ledger (status read + ack_at)" {
  local id; id=$(bash "$SCRIPT" send --to worker --message "x" 2>/dev/null)
  bash "$SCRIPT" ack --id "$id" >/dev/null
  run bash "$SCRIPT" status --id "$id"
  [ "$status" -eq 0 ]
  [[ "$output" == *"status=read"* ]]
  [[ "$output" != *"ack_at= "* ]]
}

@test "broadcast copia el mensaje en todas las inbox conocidas con su destinatario" {
  bash "$SCRIPT" send --to a --message "init" >/dev/null 2>&1
  bash "$SCRIPT" send --to b --message "init" >/dev/null 2>&1
  run bash "$SCRIPT" send --to all --broadcast --role steer --message "parad"
  [ "$status" -eq 0 ]
  grep -q '"to":"a".*"message":"parad"' "$SAVIA_MSG_DIR/inbox/a.jsonl"
  grep -q '"to":"b".*"message":"parad"' "$SAVIA_MSG_DIR/inbox/b.jsonl"
}

@test "role inválido se rechaza sin escribir nada" {
  run bash "$SCRIPT" send --to worker --role admin --message "x"
  [ "$status" -eq 2 ]
  [ ! -e "$SAVIA_MSG_DIR/ledger.jsonl" ]
}

@test "empty message o sin --to se rechaza con exit 2" {
  run bash "$SCRIPT" send --to worker --message ""
  [ "$status" -eq 2 ]
  run bash "$SCRIPT" send --message "x"
  [ "$status" -eq 2 ]
}

@test "receptor con separadores de ruta se rechaza (sin escritura fuera de inbox)" {
  run bash "$SCRIPT" send --to "../escape" --message "x"
  [ "$status" -eq 2 ]
  [ ! -e "$SAVIA_MSG_DIR/escape.jsonl" ]
  run bash "$SCRIPT" send --to "a/b" --message "x"
  [ "$status" -eq 2 ]
}

@test "mensaje con tabulador y comillas produce JSONL válido y listable" {
  run bash "$SCRIPT" send --to worker --message $'col1\tcol2 "citado" \\ fin'
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; [json.loads(l) for l in open(sys.argv[1])]" "$SAVIA_MSG_DIR/inbox/worker.jsonl"
  run bash "$SCRIPT" list --inbox worker
  [ "$status" -eq 0 ]
  [[ "$output" == *"citado"* ]]
}

@test "ack y status de id nonexistent fallan con exit distinto de 0" {
  bash "$SCRIPT" send --to worker --message "x" >/dev/null 2>&1
  run bash "$SCRIPT" ack --id m-nonexistent
  [ "$status" -ne 0 ]
  run bash "$SCRIPT" status --id m-nonexistent
  [ "$status" -ne 0 ]
  [[ "$output" == *"no encontrado"* ]]
}

@test "list de inbox vacía o zero mensajes no falla" {
  run bash "$SCRIPT" list --inbox nadie
  [ "$status" -eq 0 ]
  [[ "$output" == *"sin mensajes"* ]]
}

@test "stat cuenta inboxes y mensajes del ledger" {
  bash "$SCRIPT" send --to a --message "1" >/dev/null 2>&1
  bash "$SCRIPT" send --to b --message "2" >/dev/null 2>&1
  run bash "$SCRIPT" stat
  [ "$status" -eq 0 ]
  [[ "$output" == *"inboxes: 2"* ]]
  [[ "$output" == *"mensajes: 2"* ]]
}
