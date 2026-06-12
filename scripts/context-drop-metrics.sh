#!/usr/bin/env bash
set -uo pipefail
# context-drop-metrics.sh — SE-221 Slice 2 — Drop-After-Use metrics
# Lee output/context-drop-audit.jsonl y reporta total_tokens_saved, n_stubs,
# n_keeps, n_drops, pct_saved.
#
# Spec: docs/propuestas/SE-221-inverted-security-patterns-as-context-engineering.md (AC-11)
#
# Uso:
#   scripts/context-drop-metrics.sh              # human-readable
#   scripts/context-drop-metrics.sh --json       # JSON
#   scripts/context-drop-metrics.sh --since=YYYY-MM-DD

JSON=0
SINCE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${SAVIA_WORKSPACE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
AUDIT_LOG="${CONTEXT_DROP_AUDIT_LOG:-${WORKSPACE}/output/context-drop-audit.jsonl}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    --since=*) SINCE="${1#*=}"; shift ;;
    --since) SINCE="${2:-}"; shift 2 ;;
    --log) AUDIT_LOG="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -f "$AUDIT_LOG" ]]; then
  if [[ "$JSON" -eq 1 ]]; then
    echo '{"total_tokens_saved":0,"n_stubs":0,"n_keeps":0,"n_drops":0,"n_total":0,"pct_saved":0,"audit_log":"missing"}'
  else
    echo "Audit log no existe: $AUDIT_LOG"
    echo "total_tokens_saved=0 n_stubs=0 n_keeps=0 n_drops=0"
  fi
  exit 0
fi

# Filtro por fecha
FILTER='.'
if [[ -n "$SINCE" ]]; then
  FILTER="select(.ts >= \"${SINCE}\")"
fi

# Agregaciones via jq
RESULT=$(jq -s --arg since "$SINCE" '
  map(
    if $since == "" then . else select(.ts >= $since) end
  ) |
  {
    n_total: length,
    n_stubs: ([.[] | select(.verdict == "STUB")] | length),
    n_keeps: ([.[] | select(.verdict == "KEEP")] | length),
    n_drops: ([.[] | select(.verdict == "DROP")] | length),
    total_tokens_saved: ([.[] | .tokens_saved_est // 0] | add // 0),
    by_tool: ([.[] | .tool] | group_by(.) | map({tool: .[0], count: length})),
    by_tier: ([.[] | .tier] | group_by(.) | map({tier: .[0], count: length}))
  }
' "$AUDIT_LOG" 2>/dev/null || echo '{}')

# Estimacion pct_saved: % de operaciones que fueron STUB o DROP
N_TOTAL=$(echo "$RESULT" | jq -r '.n_total // 0')
N_REDUCED=$(echo "$RESULT" | jq -r '(.n_stubs // 0) + (.n_drops // 0)')
PCT=0
if [[ "$N_TOTAL" -gt 0 ]]; then
  # Forzar locale C para usar punto decimal (no coma)
  PCT=$(LC_ALL=C awk -v r="$N_REDUCED" -v t="$N_TOTAL" 'BEGIN { printf "%.1f", (r/t)*100 }')
fi

if [[ "$JSON" -eq 1 ]]; then
  echo "$RESULT" | jq --arg pct "$PCT" '. + {pct_saved: ($pct | tonumber)}'
else
  echo "Context Drop-After-Use metrics"
  echo "  log:       $AUDIT_LOG"
  if [[ -n "$SINCE" ]]; then echo "  since:     $SINCE"; fi
  echo "  total:     $N_TOTAL"
  echo "  STUB:      $(echo "$RESULT" | jq -r '.n_stubs')"
  echo "  KEEP:      $(echo "$RESULT" | jq -r '.n_keeps')"
  echo "  DROP:      $(echo "$RESULT" | jq -r '.n_drops')"
  echo "  tokens_saved_est: $(echo "$RESULT" | jq -r '.total_tokens_saved')"
  echo "  pct_saved: ${PCT}%"
fi

exit 0
