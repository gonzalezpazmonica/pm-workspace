#!/usr/bin/env bash
# agent-budget-check.sh — SE-272 Slice 3: Per-requestor budget limits
# Ref: docs/propuestas/SE-272-servicio-gestionado.md
#
# Per-requestor budget: limits on requests and cost per agent identity per window.
# Exhausted budget → enqueue + notify contract owner (never silent deny).
#
# Usage:
#   agent-budget-check.sh check    --identity ID [--cost-cents N] [--config FILE]
#   agent-budget-check.sh reset    --identity ID [--config FILE]
#   agent-budget-check.sh status   --identity ID [--config FILE]
#   agent-budget-check.sh enqueue  --identity ID [--payload JSON]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}"
BUDGET_CONFIG="${BUDGET_CONFIG:-$REPO_ROOT/config/agent-budget.yaml}"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/data}"
mkdir -p "$DATA_DIR"
USAGE_LOG="${USAGE_LOG:-$DATA_DIR/agent-budget-usage.jsonl}"
QUEUE_FILE="${QUEUE_FILE:-$DATA_DIR/agent-budget-queue.jsonl}"
NOTIFY_LOG="${NOTIFY_LOG:-$REPO_ROOT/bridge/control-plane/agent-budget-events.jsonl}"
mkdir -p "$(dirname "$NOTIFY_LOG")" 2>/dev/null || true

