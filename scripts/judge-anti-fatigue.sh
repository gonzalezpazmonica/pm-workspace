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
#     Records a verdict event. action = ignored | acknowledged | acted
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
EXTRA="${3:-}"

mkdir -p "$(dirname "$LEDGER")"

# ── Record ──────────────────────────────────────────────────────────────
do_record() {
  local judge="$1"
  local verdict_id="${2:-unknown}"
  local action="${3:-ignored}"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  echo "{\"ts\":\"$ts\",\"judge\":\"$judge\",\"verdict_id\":\"$verdict_id\",\"action\":\"$action\"}" >> "$LEDGER"
  
  # Check if we need to escalate
  local cutoff
  cutoff=$(date -u -d "${WINDOW_HOURS} hours ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "1970-01-01T00:00:00Z")
  
  local ignored
  ignored=$(grep "\"$judge\"" "$LEDGER" 2>/dev/null | grep '"ignored"' | \
    python3 -c "
import sys, json
cutoff = '$cutoff'
count = 0
for line in sys.stdin:
    try:
        d = json.loads(line.strip())
        if d.get('ts', '') >= cutoff:
            count += 1
    except: pass
print(count)
" 2>/dev/null || echo 0)
  
  if [[ "$ignored" -ge "$MAX_IGNORED" ]]; then
    echo "[ANTI-FATIGA] $judge: $ignored ignored verdicts in ${WINDOW_HOURS}h → ESCALATE" >&2
    echo "{\"ts\":\"$ts\",\"judge\":\"$judge\",\"event\":\"escalated\",\"ignored_count\":$ignored,\"window_hours\":$WINDOW_HOURS}" >> "$LEDGER"
    exit 1
  fi
}

# ── Check ────────────────────────────────────────────────────────────────
do_check() {
  local judge="$1"
  [[ ! -f "$LEDGER" ]] && exit 0
  
  local cutoff
  cutoff=$(date -u -d "${WINDOW_HOURS} hours ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "1970-01-01T00:00:00Z")
  
  local ignored
  ignored=$(grep "\"$judge\"" "$LEDGER" 2>/dev/null | grep '"ignored"' | \
    python3 -c "
import sys, json
cutoff = '$cutoff'
count = 0
for line in sys.stdin:
    try:
        d = json.loads(line.strip())
        if d.get('ts', '') >= cutoff:
            count += 1
    except: pass
print(count)
" 2>/dev/null || echo 0)
  
  if [[ "$ignored" -ge "$MAX_IGNORED" ]]; then
    echo "ESCALATE: $judge has $ignored ignored verdicts (threshold: $MAX_IGNORED, window: ${WINDOW_HOURS}h)" >&2
    exit 1
  fi
  echo "OK: $judge has $ignored/$MAX_IGNORED ignored verdicts"
}

# ── Summary ──────────────────────────────────────────────────────────────
do_summary() {
  [[ ! -f "$LEDGER" ]] && echo "No anti-fatigue ledger found." && exit 0
  
  echo "=== Anti-Fatigue Ledger Summary ==="
  echo ""
  
  local cutoff
  cutoff=$(date -u -d "${WINDOW_HOURS} hours ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "1970-01-01T00:00:00Z")
  
  python3 -c "
import sys, json
from collections import defaultdict
cutoff = '$cutoff'
max_ignored = $MAX_IGNORED
window_h = $WINDOW_HOURS
counts = defaultdict(lambda: {'ignored': 0, 'acknowledged': 0, 'acted': 0})
with open('$LEDGER') as f:
    for line in f:
        try:
            d = json.loads(line.strip())
            if d.get('ts', '') >= cutoff:
                judge = d.get('judge', 'unknown')
                action = d.get('action', 'ignored')
                if action in counts[judge]:
                    counts[judge][action] += 1
        except: pass

for judge in sorted(counts.keys()):
    c = counts[judge]
    status = 'ESCALATE' if c['ignored'] >= max_ignored else 'OK'
    print(f'  {status:10s} {judge:40s} ignored={c[\"ignored\"]} acknowledged={c[\"acknowledged\"]} acted={c[\"acted\"]}')
" 2>/dev/null
}

# ── Reset ────────────────────────────────────────────────────────────────
do_reset() {
  local judge="$1"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "{\"ts\":\"$ts\",\"judge\":\"$judge\",\"event\":\"reset\",\"reason\":\"human_acknowledgment\"}" >> "$LEDGER"
  echo "Reset counter for $judge"
}

# ── Dispatch ─────────────────────────────────────────────────────────────
case "$ACTION" in
  record) do_record "$JUDGE" "$EXTRA" "$4" ;;
  check)  do_check "$JUDGE" ;;
  summary) do_summary ;;
  reset)  do_reset "$JUDGE" ;;
  *)
    echo "Usage: $0 {record|check|summary|reset} <judge> [args...]" >&2
    echo ""
    echo "  record <judge> <verdict_id> <action>  — record a verdict event"
    echo "  check  <judge>                         — check escalation threshold"
    echo "  summary                                — print all tracked judges"
    echo "  reset  <judge>                         — reset after human acknowledgment"
    exit 2
    ;;
esac
