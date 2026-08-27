#!/usr/bin/env bash
# agent-messaging.sh — Bus de mensajería local agente→agente (SE-347 lección PMA)
#
# Patrón extraído de Prime Agent (docs/long-running-agents.md, docs/rlm.md):
#   agent_message.send(..., receiver_role=auto|steer|follow_up) con receipts
#   delivered|queued y broadcast. PMA lo hace dentro del daemon; Savia lo hace
#   sobre ficheros JSONL en infraestructura propia (CRIT-001 — sin red).
#
# Modelo:
#   - inbox por receptor: ~/.savia/msg/inbox/<receptor>.jsonl
#   - ledger global:      ~/.savia/msg/ledger.jsonl
#   - mensaje: {id, ts, from, to, role, message, status, ack_at}
#   - receipts: queued (escrito en ledger) → delivered (en inbox) → read (ack)
#   - broadcast: to="all" → copia en TODAS las inbox conocidas.
#
# Uso:
#   agent-messaging.sh send --to <agente> [--role parent|child|steer|follow_up] --message "text" [--from <agente>]
#   agent-messaging.sh send --to all --broadcast --message "text" [--role steer]
#   agent-messaging.sh list --inbox <agente> [--unread]
#   agent-messaging.sh ack --id <msgid> [--as <agente>]
#   agent-messaging.sh status --id <msgid>
#   agent-messaging.sh stat
#
# Env: SAVIA_MSG_DIR (default ~/.savia/msg) — override para tests.

set -uo pipefail

MSG_DIR="${SAVIA_MSG_DIR:-$HOME/.savia/msg}"
INBOX_DIR="$MSG_DIR/inbox"
mkdir -p "$INBOX_DIR"
iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown"; }
mid() { echo "m-$(date +%s%N)-$$" 2>/dev/null || echo "m-$$"; }

# Escapa comillas dobles para JSONL (aproximación suficiente para textos cortos)
_json_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' '; }

