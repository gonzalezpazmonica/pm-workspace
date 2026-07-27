#!/usr/bin/env bash
# agent-effort-meter.sh — SE-272 Slice 3: Measure actual work not ticket count
# Ref: docs/propuestas/SE-272-servicio-gestionado.md
#
# Measures actual work (tokens, compute time, human intervention), not ticket count.
# Thousand trivial agent requests consume proportional budget.
#
# Usage:
#   agent-effort-meter.sh record    --identity ID --tokens-in N --tokens-out N --compute-s N [--human-intervention-s N]
#   agent-effort-meter.sh summary   --identity ID [--window 1h|24h|7d|30d]
#   agent-effort-meter.sh breakdown --identity ID [--window 1h|24h|7d|30d]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/data}"
mkdir -p "$DATA_DIR"
EFFORT_LOG="${EFFORT_LOG:-$DATA_DIR/agent-effort-measurements.jsonl}"

_usage() {
  cat >&2 <<'EOF'
Usage: agent-effort-meter.sh <subcommand> [options]

Subcommands:
  record    --identity ID --tokens-in N --tokens-out N --compute-s N [--human-intervention-s N]
            Record an effort measurement.
  summary   --identity ID [--window 1h|24h|7d|30d]
            Print effort summary for an identity.
  breakdown --identity ID [--window 1h|24h|7d|30d]
            Print detailed effort breakdown per request type.

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

# ── Parse window to seconds ──────────────────────────────────────────────────
_parse_window_s() {
  local window="$1"
  case "$window" in
    1h)  echo 3600 ;;
    24h) echo 86400 ;;
    7d)  echo 604800 ;;
    30d) echo 2592000 ;;
    *)   _die "Unknown window: ${window}. Use 1h|24h|7d|30d" ;;
  esac
}

# ── Subcommand: record ───────────────────────────────────────────────────────
cmd_record() {
  local identity="" tokens_in="0" tokens_out="0" compute_s="0" human_intervention_s="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --identity)              identity="$2";              shift 2 ;;
      --tokens-in)             tokens_in="$2";             shift 2 ;;
      --tokens-out)            tokens_out="$2";            shift 2 ;;
      --compute-s)             compute_s="$2";             shift 2 ;;
      --human-intervention-s)  human_intervention_s="$2";  shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$identity" ]] && _die "--identity is required"

  local ts
  ts="$(_now)"

  _py "
import json
record = {
    'timestamp': '${ts}',
    'identity': '${identity}',
    'tokens_in': ${tokens_in},
    'tokens_out': ${tokens_out},
    'compute_s': ${compute_s},
    'human_intervention_s': ${human_intervention_s},
}
with open('${EFFORT_LOG}', 'a') as fh:
    fh.write(json.dumps(record) + '\n')
" 2>/dev/null

  echo "RECORDED: identity=${identity} tokens_in=${tokens_in} tokens_out=${tokens_out} compute_s=${compute_s} human_s=${human_intervention_s}"
}

# ── Subcommand: summary ──────────────────────────────────────────────────────
cmd_summary() {
  local identity="" window="24h"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --identity) identity="$2"; shift 2 ;;
      --window)   window="$2";   shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$identity" ]] && _die "--identity is required"

  local window_s
  window_s=$(_parse_window_s "$window")
  local now_s
  now_s="$(date +%s)"
  local cutoff_s=$(( now_s - window_s ))

  if [[ ! -f "$EFFORT_LOG" ]]; then
    echo "IDENTITY: ${identity}"
    echo "WINDOW: ${window}"
    echo "REQUESTS: 0"
    echo "TOTAL_TOKENS_IN: 0"
    echo "TOTAL_TOKENS_OUT: 0"
    echo "TOTAL_COMPUTE_S: 0"
    echo "TOTAL_HUMAN_INTERVENTION_S: 0"
    echo "TRIVIAL_REQUESTS: 0"
    echo "EFFORT_RATIO: 0.0"
    exit 0
  fi

  _py "
import json, time

window_s = ${window_s}
now_s = ${now_s}
cutoff_s = ${cutoff_s}
identity = '${identity}'

total = 0
tokens_in = 0
tokens_out = 0
compute_s = 0
human_s = 0
trivial = 0  # requests with < 100 tokens and < 1s compute

