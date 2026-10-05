#!/usr/bin/env bash
# pr-wait.sh <PR> — espera la CI de un PR de forma honesta (CRIT-034).
# Antes de esperar comprueba que el PR sigue ABIERTO; liga la espera al head SHA y aborta si
# cambia (el resultado sería de otro commit). Salidas: 0 verde · 1 rojo · 2 uso · 3 no abierto
# (MERGED/CLOSED) · 4 el head cambió · 5 pendiente al agotar el plazo.
set -uo pipefail
GH="${GH:-gh}"; REPO="${PR_WAIT_REPO:-gonzalezpazmonica/savia}"
POLLS="${PR_WAIT_POLLS:-60}"; POLL_S="${PR_WAIT_POLL_S:-30}"
N="${1:-}"; [[ "$N" =~ ^[0-9]+$ ]] || { echo "uso: pr-wait.sh <PR>" >&2; exit 2; }

state=$($GH pr view "$N" -R "$REPO" --json state --jq .state 2>/dev/null)
[[ "$state" == OPEN ]] || { echo "#$N no está abierto ($state): no hay nada que esperar"; exit 3; }
sha=$($GH pr view "$N" -R "$REPO" --json headRefOid --jq .headRefOid 2>/dev/null)
[[ -n "$sha" ]] || { echo "#$N sin head SHA" >&2; exit 2; }

for _ in $(seq 1 "$POLLS"); do
  now=$($GH pr view "$N" -R "$REPO" --json headRefOid --jq .headRefOid 2>/dev/null)
  [[ "$now" == "$sha" ]] || { echo "#$N: el head cambió (${sha:0:9} → ${now:0:9}); vuelve a lanzar la espera"; exit 4; }
  out=$($GH pr checks "$N" -R "$REPO" 2>/dev/null)
  b=$(awk -F'\t' 'NF>1{print $2}' <<<"$out" | sort -u | paste -sd, -)
  if [[ -n "$b" && "$b" != *pending* ]]; then
    # Solo «pass» y «skipping» cuentan como verde; cancel, fail o cualquier estado desconocido es rojo.
    if grep -qvxE 'pass|skipping' <<<"$(tr ',' '\n' <<<"$b")"; then
      echo "#$N ${sha:0:9}: CI en rojo"; awk -F'\t' '$2!="pass" && $2!="skipping"{print "  " $2 ": " $1}' <<<"$out"; exit 1
    fi
    echo "#$N ${sha:0:9}: CI pass"; exit 0
  fi
  sleep "$POLL_S"
done
echo "#$N ${sha:0:9}: CI pendiente tras el plazo"; exit 5