_usage() {
  cat >&2 <<'EOF'
Usage: agent-budget-check.sh <subcommand> [options]

Subcommands:
  check    --identity ID [--cost-cents N] [--config FILE]
           Check if request fits within budget. Exit 0 = approved, exit 1 = exhausted.
  reset    --identity ID [--config FILE]
           Reset budget counters for an identity.
  status   --identity ID [--config FILE]
           Show current budget status for an identity.
  enqueue  --identity ID [--payload JSON]
           Enqueue request for later processing.

Exit codes:
  0 — within budget (approved)
  1 — budget exhausted (enqueued, notified)
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

# ── Read budget config for an identity ───────────────────────────────────────
_read_config() {
  local identity="$1"
  local config_file="$2"

  if [[ ! -f "$config_file" ]]; then
    _die "Budget config not found: ${config_file}"
  fi

  _py "
import yaml, json, sys
try:
    with open('${config_file}') as fh:
        cfg = yaml.safe_load(fh)
    defaults = cfg.get('defaults', {})
    identities = cfg.get('identities', {})
    entry = identities.get('${identity}', identities.get('wildcard', defaults))
    result = {
        'window': entry.get('window', '1h'),
        'max_requests': entry.get('max_requests', 100),
        'max_cost_cents': entry.get('max_cost_cents', 5000),
        'enqueue_on_exhaust': entry.get('enqueue_on_exhaust', True),
        'notify_contract_owner': entry.get('notify_contract_owner', True),
    }
    print(json.dumps(result))
except Exception as e:
    print(json.dumps({'error': str(e)}), file=sys.stderr)
    sys.exit(1)
" 2>/dev/null
}

# ── Parse window string to seconds ───────────────────────────────────────────
_parse_window_s() {
  local window="$1"
  _py "
w = '${window}'
n = int(w[:-1])
unit = w[-1]
mult = {'s': 1, 'm': 60, 'h': 3600, 'd': 86400}
print(n * mult.get(unit, 1))
"
}

# ── Get usage for identity within current window ─────────────────────────────
_get_window_usage() {
  local identity="$1"
  local window_s="$2"
  local usage_file="$3"
  local now_s
  now_s="$(date +%s)"
  local cutoff_s=$(( now_s - window_s ))

  if [[ ! -f "$usage_file" ]]; then
    echo '{"requests": 0, "cost_cents": 0}'
    return
  fi

  _py "
import json, time
window_s = ${window_s}
now_s = ${now_s}
cutoff_s = ${cutoff_s}
identity = '${identity}'
total_requests = 0
total_cost = 0
try:
    with open('${usage_file}') as fh:
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
            if rec.get('identity') == identity and ts_s >= cutoff_s:
                total_requests += 1
                total_cost += rec.get('cost_cents', 0)
    print(json.dumps({'requests': total_requests, 'cost_cents': total_cost}))
except Exception:
    print(json.dumps({'requests': 0, 'cost_cents': 0}))
"
}

# ── Log usage entry ──────────────────────────────────────────────────────────
_log_usage() {
  local identity="$1"
  local cost_cents="$2"
  local decision="$3"
  local ts
  ts="$(_now)"

  _py "
import json
record = {
    'timestamp': '${ts}',
    'identity': '${identity}',
    'cost_cents': ${cost_cents},
    'decision': '${decision}',
}
with open('${USAGE_LOG}', 'a') as fh:
    fh.write(json.dumps(record) + '\n')
" 2>/dev/null || true
}

# ── Notify contract owner ────────────────────────────────────────────────────
_notify_owner() {
  local identity="$1"
  local reason="$2"
  local ts
  ts="$(_now)"

  _py "
import json
record = {
    'timestamp': '${ts}',
    'identity': '${identity}',
    'event': 'budget_exhausted',
    'reason': '${reason}',
}
with open('${NOTIFY_LOG}', 'a') as fh:
    fh.write(json.dumps(record) + '\n')
" 2>/dev/null || true
}

# ── Subcommand: check ────────────────────────────────────────────────────────
cmd_check() {
  local identity="" cost_cents="0" config_file="$BUDGET_CONFIG"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --identity)  identity="$2";    shift 2 ;;
      --cost-cents) cost_cents="$2"; shift 2 ;;
      --config)    config_file="$2"; shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$identity" ]] && _die "--identity is required"

  local cfg_json window_s max_requests max_cost_cents enqueue_on_exhaust notify_owner
  cfg_json="$(_read_config "$identity" "$config_file")" || exit 2

  window_s="$(_py "import json,sys; print(json.loads(sys.argv[1])['window'])" "$cfg_json")"
  window_s=$(_parse_window_s "$window_s")
  max_requests="$(_py "import json,sys; print(json.loads(sys.argv[1])['max_requests'])" "$cfg_json")"
  max_cost_cents="$(_py "import json,sys; print(json.loads(sys.argv[1])['max_cost_cents'])" "$cfg_json")"
  enqueue_on_exhaust="$(_py "import json,sys; print(json.loads(sys.argv[1])['enqueue_on_exhaust'])" "$cfg_json")"
  notify_owner="$(_py "import json,sys; print(json.loads(sys.argv[1])['notify_contract_owner'])" "$cfg_json")"

  local usage_json requests_used cost_used
  usage_json="$(_get_window_usage "$identity" "$window_s" "$USAGE_LOG")"
  requests_used="$(_py "import json,sys; print(json.loads(sys.argv[1])['requests'])" "$usage_json")"
  cost_used="$(_py "import json,sys; print(json.loads(sys.argv[1])['cost_cents'])" "$usage_json")"

  local requests_after=$(( requests_used + 1 ))
  local cost_after=$(( cost_used + cost_cents ))

  if [[ "$requests_after" -le "$max_requests" && "$cost_after" -le "$max_cost_cents" ]]; then
    _log_usage "$identity" "$cost_cents" "approved"
    echo "BUDGET_OK: identity=${identity} requests=${requests_after}/${max_requests} cost_cents=${cost_after}/${max_cost_cents}"
    exit 0
  fi

  # Budget exhausted
  local reason="requests=${requests_after}/${max_requests} cost_cents=${cost_after}/${max_cost_cents}"
  _log_usage "$identity" "$cost_cents" "exhausted"

  if [[ "$enqueue_on_exhaust" == "True" || "$enqueue_on_exhaust" == "true" ]]; then
    _py "
import json
record = {'timestamp': '$(_now)', 'identity': '${identity}', 'cost_cents': ${cost_cents}, 'reason': '${reason}'}
with open('${QUEUE_FILE}', 'a') as fh:
    fh.write(json.dumps(record) + '\n')
