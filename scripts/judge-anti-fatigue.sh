#!/usr/bin/env bash
set -uo pipefail
# judge-anti-fatigue.sh — SE-273 S1: Anti-fatigue verdict tracking
#
# Tracks ignored judge verdicts and escalates when threshold is reached.
# A non-blocking judge whose verdicts are ignored N times within a window
# is escalated to blocking or flagged for human review.
#
# Usage:
#   bash scripts/judge-anti-fatigue.sh record <judge> <verdict_id> <action>
#     Records a verdict event. action = ignored (default) | acknowledged | acted
#
#   bash scripts/judge-anti-fatigue.sh check <judge>
#     Checks if a judge has exceeded the ignored-verdict threshold.
#     Exit 0 = under threshold. Exit 1 = over threshold (escalate).
#
#   bash scripts/judge-anti-fatigue.sh summary
#     Prints summary of all tracked judges.
#
#   bash scripts/judge-anti-fatigue.sh reset <judge>
#     Resets counter for a judge (after human acknowledgment).

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LEDGER="${ROOT}/output/anti-fatigue-ledger.jsonl"
MAX_IGNORED="${SAVIA_ANTI_FATIGUE_MAX_IGNORED:-3}"
WINDOW_HOURS="${SAVIA_ANTI_FATIGUE_WINDOW_HOURS:-24}"
ACTION="${1:-}"
JUDGE="${2:-}"
VERDICT_ID="${3:-unknown}"
VERDICT_ACTION="${4:-ignored}"

usage() {
  echo "Usage: $0 {record|check|summary|reset} <judge> [args...]" >&2
  echo "" >&2
  echo "  record <judge> <verdict_id> [action]  — record a verdict event (default action: ignored)" >&2
  echo "  check  <judge>                         — check escalation threshold" >&2
  echo "  summary                                — print all tracked judges" >&2
  echo "  reset  <judge>                         — reset after human acknowledgment" >&2
  exit 2
}

[[ "$MAX_IGNORED" =~ ^[0-9]+$ && "$WINDOW_HOURS" =~ ^[0-9]+$ ]] || {
  echo "ERROR: SAVIA_ANTI_FATIGUE_MAX_IGNORED y _WINDOW_HOURS deben ser enteros" >&2; exit 2; }

mkdir -p "$(dirname "$LEDGER")"

# Per-judge counts of verdict records inside the window and after the judge's
# latest reset (by ledger order). Event lines (escalated, reset) are never counted as verdicts.
# Prints one JSON object: {judge: {ignored, acknowledged, acted}}.
count_verdicts() {
  python3 - "$LEDGER" "$WINDOW_HOURS" <<'PYEOF'
import json, sys
from datetime import datetime, timedelta, timezone
ledger, window_h = sys.argv[1], int(sys.argv[2])
cutoff = (datetime.now(timezone.utc) - timedelta(hours=window_h)).strftime("%Y-%m-%dT%H:%M:%SZ")
entries = []
try:
    with open(ledger, encoding="utf-8") as f:
        for line in f:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if isinstance(d, dict):
                entries.append(d)
except FileNotFoundError:
    pass
counts = {}
for d in entries:  # ledger order: a reset clears what came before it
    j = d.get("judge", "unknown")
    if d.get("event") == "reset":
        counts.pop(j, None)
        continue
    action = d.get("action")
    if action not in ("ignored", "acknowledged", "acted") or d.get("ts", "") < cutoff:
        continue
    counts.setdefault(j, {"ignored": 0, "acknowledged": 0, "acted": 0})[action] += 1
print(json.dumps(counts))
PYEOF
}

ignored_for() {
  count_verdicts | python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], {}).get("ignored", 0))' "$1"
}

# ── Record ──────────────────────────────────────────────────────────────
do_record() {
  local judge="$1" verdict_id="$2" action="$3" ts ignored
  [[ -n "$judge" ]] || usage
  case "$action" in ignored|acknowledged|acted) ;; *)
    echo "ERROR: action inválida: $action (ignored|acknowledged|acted)" >&2; exit 2 ;;
  esac
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  python3 -c 'import json,sys; print(json.dumps({"ts": sys.argv[1], "judge": sys.argv[2], "verdict_id": sys.argv[3], "action": sys.argv[4]}))' \
    "$ts" "$judge" "$verdict_id" "$action" >> "$LEDGER"

  ignored=$(ignored_for "$judge")
  if [[ "$ignored" -ge "$MAX_IGNORED" ]]; then
    echo "[ANTI-FATIGA] $judge: $ignored ignored verdicts in ${WINDOW_HOURS}h → ESCALATE" >&2
    python3 -c 'import json,sys; print(json.dumps({"ts": sys.argv[1], "judge": sys.argv[2], "event": "escalated", "ignored_count": int(sys.argv[3]), "window_hours": int(sys.argv[4])}))' \
      "$ts" "$judge" "$ignored" "$WINDOW_HOURS" >> "$LEDGER"
    exit 1
  fi
}

# ── Check ────────────────────────────────────────────────────────────────
do_check() {
  local judge="$1" ignored
  [[ -n "$judge" ]] || usage
  ignored=$(ignored_for "$judge")
  if [[ "$ignored" -ge "$MAX_IGNORED" ]]; then
    echo "ESCALATE: $judge has $ignored ignored verdicts (threshold: $MAX_IGNORED, window: ${WINDOW_HOURS}h)" >&2
    exit 1
  fi
  echo "OK: $judge has $ignored/$MAX_IGNORED ignored verdicts"
}

# ── Summary ──────────────────────────────────────────────────────────────
do_summary() {
  [[ -f "$LEDGER" ]] || { echo "No anti-fatigue ledger found."; exit 0; }
  echo "=== Anti-Fatigue Ledger Summary ==="
  echo ""
  count_verdicts | python3 -c '
import json, sys
counts, max_ignored = json.load(sys.stdin), int(sys.argv[1])
for judge in sorted(counts):
    c = counts[judge]
    status = "ESCALATE" if c["ignored"] >= max_ignored else "OK"
    print("  %-10s %-40s ignored=%d acknowledged=%d acted=%d"
          % (status, judge, c["ignored"], c["acknowledged"], c["acted"]))
' "$MAX_IGNORED"
}

# ── Reset ────────────────────────────────────────────────────────────────
# Verdicts recorded up to this instant stop counting for the judge.
do_reset() {
  local judge="$1" ts
  [[ -n "$judge" ]] || usage
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  python3 -c 'import json,sys; print(json.dumps({"ts": sys.argv[1], "judge": sys.argv[2], "event": "reset", "reason": "human_acknowledgment"}))' \
    "$ts" "$judge" >> "$LEDGER"
  echo "Reset counter for $judge"
}

# ── Dispatch ─────────────────────────────────────────────────────────────
case "$ACTION" in
  record)  do_record "$JUDGE" "$VERDICT_ID" "$VERDICT_ACTION" ;;
  check)   do_check "$JUDGE" ;;
  summary) do_summary ;;
  reset)   do_reset "$JUDGE" ;;
  *)       usage ;;
esac
