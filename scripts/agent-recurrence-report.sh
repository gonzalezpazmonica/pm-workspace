#!/usr/bin/env bash
# agent-recurrence-report.sh — SE-272 Slice 3: Identifies recurring agent requests
# Ref: docs/propuestas/SE-272-servicio-gestionado.md
#
# Identifies recurring agent requests resolvable by automation or upstream fix.
# Highlights patterns for improvement.
#
# Usage:
#   agent-recurrence-report.sh analyze   [--window 24h|7d|30d] [--min-occurrences N]
#   agent-recurrence-report.sh patterns  [--window 24h|7d|30d]
#   agent-recurrence-report.sh suggest   [--window 24h|7d|30d]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/data}"
mkdir -p "$DATA_DIR"
REQUEST_LOG="${REQUEST_LOG:-$DATA_DIR/agent-request-identity.jsonl}"
EFFORT_LOG="${EFFORT_LOG:-$DATA_DIR/agent-effort-measurements.jsonl}"
RECURRENCE_OUTPUT="${RECURRENCE_OUTPUT:-$REPO_ROOT/output}"

_usage() {
  cat >&2 <<'EOF'
Usage: agent-recurrence-report.sh <subcommand> [options]

Subcommands:
  analyze   [--window 24h|7d|30d] [--min-occurrences N] [--input FILE]
            Analyze request log for recurring patterns.
  patterns  [--window 24h|7d|30d] [--input FILE]
            Show top recurring request patterns.
  suggest   [--window 24h|7d|30d] [--input FILE]
            Suggest automation or upstream fixes for recurring patterns.

Exit codes:
  0 — success
  2 — usage error
EOF
  exit 2
}

_die() {
  echo "ERROR: $*" >&2
  exit 2
}

_py() { python3 -c "$@"; }
_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

_parse_window_s() {
  local window="$1"
  case "$window" in
    24h) echo 86400 ;;
    7d)  echo 604800 ;;
    30d) echo 2592000 ;;
    *)   _die "Unknown window: ${window}. Use 24h|7d|30d" ;;
  esac
}

# ── Subcommand: analyze ──────────────────────────────────────────────────────
cmd_analyze() {
  local window="7d" min_occurrences="3" input_file="$REQUEST_LOG"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window)           window="$2";           shift 2 ;;
      --min-occurrences)  min_occurrences="$2";  shift 2 ;;
      --input)            input_file="$2";        shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  local window_s
  window_s=$(_parse_window_s "$window")
  local now_s
  now_s="$(date +%s)"
  local cutoff_s=$(( now_s - window_s ))

  if [[ ! -f "$input_file" ]]; then
    echo "No request data at ${input_file}"
    exit 0
  fi

  _py "
import json, time, collections

window_s = ${window_s}
cutoff_s = ${cutoff_s}
min_occ = ${min_occurrences}

agent_ids = collections.Counter()
origins = collections.Counter()
decisions = collections.Counter()

try:
    with open('${input_file}') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except:
                continue
            ts = rec.get('timestamp', '')
            try:
                ts_s = int(time.mktime(time.strptime(ts, '%Y-%m-%dT%H:%M:%SZ')))
            except:
                continue
            if ts_s < cutoff_s:
                continue
            agent_id = rec.get('agent_id', '')
            if agent_id:
                agent_ids[agent_id] += 1
            origins[rec.get('origin', 'unknown')] += 1
            decisions[rec.get('decision', 'unknown')] += 1
except FileNotFoundError:
    pass

total = sum(origins.values())

print(f'=== RECURRENCE ANALYSIS (window=${window}, min_occurrences=${min_occurrences}) ===')
print(f'Total requests: {total}')
print('')
print('--- By Origin ---')
for o, c in sorted(origins.items()):
    print(f'  {o}: {c}')
print('')
print('--- By Decision ---')
for d, c in sorted(decisions.items()):
    print(f'  {d}: {c}')
print('')
print('--- Recurring Agent Identities ---')
recurring = [(a, c) for a, c in agent_ids.items() if c >= min_occ]
if recurring:
    for a, c in sorted(recurring, key=lambda x: -x[1]):
        print(f'  {a}: {c} requests (recurring)')
else:
    print('  None detected')
print('')
if recurring:
    print('NOTE: Recurring agent requests should be reviewed for automation or upstream fix.')
"
}

# ── Subcommand: patterns ─────────────────────────────────────────────────────
cmd_patterns() {
  local window="7d" input_file="$REQUEST_LOG"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window) window="$2";      shift 2 ;;
      --input)  input_file="$2";  shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  local window_s
  window_s=$(_parse_window_s "$window")
  local now_s
  now_s="$(date +%s)"
  local cutoff_s=$(( now_s - window_s ))

  if [[ ! -f "$input_file" ]]; then
    echo "No request data at ${input_file}"
    exit 0
  fi

  echo "═══════════════════════════════════════════════"
  echo "RECURRENCE PATTERNS — window=${window}"
  echo "═══════════════════════════════════════════════"

  _py "
