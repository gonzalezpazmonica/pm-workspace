#!/usr/bin/env bash
# SE-387 C/F5 — Exactly-once effects: intent -> reservation -> gate -> execute -> receipt -> close.
# Uso: effect-reservation.sh reserve <op> <idempotency_key> | close <op> <key> | status <op> <key>
set -uo pipefail
DIR="${SAVIA_RESERVATIONS:-$HOME/.savia/reservations}"; mkdir -p "$DIR"
CMD="${1:-}"; OP="${2:-}"; KEY="${3:-}"; F="$DIR/${OP}__${KEY}.json"
case "$CMD" in
  reserve)
    if [[ -f "$F" ]]; then st=$(jq -r .state "$F"); echo "ALREADY_EXECUTED: efecto $OP/$KEY en estado $st — no se repite"; exit 3; fi
    printf '{"op":"%s","key":"%s","state":"reserved","ts":"%s"}\n' "$OP" "$KEY" "$(date -u +%FT%TZ)" > "$F"
    echo "reservation: $OP/$KEY (reserved)";;
  close)
    jq -c --arg st closed --arg ts "$(date -u +%FT%TZ)" '.state=$st | .closed_at=$ts' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
    echo "receipt: $OP/$KEY closed";;
  status) jq -r .state "$F" 2>/dev/null || echo "none";;
  *) echo "uso: reserve|close|status <op> <key>"; exit 1;;
esac
