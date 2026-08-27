#!/usr/bin/env bash
# savia-goals.sh — Goals durables + heartbeats claimed-due (SE-347 lección PMA)
#
# Patrón extraído de Prime Agent (docs/long-running-agents.md, docs/rlm-runtime.md):
#   - GOAL = objetivo con presupuesto (tokens + wall-clock) y estado durable;
#     SOLO `complete` marca éxito (goal.complete() es el único final válido).
#   - HEARTBEAT claimed-due: un tick pendiente NO se reentrega tras crash
#     (si quedó marcado como claimed por un runner muerto, otro runner no lo
#     reclama); ticks perdidos coalescen (solo se entrega el más reciente).
#
# CRIT-001: ledger local en ~/.savia/goals (nunca en repo, nunca a cloud).
#
# Uso:
#   savia-goals.sh create --title "X" [--budget-tokens N] [--budget-seconds N]
#   savia-goals.sh list [--active|--all]
#   savia-goals.sh get <id>
#   savia-goals.sh progress <id> [--tokens N] [--seconds N] [--note "text"]
#   savia-goals.sh complete <id>
#   savia-goals.sh abandon <id>
#   savia-goals.sh heartbeat add --every <secs> --prompt "text" [--name N]
#   savia-goals.sh heartbeat claim-due [--now EPOCH]
#   savia-goals.sh heartbeat list
#   savia-goals.sh stat
#
# Env: SAVIA_GOALS_DIR (default ~/.savia/goals) — override para tests.

set -uo pipefail

GOALS_DIR="${SAVIA_GOALS_DIR:-$HOME/.savia/goals}"
mkdir -p "$GOALS_DIR"
now_epoch() { date +%s 2>/dev/null || echo 0; }
iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown"; }
uuid() { echo "g-$(date +%s%N)-$$" 2>/dev/null || echo "g-$$"; }

goal_file() { echo "$GOALS_DIR/$1.json"; }

_goal_json() {
  local id="$1"
  cat > "$GOALS_DIR/$id.json"
}

cmd_create() {
  local title="" bt="" bs=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) title="$2"; shift 2 ;;
      --budget-tokens) bt="$2"; shift 2 ;;
      --budget-seconds) bs="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -n "$title" ]] || { echo "ERROR: --title required" >&2; return 2; }
  local id
  id=$(uuid)
  _goal_json "$id" <<EOF
{"id":"$id","title":"$title","budget_tokens":${bt:-0},"budget_seconds":${bs:-0},"status":"active","progress":{"tokens":0,"seconds":0,"continuations":0},"notes":[],"created_at":"$(iso_now)","updated_at":"$(iso_now)"}
EOF
  echo "$id"
}