import json, time, collections

window_s = ${window_s}
cutoff_s = ${cutoff_s}

hourly = collections.Counter()
daily = collections.Counter()
agent_hits = collections.Counter()

try:
    with open('${input_file}') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except:
                continue
            ts = rec.get('timestamp', '')
            try:
                ts_s = int(time.mktime(time.strptime(ts, '%Y-%m-%dT%H:%M:%SZ')))
            except:
                continue
            if ts_s < cutoff_s:
                continue
            hour = ts.split('T')[1][:2]
            day = ts.split('T')[0]
            hourly[hour] += 1
            daily[day] += 1
            agent_id = rec.get('agent_id', '')
            if agent_id:
                agent_hits[agent_id] += 1
except FileNotFoundError:
    pass

print('')
print('--- Peak Hours (UTC) ---')
for h, c in hourly.most_common(8):
    bar = '#' * min(c, 50)
    print(f'  {h}:00 | {bar} ({c})')

print('')
print('--- Daily Volume ---')
for d, c in sorted(daily.items()):
    bar = '#' * min(c, 40)
    print(f'  {d} | {bar} ({c})')

print('')
print('--- Top Agent Requestors ---')
for a, c in agent_hits.most_common(10):
    print(f'  {a}: {c}')
"
}

# ── Subcommand: suggest ──────────────────────────────────────────────────────
cmd_suggest() {
  local window="7d" input_file="$REQUEST_LOG"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window) window="$2";      shift 2 ;;
      --input)  input_file="$2";  shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  local window_s
  window_s=$(_parse_window_s "$window")
  local now_s
  now_s="$(date +%s)"
  local cutoff_s=$(( now_s - window_s ))

  if [[ ! -f "$input_file" ]]; then
    echo "No request data at ${input_file}"
    exit 0
  fi

  echo "═══════════════════════════════════════════════"
  echo "IMPROVEMENT SUGGESTIONS — window=${window}"
  echo "═══════════════════════════════════════════════"

  _py "
import json, time, collections

window_s = ${window_s}
cutoff_s = ${cutoff_s}

agent_ids = collections.Counter()
reject_reasons = collections.Counter()

try:
    with open('${input_file}') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except:
                continue
            ts = rec.get('timestamp', '')
            try:
                ts_s = int(time.mktime(time.strptime(ts, '%Y-%m-%dT%H:%M:%SZ')))
            except:
                continue
            if ts_s < cutoff_s:
                continue
            agent_id = rec.get('agent_id', '')
            if agent_id:
                agent_ids[agent_id] += 1
            if rec.get('decision') == 'REJECT':
                reject_reasons[rec.get('reason', 'unknown')] += 1
except FileNotFoundError:
    pass

total_requests = sum(agent_ids.values())
suggestions = []

for agent_id, count in agent_ids.most_common():
    if count >= 10:
        suggestions.append({
            'agent_id': agent_id,
            'count': count,
            'pct': round(100 * count / max(total_requests, 1), 1),
            'suggestion': f'Agent \"{agent_id}\" made {count} requests ({round(100*count/max(total_requests,1),1)}%). Consider bulk API endpoint or batch processing.',
            'action': 'implement_batch_endpoint',
        })
    elif count >= 5:
        suggestions.append({
            'agent_id': agent_id,
            'count': count,
            'pct': round(100 * count / max(total_requests, 1), 1),
            'suggestion': f'Agent \"{agent_id}\" made {count} requests. Review for caching or rate-limit tuning.',
            'action': 'review_thresholds',
        })

for reason, count in reject_reasons.most_common():
    if count >= 5:
        suggestions.append({
            'reason': reason,
            'count': count,
            'suggestion': f'Rejection reason \"{reason}\" occurred {count} times. Consider pre-validation on external platform side.',
            'action': 'add_pre_validation',
        })

if suggestions:
    for i, s in enumerate(suggestions, 1):
        print(f\"\nSuggestion #{i}:\")
        print(f\"  Type: {s.get('action', 'review')}\")
        print(f\"  Detail: {s.get('suggestion', 'N/A')}\")
        if 'agent_id' in s:
            print(f\"  Agent: {s['agent_id']} ({s['count']} requests, {s['pct']}%)\")
        if 'reason' in s:
            print(f\"  Reason: {s['reason']} ({s['count']} occurrences)\")
else:
    print('No improvement suggestions. Patterns inconclusive.')
"
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
[[ $# -lt 1 ]] && _usage

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  analyze)   cmd_analyze   "$@" ;;
  patterns)  cmd_patterns  "$@" ;;
  suggest)   cmd_suggest   "$@" ;;
  *)         _usage ;;
esac
