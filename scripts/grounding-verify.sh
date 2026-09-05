#!/usr/bin/env bash
# SE-387 C/F2 — Grounding fail-closed (SE-383 lección).
# Un veredicto que declara grounding DEBE referenciar eventos reales del trace.
# Uso: grounding-verify.sh <trace.jsonl> <veredicto.json>
# fail-closed: trace ausente/vacío/inconsistente => REJECT_UNGROUNDED (exit 2).
set -uo pipefail
TRACE="${1:-}"; VERD="${2:-}"
[[ -f "$VERD" ]] || { echo "REJECT_UNGROUNDED: sin veredicto"; exit 2; }
if ! grep -q '"grounded": *true' "$VERD"; then echo "PASS: veredicto sin grounding (no exige trace)"; exit 0; fi
[[ -f "$TRACE" ]] || { echo "REJECT_UNGROUNDED: veredicto grounded sin trace"; exit 2; }
[[ -s "$TRACE" ]] || { echo "REJECT_UNGROUNDED: trace vacío"; exit 2; }
# cada grounding (campo simple o array) debe existir en el trace
GONE=$(jq -r '[.grounded_on // empty] + [.groundings[]?.id // empty] | .[]' "$VERD" 2>/dev/null | sort -u)
if [[ -z "$GONE" ]]; then echo "REJECT_UNGROUNDED: veredicto grounded sin referencias a eventos"; exit 2; fi
while IFS= read -r eid; do
  [[ -z "$eid" ]] && continue
  grep -q "$eid" "$TRACE" || { echo "REJECT_UNGROUNDED: $eid no existe en trace"; exit 2; }
done <<< "$GONE"
echo "PASS: grounding verificado contra trace real"
exit 0