cmd_list() {
  local mode="${1:-active}"
  for f in "$GOALS_DIR"/*.json; do
    [[ -e "$f" ]] || continue
    local id status title bt ptokens bsecs psecs
    id=$(basename "$f" .json)
    status=$(grep -oP '"status":\s*"\K[^"]+' "$f" | head -1)
    title=$(grep -oP '"title":\s*"\K[^"]+' "$f" | head -1)
    bt=$(grep -oP '"budget_tokens":\s*\K[0-9]+' "$f" | head -1)
    ptokens=$(grep -oP '"progress":\{"tokens":\s*\K[0-9]+' "$f" | head -1)
    bsecs=$(grep -oP '"budget_seconds":\s*\K[0-9]+' "$f" | head -1)
    psecs=$(grep -oP '"seconds":\s*\K[0-9]+' "$f" | head -1)
    [[ "$mode" == "active" && "$status" != "active" ]] && continue
    [[ "$mode" == "all" ]] || [[ "$mode" == "active" ]] || [[ "$mode" == "completed" && "$status" == "completed" ]] || continue
    printf '%-14s %-10s tokens %s/%s secs %s/%s %s\n' "$id" "$status" "$ptokens" "$bt" "$psecs" "$bsecs" "$title"
  done
}

cmd_get() {
  local id="${1:-}"
  [[ -n "$id" ]] || { echo "ERROR: goal id required" >&2; return 2; }
  [[ -f "$(goal_file "$id")" ]] || { echo "ERROR: goal $id no existe" >&2; return 1; }
  cat "$(goal_file "$id")"
  echo
}

cmd_progress() {
  local id="${1:-}" tokens=0 secs=0 note=""
  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tokens) tokens="$2"; shift 2 ;;
      --seconds) secs="$2"; shift 2 ;;
      --note) note="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  local f
  f="$(goal_file "$id")"
  [[ -f "$f" ]] || { echo "ERROR: goal $id no existe" >&2; return 1; }
  python3 - "$f" "$tokens" "$secs" "$note" <<'PY'
import json,sys,datetime
f,to,se,note = sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),sys.argv[4]
d=json.load(open(f))
if d.get('status')!='active':
    print(f"ERROR: goal {d['id']} no activo ({d.get('status')})", file=sys.stderr); sys.exit(1)
p=d.setdefault('progress',{'tokens':0,'seconds':0,'continuations':0})
p['tokens']=p.get('tokens',0)+to
p['seconds']=p.get('seconds',0)+se
p['continuations']=p.get('continuations',0)+1
if note: d.setdefault('notes',[]).append(note)
d['updated_at']=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
json.dump(d,open(f,'w'))
print(f"{d['id']}: tokens={p['tokens']}/{d.get('budget_tokens',0)} secs={p['seconds']}/{d.get('budget_seconds',0)} continuations={p['continuations']}")
PY
}

cmd_complete() {
  local id="${1:-}"
  [[ -n "$id" ]] || { echo "ERROR: goal id required" >&2; return 2; }
  local f
  f="$(goal_file "$id")"
  [[ -f "$f" ]] || { echo "ERROR: goal $id no existe" >&2; return 1; }
  python3 - "$f" <<'PY'
import json,sys,datetime
f=sys.argv[1]; d=json.load(open(f))
d['status']='completed'
d['completed_at']=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
json.dump(d,open(f,'w'))
print(f"goal {d['id']} COMPLETED (único final válido)")
PY
}

cmd_abandon() {
  local id="${1:-}"
  [[ -n "$id" ]] || { echo "ERROR: goal id required" >&2; return 2; }
  local f
  f="$(goal_file "$id")"
  [[ -f "$f" ]] || { echo "ERROR: goal $id no existe" >&2; return 1; }
  python3 -c "
import json,sys
f=sys.argv[1]; d=json.load(open(f)); d['status']='abandoned'; json.dump(d,open(f,'w')); print(f\"goal {d['id']} ABANDONED\")" "$f"
}

# ── Heartbeats (claimed-due) ────────────────────────────────────────────
HB_FILE="$GOALS_DIR/.heartbeats.jsonl"

hb_add() {
  local every="" prompt="" name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --every) every="$2"; shift 2 ;;
      --prompt) prompt="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -n "$every" && -n "$prompt" ]] || { echo "ERROR: --every and --prompt required" >&2; return 2; }
  local id
  id=$(uuid)
  {
    echo "{\"id\":\"$id\",\"name\":\"${name:-hb-$id}\",\"every\":$every,\"prompt\":\"$prompt\",\"last_claimed\":0,\"last_ts\":\"\"}"
  } >> "$HB_FILE"
  echo "$id"
}

# claim-due: devuelve los heartbeats pendientes (no claimed o cuyo intervalo
# venció), los marca como claimed en el instante (claimed-due → un runner
# muerto NO bloquea; tampoco se reentrega dos veces el mismo tick). Si hubo
# varios ticks perdidos, coalescen al más reciente.
hb_claim_due() {
  local now
  now="${1:-$(now_epoch)}"
  python3 - "$HB_FILE" "$now" "$GOALS_DIR" <<'PY'
import json,sys,os,datetime
hb_file,now,goals_dir=sys.argv[1],int(sys.argv[2]),sys.argv[3]
if not os.path.exists(hb_file): sys.exit(0)
lines=[json.loads(l) for l in open(hb_file) if l.strip()]
due=[]
for h in lines:
    due_at=h['last_claimed']+h['every']
    if now>=due_at:
        h['last_claimed']=now
        h['last_ts']=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        due.append(h)
open(hb_file,'w').write(''.join(json.dumps(h)+'\n' for h in lines))
for h in due:
    print(f"{h['id']}\t{h['name']}\t{h['prompt']}")
PY
}

hb_list() {
  [[ -f "$HB_FILE" ]] || return 0
  python3 -c "
import json,sys
for l in open(sys.argv[1]):
    h=json.loads(l); print(f\"{h['id']}\t{h['name']}\tevery={h['every']}s\tlast={h['last_claimed']}\t{h['prompt']}\")" "$HB_FILE"
}

cmd_stat() {
  local goals hbs
  goals=$(ls "$GOALS_DIR"/*.json 2>/dev/null | wc -l)
  hbs=$(grep -c . "$HB_FILE" 2>/dev/null || echo 0)
  echo "goals: $goals | heartbeats: $hbs | dir: $GOALS_DIR"
}

case "${1:-help}" in
  create) shift; cmd_create "$@" ;;
  list) shift; cmd_list "${1:-active}" ;;
  get) shift; cmd_get "$@" ;;
  progress) shift; cmd_progress "$@" ;;
  complete) shift; cmd_complete "$@" ;;
  abandon) shift; cmd_abandon "$@" ;;
  stat) cmd_stat ;;
  heartbeat)
    shift
    case "${1:-list}" in
      add) shift; hb_add "$@" ;;
      claim-due)
        shift
        now="$(now_epoch)"
        if [[ "${1:-}" == "--now" ]]; then now="${2:?}"; shift 2; fi
        hb_claim_due "$now"
        ;;
      list) shift; hb_list ;;
      *) echo "heartbeat: add | claim-due | list" >&2; exit 2 ;;
    esac ;;
  help|--help|-h)
    sed -n '2,28p' "${BASH_SOURCE[0]}" | grep -E '^#\s+savia-goals|^#\s+  ' | sed 's/^#//' ;;
  *)
    echo "Uso: savia-goals.sh {create|list|get|progress|complete|abandon|heartbeat|stat}" >&2
    exit 2 ;;
esac