" 2>/dev/null || true
    echo "BUDGET_EXHAUSTED_ENQUEUED: ${reason}" >&2
  else
    echo "BUDGET_EXHAUSTED_DENIED: ${reason}" >&2
  fi

  if [[ "$notify_owner" == "True" || "$notify_owner" == "true" ]]; then
    _notify_owner "$identity" "$reason"
    echo "NOTIFY: contract owner notified for identity '${identity}'" >&2
  fi

  exit 1
}

# ── Subcommand: reset ────────────────────────────────────────────────────────
cmd_reset() {
  local identity="" config_file="$BUDGET_CONFIG"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --identity) identity="$2"; shift 2 ;;
      --config)   config_file="$2"; shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$identity" ]] && _die "--identity is required"

  _py "
import json, sys
identity = '${identity}'
records = []
found = 0
try:
    with open('${USAGE_LOG}') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                records.append('')
                continue
            try:
                rec = json.loads(line)
            except:
                records.append(line)
                continue
            if rec.get('identity') == identity:
                rec['reset_at'] = '$(_now)'
                rec['decision'] = 'reset'
                records.append(json.dumps(rec))
                found += 1
            else:
                records.append(line)
except FileNotFoundError:
    pass
if found == 0:
    print('No usage records found for identity: ${identity}')
    sys.exit(0)
with open('${USAGE_LOG}', 'w') as fh:
    for r in records:
        fh.write(r + '\n')
print(f'Reset {found} records for identity: ${identity}')
" 2>/dev/null

  exit 0
}

# ── Subcommand: status ───────────────────────────────────────────────────────
cmd_status() {
  local identity="" config_file="$BUDGET_CONFIG"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --identity) identity="$2"; shift 2 ;;
      --config)   config_file="$2"; shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$identity" ]] && _die "--identity is required"

  local cfg_json window_s max_requests max_cost_cents
  cfg_json="$(_read_config "$identity" "$config_file")" || exit 2

  window_s="$(_py "import json,sys; print(json.loads(sys.argv[1])['window'])" "$cfg_json")"
  window_s=$(_parse_window_s "$window_s")
  max_requests="$(_py "import json,sys; print(json.loads(sys.argv[1])['max_requests'])" "$cfg_json")"
  max_cost_cents="$(_py "import json,sys; print(json.loads(sys.argv[1])['max_cost_cents'])" "$cfg_json")"

  local usage_json requests_used cost_used
  usage_json="$(_get_window_usage "$identity" "$window_s" "$USAGE_LOG")"
  requests_used="$(_py "import json,sys; print(json.loads(sys.argv[1])['requests'])" "$usage_json")"
  cost_used="$(_py "import json,sys; print(json.loads(sys.argv[1])['cost_cents'])" "$usage_json")"

  local queued=0
  if [[ -f "$QUEUE_FILE" ]]; then
    queued=$(_py "
import json
count = 0
try:
    with open('${QUEUE_FILE}') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except:
                continue
            if rec.get('identity') == '${identity}':
                count += 1
except:
    pass
print(count)
" 2>/dev/null)
  fi

  echo "IDENTITY: ${identity}"
  echo "WINDOW: ${window_s}s"
  echo "REQUESTS_USED: ${requests_used}/${max_requests}"
  echo "COST_CENTS_USED: ${cost_used}/${max_cost_cents}"
  echo "ENQUEUED: ${queued}"
  [[ "${requests_used:-0}" -ge "${max_requests:-0}" ]] && echo "STATUS: EXHAUSTED" || echo "STATUS: ACTIVE"
}

# ── Subcommand: enqueue ──────────────────────────────────────────────────────
cmd_enqueue() {
  local identity="" payload="{}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --identity) identity="$2"; shift 2 ;;
      --payload)  payload="$2";  shift 2 ;;
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
    'payload': ${payload},
}
with open('${QUEUE_FILE}', 'a') as fh:
    fh.write(json.dumps(record) + '\n')
" 2>/dev/null

  echo "ENQUEUED: identity=${identity} at ${ts}"
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
[[ $# -lt 1 ]] && _usage

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  check)    cmd_check    "$@" ;;
  reset)    cmd_reset    "$@" ;;
  status)   cmd_status   "$@" ;;
  enqueue)  cmd_enqueue  "$@" ;;
  *)        _usage ;;
esac
