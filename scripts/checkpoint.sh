#!/usr/bin/env bash
# SE-387 C/F4 — Durable orchestration checkpoint (local, ~/.savia/checkpoints/).
set -uo pipefail
DIR="${SAVIA_CHECKPOINTS:-$HOME/.savia/checkpoints}"; mkdir -p "$DIR"
CMD="${1:-}"; RUN="${2:-}"; F="$DIR/$RUN.json"
case "$CMD" in
  init)
    printf '{"run_id":"%s","spec_id":"%s","current_slice":"","completed_steps":[],"pending_steps":[],"artifact_refs":[],"receipts":[],"budget":{},"retry_count":0,"last_safe_checkpoint":"%s"}\n' \
      "$RUN" "${3:-}" "$(date -u +%FT%TZ)" > "$F"
    echo "checkpoint init: $F" ;;
  update)
    python3 -c "import json,sys;f,s,st,d=sys.argv[1:5];x=json.load(open(f));
x['completed_steps'].append(s) if st=='done' and s not in x['completed_steps'] else None;
x['pending_steps'].append(s) if st=='pending' and s not in x['pending_steps'] else None;
x['last_safe_checkpoint']=d or x['last_safe_checkpoint'];json.dump(x,open(f,'w'),indent=2);print('checkpoint update',s,st)" "$F" "${3:-}" "${4:-}" "${5:-}"
    ;;
  status)
    if [[ -f "$F" ]]; then
      jq -r '"run=\(.run_id) done=\(.completed_steps|join(",")) retry=\(.retry_count)"' "$F"
      exit 0
    else echo "sin checkpoint $RUN"; exit 1; fi ;;
  *) echo "uso: checkpoint.sh init|update|status <run_id>"; exit 1 ;;
esac