try:
    with open('${EFFORT_LOG}') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except:
                continue
            if rec.get('identity') != identity:
                continue
            ts = rec.get('timestamp', '')
            try:
                ts_s = int(time.mktime(time.strptime(ts, '%Y-%m-%dT%H:%M:%SZ')))
            except:
                continue
            if ts_s < cutoff_s:
                continue
            total += 1
            ti = rec.get('tokens_in', 0)
            to = rec.get('tokens_out', 0)
            cs = rec.get('compute_s', 0)
            hs = rec.get('human_intervention_s', 0)
            tokens_in += ti
            tokens_out += to
            compute_s += cs
            human_s += hs
            if ti + to < 100 and cs < 1:
                trivial += 1
except FileNotFoundError:
    pass

effort_ratio = round((tokens_in + tokens_out + compute_s) / max(total, 1), 1)

print(f\"IDENTITY: {identity}\")
print(f\"WINDOW: ${window}\")
print(f\"REQUESTS: {total}\")
print(f\"TOTAL_TOKENS_IN: {tokens_in}\")
print(f\"TOTAL_TOKENS_OUT: {tokens_out}\")
print(f\"TOTAL_COMPUTE_S: {compute_s}\")
print(f\"TOTAL_HUMAN_INTERVENTION_S: {human_s}\")
print(f\"TRIVIAL_REQUESTS: {trivial}\")
print(f\"EFFORT_RATIO: {effort_ratio}\")
print(f\"HUMAN_INTERVENTION_RATIO: {round(human_s / max(compute_s, 0.001), 2)}\")
"
}

# ── Subcommand: breakdown ────────────────────────────────────────────────────
cmd_breakdown() {
  local identity="" window="24h"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --identity) identity="$2"; shift 2 ;;
      --window)   window="$2";   shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$identity" ]] && _die "--identity is required"

  local window_s
  window_s=$(_parse_window_s "$window")
  local now_s
  now_s="$(date +%s)"
  local cutoff_s=$(( now_s - window_s ))

  if [[ ! -f "$EFFORT_LOG" ]]; then
    echo "No effort data for identity: ${identity}"
    exit 0
  fi

  echo "═══════════════════════════════════════════════"
  echo "EFFORT BREAKDOWN — identity=${identity} window=${window}"
  echo "═══════════════════════════════════════════════"

  _py "
import json, time, collections

window_s = ${window_s}
cutoff_s = ${cutoff_s}
identity = '${identity}'

buckets = collections.defaultdict(lambda: {'count': 0, 'tokens_in': 0, 'tokens_out': 0, 'compute_s': 0, 'human_s': 0})

try:
    with open('${EFFORT_LOG}') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except:
                continue
            if rec.get('identity') != identity:
                continue
            ts = rec.get('timestamp', '')
            try:
                ts_s = int(time.mktime(time.strptime(ts, '%Y-%m-%dT%H:%M:%SZ')))
            except:
                continue
            if ts_s < cutoff_s:
                continue
            hour_bucket = ts.split('T')[1][:2] + ':00'
            buckets[hour_bucket]['count'] += 1
            buckets[hour_bucket]['tokens_in'] += rec.get('tokens_in', 0)
            buckets[hour_bucket]['tokens_out'] += rec.get('tokens_out', 0)
            buckets[hour_bucket]['compute_s'] += rec.get('compute_s', 0)
            buckets[hour_bucket]['human_s'] += rec.get('human_intervention_s', 0)
except FileNotFoundError:
    pass

if not buckets:
    print('No data')
else:
    print(f\"{'BUCKET':<10} {'COUNT':>8} {'TOKENS_IN':>12} {'TOKENS_OUT':>13} {'COMPUTE_S':>11} {'HUMAN_S':>9}\")
    print('-' * 70)
    for b in sorted(buckets):
        d = buckets[b]
        print(f\"{b:<10} {d['count']:>8} {d['tokens_in']:>12} {d['tokens_out']:>13} {d['compute_s']:>11} {d['human_s']:>9}\")
"
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
[[ $# -lt 1 ]] && _usage

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  record)     cmd_record     "$@" ;;
  summary)    cmd_summary    "$@" ;;
  breakdown)  cmd_breakdown  "$@" ;;
  *)          _usage ;;
esac