# Lista de receptores conocidos = ficheros de inbox + 'all'
known_inboxes() { ls "$INBOX_DIR"/*.jsonl 2>/dev/null | xargs -r -n1 basename | sed 's/\.jsonl$//'; }

cmd_send() {
  local to="" role="follow_up" message="" from="${SAVIA_MSG_FROM:-savia}" broadcast=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --to) to="$2"; shift 2 ;;
      --role) role="$2"; shift 2 ;;
      --message) message="$2"; shift 2 ;;
      --from) from="$2"; shift 2 ;;
      --broadcast) broadcast=true; shift ;;
      *) shift ;;
    esac
  done
  [[ -n "$to" && -n "$message" ]] || { echo "ERROR: --to y --message required" >&2; return 2; }
  case "$role" in
    parent|child|steer|follow_up) ;;
    *) echo "ERROR: role inválido '$role' (parent|child|steer|follow_up)" >&2; return 2 ;;
  esac

  local id
  id=$(mid)
  local msg
  msg="{\"id\":\"$id\",\"ts\":\"$(iso_now)\",\"from\":\"$(_json_esc "$from")\",\"to\":\"$(_json_esc "$to")\",\"role\":\"$role\",\"message\":\"$(_json_esc "$message")\",\"status\":\"queued\",\"ack_at\":\"\"}"

  # ledger (append-only, receipt = queued)
  echo "$msg" >> "$MSG_DIR/ledger.jsonl"

  # entrega a inbox(es) — stdout SOLO con el id (scriptable); estado a stderr
  if $broadcast || [[ "$to" == "all" ]]; then
    local rec
    while IFS= read -r rec; do
      [[ -n "$rec" ]] || continue
      echo "$msg" | sed "s/\"to\":\"all\"/\"to\":\"$rec\"/" >> "$INBOX_DIR/$rec.jsonl"
    done < <(known_inboxes)
    echo "$id"
    echo "queued+delivered (broadcast: $(known_inboxes | wc -l) inboxes)" >&2
  else
    echo "$msg" >> "$INBOX_DIR/$to.jsonl"
    echo "$id"
    echo "queued+delivered -> $to" >&2
  fi
}

cmd_list() {
  local inbox="" unread=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --inbox) inbox="$2"; shift 2 ;;
      --unread) unread=true; shift ;;
      *) shift ;;
    esac
  done
  [[ -n "$inbox" ]] || { echo "ERROR: --inbox required" >&2; return 2; }
  [[ -f "$INBOX_DIR/$inbox.jsonl" ]] || { echo "(sin mensajes para $inbox)"; return 0; }
  python3 - "$INBOX_DIR/$inbox.jsonl" "$unread" <<'PY'
import json,sys
f,unread=sys.argv[1],sys.argv[2]=='True'
n=0
for l in open(f):
    d=json.loads(l)
    if unread and d.get('status')=='read': continue
    n+=1
    print(f"{d['id']}\t{d['from']}->{d['to']}\t[{d['role']}]\t{d['status']}\t{d['message'][:80]}")
if n==0: print("(sin mensajes pendientes)")
PY
}

cmd_ack() {
  local id="" as=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      --as) as="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -n "$id" ]] || { echo "ERROR: --id required" >&2; return 2; }
  python3 - "$INBOX_DIR" "$MSG_DIR" "$id" "$(iso_now)" <<'PY'
import json,sys,glob,os
base,ledger_dir,mid,ts=sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4]
found=False
# 1) inbox del receptor: status -> read
for f in glob.glob(base+'/*.jsonl'):
    lines=[]
    for l in open(f):
        d=json.loads(l)
        if d.get('id')==mid:
            d['status']='read'; d['ack_at']=ts; found=True
        lines.append(json.dumps(d)+'\n')
    open(f,'w').writelines(lines)
# 2) ledger: mismo receipt (canónico para status --id)
ledger=os.path.join(ledger_dir,'ledger.jsonl')
if os.path.exists(ledger):
    lines=[]
    for l in open(ledger):
        d=json.loads(l)
        if d.get('id')==mid:
            d['status']='read'; d['ack_at']=ts; found=True
        lines.append(json.dumps(d)+'\n')
    open(ledger,'w').writelines(lines)
if found: print(f"ack {mid} -> read")
else: print(f"ERROR: mensaje {mid} no encontrado", file=sys.stderr); sys.exit(1)
PY
}

cmd_status() {
  local id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -n "$id" ]] || { echo "ERROR: --id required" >&2; return 2; }
  grep -h "$id" "$MSG_DIR/ledger.jsonl" 2>/dev/null | python3 -c "
import json,sys
for l in sys.stdin:
    d=json.loads(l)
    if d['id']=='$id':
        print(f\"{d['id']} from={d['from']} to={d['to']} role={d['role']} status={d['status']} ack_at={d.get('ack_at','')}\")
        sys.exit(0)
print('no encontrado'); sys.exit(1)"
}

cmd_stat() {
  local inboxes msgs
  inboxes=$(known_inboxes | wc -l)
  msgs=$(grep -c . "$MSG_DIR/ledger.jsonl" 2>/dev/null || echo 0)
  echo "inboxes: $inboxes | mensajes: $msgs | dir: $MSG_DIR"
}

case "${1:-help}" in
  send) shift; cmd_send "$@" ;;
  list) shift; cmd_list "$@" ;;
  ack) shift; cmd_ack "$@" ;;
  status) shift; cmd_status "$@" ;;
  stat) cmd_stat ;;
  help|--help|-h)
    sed -n '2,24p' "${BASH_SOURCE[0]}" | grep -E '^#\s+agent-|^#\s+  ' | sed 's/^#//' ;;
  *)
    echo "Uso: agent-messaging.sh {send|list|ack|status|stat}" >&2
    exit 2 ;;
esac
