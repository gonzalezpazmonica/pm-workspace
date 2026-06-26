#!/usr/bin/env bash
# scripts/workforce-analytics.sh — SPEC-SE-025 Agentic Workforce Analytics
set -uo pipefail
#
# Aggregates agent data sources into a tabular or JSON report.
#
# CLI:
#   bash scripts/workforce-analytics.sh [--since YYYY-MM-DD] [--json] [--format table|json|csv]
#
# Metrics:
#   agent_invocations     total per agent
#   avg_duration_min      mean duration per agent (minutes)
#   success_rate          fraction of runs without errors (0-1)
#   review_court_pass_rate fraction of PRs that passed Court without fixes
#   most_active_hour      hour of day with peak activity (0-23)
#   top_agents            top 5 by invocations
#
# Sources: output/agent-trace/*.jsonl, data/agent-actuals.jsonl, output/**/*.review.crc
# No external deps beyond stdlib + jq (optional) + python3 (optional)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/output}"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/data}"
# ANALYTICS_REPO_ROOT lets tests redirect data/ lookups
ANALYTICS_REPO_ROOT="${ANALYTICS_REPO_ROOT:-$(dirname "$DATA_DIR")}"

# ── Argument parsing ──────────────────────────────────────────────────────────

FORMAT="table"
SINCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)          FORMAT="json"; shift ;;
    --format)        FORMAT="$2"; shift 2 ;;
    --since)         SINCE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# //'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Python path ───────────────────────────────────────────────────────────────

ANALYTICS_PY="$SCRIPT_DIR/workforce-analytics.py"

# ── Main logic ────────────────────────────────────────────────────────────────

if command -v python3 >/dev/null 2>&1 && [[ -f "$ANALYTICS_PY" ]]; then
  SINCE_ARG=""
  [[ -n "$SINCE" ]] && SINCE_ARG="--since $SINCE"

  # shellcheck disable=SC2086
  METRICS=$(python3 "$ANALYTICS_PY" \
    --data-dir "$OUTPUT_DIR" \
    --repo-root "$ANALYTICS_REPO_ROOT" \
    $SINCE_ARG 2>/dev/null) || METRICS=""

  if [[ -z "$METRICS" ]]; then
    METRICS='{"metrics":{},"note":"no agent data found"}'
  fi

  # Check if any data was actually found
  TOTAL_INV=$(echo "$METRICS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(d.get('summary',{}).get('total_invocations',0))
" 2>/dev/null) || TOTAL_INV="0"

  if [[ "$TOTAL_INV" == "0" ]]; then
    METRICS='{"metrics":{},"note":"no agent data found"}'
  fi
else
  # Fallback: pure bash aggregation from agent-actuals.jsonl
  ACTUALS="$DATA_DIR/agent-actuals.jsonl"
  if [[ ! -f "$ACTUALS" ]]; then
    METRICS='{"metrics":{},"note":"no agent data found"}'
  else
    # Count schema_version 2 entries per agent using basic tools
    if command -v jq >/dev/null 2>&1; then
      METRICS=$(jq -s '
        [ .[] | select(.agent != null) ] as $runs |
        ($runs | group_by(.agent) | map({
          agent: .[0].agent,
          count: length,
          avg_dur: ([(.[].duration_s // 0)] | add / length / 60),
          pass_cnt: ([ .[] | select(.run_status == "completed") ] | length)
        })) as $agents |
        {
          agent_invocations: ($agents | map({key:.agent,value:.count}) | from_entries),
          avg_durations: ($agents | map({key:.agent,value:(.avg_dur|floor*100/100)}) | from_entries),
          success_rates: ($agents | map({key:.agent,value:(.pass_cnt/.count)}) | from_entries),
          top_agents: ($agents | sort_by(-.count) | .[0:5] | map(.agent)),
          summary: {total_invocations:($runs|length), computed_at: (now|todate)}
        }
      ' "$ACTUALS" 2>/dev/null) || METRICS='{"metrics":{},"note":"no agent data found"}'
    else
      METRICS='{"metrics":{},"note":"no agent data found"}'
    fi
  fi
fi

# ── Output formatting ─────────────────────────────────────────────────────────

case "$FORMAT" in
  json)
    echo "$METRICS"
    ;;
  csv)
    echo "agent,invocations,avg_duration_min,success_rate"
    echo "$METRICS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
inv=d.get('agent_invocations',{})
dur=d.get('avg_durations',{})
suc=d.get('success_rates',{})
for a in sorted(inv):
    print(f'{a},{inv[a]},{dur.get(a,0):.2f},{suc.get(a,0):.3f}')
" 2>/dev/null || echo "# no data"
    ;;
  table|*)
    echo "Agentic Workforce Analytics (SE-025)"
    echo "═══════════════════════════════════════════════════════════"
    if [[ -n "$SINCE" ]]; then
      echo "Period: since $SINCE"
    fi
    echo ""

    NOTE=$(echo "$METRICS" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('note',''))" 2>/dev/null || echo "")
    if [[ -n "$NOTE" ]]; then
      echo "$NOTE"
      exit 0
    fi

    echo "$METRICS" | python3 -c "
import json, sys

d = json.load(sys.stdin)
inv  = d.get('agent_invocations', {})
dur  = d.get('avg_durations', {})
suc  = d.get('success_rates', {})
mah  = d.get('most_active_hours', {})
top  = d.get('top_agents', [])
crt  = d.get('review_court', {})
summ = d.get('summary', {})

print('Agent Invocations')
print('-' * 55)
header = f'  {'Agent':<28} {'Runs':>6} {'AvgMin':>7} {'SuccRate':>9}'
print(header)
for a in sorted(inv, key=inv.__getitem__, reverse=True):
    print(f'  {a:<28} {inv[a]:>6} {dur.get(a,0):>7.1f} {suc.get(a,0)*100:>8.1f}%')
print()

print('Top 5 Agents by Invocations')
print('-' * 55)
for i, a in enumerate(top, 1):
    print(f'  {i}. {a}  ({inv.get(a,0)} runs)')
print()

crt_rate = crt.get('pass_rate')
crt_total = crt.get('total_prs', 0)
if crt_rate is not None:
    print(f'Code Review Court  pass_rate={crt_rate*100:.1f}%  prs={crt_total}')
else:
    print('Code Review Court  no .review.crc files found')
print()

print(f'Summary')
print('-' * 55)
print(f'  Total invocations : {summ.get(\"total_invocations\", 0)}')
print(f'  Total agents      : {summ.get(\"total_agents\", 0)}')
print(f'  Total CPU hours   : {summ.get(\"total_run_hours\", 0):.2f}')
print(f'  Computed at       : {summ.get(\"computed_at\", \"\")}')
" 2>/dev/null || echo "# no data"
    ;;
esac
