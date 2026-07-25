#!/usr/bin/env bash
# ext-platform-resilience.sh — SE-272 Slice 4: Resilience for external platforms
# Ref: docs/propuestas/SE-272-servicio-gestionado.md
#
# External platform unreachable → engagement continues in local mode with
# outgoing message queue. Never blocks (coherence with SE-271 S7).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}"
CARDS_FILE="${PLATFORM_CARDS_FILE:-$REPO_ROOT/config/ext-platform-cards.yaml}"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/data}"
mkdir -p "$DATA_DIR"
QUEUE_FILE="${SAVIA_EXT_QUEUE:-$REPO_ROOT/bridge/control-plane/ext-platform-outbound.jsonl}"
mkdir -p "$(dirname "$QUEUE_FILE")" 2>/dev/null || true
RESILIENCE_LOG="${RESILIENCE_LOG:-$DATA_DIR/ext-platform-resilience.jsonl}"

_usage() {
  cat >&2 <<'EOF'
Usage: ext-platform-resilience.sh <subcommand> [options]

Subcommands:
  probe       --card-id ID [--timeout-s N]
              Probe external platform reachability. Exit 0 = reachable.
  enqueue     --card-id ID --payload JSON [--priority high|normal|low]
              Enqueue outgoing message for external platform.
  dequeue     --card-id ID [--limit N]
              Dequeue and attempt delivery for queued messages.
  status      [--card-id ID]
              Show queue status and platform health.

Exit codes: 0 = ok, 1 = unreachable/empty, 2 = usage error
EOF
  exit 2
}

_die() {
  echo "ERROR: $*" >&2
  exit 2
}

_py() { python3 -c "$@"; }
_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# ── Lookup card endpoint ─────────────────────────────────────────────────────
_lookup_endpoint() {
  local card_id="$1"
  local cards_file="$2"

  if [[ ! -f "$cards_file" ]]; then
    echo ""
    return 1
  fi

  _py "
import yaml, json, sys
try:
    with open('${cards_file}') as fh:
        cfg = yaml.safe_load(fh)
    cards = cfg.get('cards', {})
    for _k, card in cards.items():
        if card.get('id') == '${card_id}':
            endpoint = card.get('endpoint', '')
            print(endpoint)
            sys.exit(0)
    print('')
except Exception:
    print('')
" 2>/dev/null
}

# ── Log resilience event ─────────────────────────────────────────────────────
_log_resilience() {
  local card_id="$1"
  local event="$2"
  local detail="$3"
  local ts
  ts="$(_now)"

  _py "
import json
rec = {'ts': '${ts}', 'card_id': '${card_id}', 'event': '${event}', 'detail': '${detail}'}
with open('${RESILIENCE_LOG}', 'a') as fh:
    fh.write(json.dumps(rec) + '\n')
" 2>/dev/null || true
}

# ── Subcommand: probe ────────────────────────────────────────────────────────
cmd_probe() {
  local card_id="" timeout_s="5" cards_file="$CARDS_FILE"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --card-id)    card_id="$2";    shift 2 ;;
      --timeout-s)  timeout_s="$2";  shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$card_id" ]] && _die "--card-id is required"

  local endpoint
  endpoint="$(_lookup_endpoint "$card_id" "$cards_file")"

  if [[ -z "$endpoint" ]]; then
    echo "UNREACHABLE: card_id=${card_id} no endpoint configured"
    exit 1
  fi

  if command -v curl &>/dev/null; then
    if curl -sf --max-time "$timeout_s" "$endpoint/health" >/dev/null 2>&1; then
      _log_resilience "$card_id" "probe_reachable" "endpoint=${endpoint}"
      echo "REACHABLE: card_id=${card_id} endpoint=${endpoint}"
      exit 0
    else
      _log_resilience "$card_id" "probe_unreachable" "endpoint=${endpoint}"
      echo "UNREACHABLE: card_id=${card_id} endpoint=${endpoint}"
      exit 1
    fi
  else
    echo "WARNING: curl not available, probe skipped"
    echo "ASSUMED_REACHABLE: card_id=${card_id}"
    exit 0
  fi
}

# ── Subcommand: enqueue ──────────────────────────────────────────────────────
cmd_enqueue() {
  local card_id="" payload="{}" priority="normal"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --card-id)  card_id="$2";  shift 2 ;;
      --payload)  payload="$2";  shift 2 ;;
      --priority) priority="$2"; shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$card_id" ]] && _die "--card-id is required"

  case "$priority" in
    high|normal|low) ;;
    *) _die "Priority must be high, normal, or low" ;;
  esac

  local ts
  ts="$(_now)"

  # Check max queue size
  local config_max=10000
  if [[ -f "$CARDS_FILE" ]]; then
    config_max=$(_py "
import yaml
try:
    with open('${CARDS_FILE}') as fh:
        cfg = yaml.safe_load(fh)
    resilience = cfg.get('resilience', {})
    print(resilience.get('max_queue_size', 10000))
except:
    print(10000)
" 2>/dev/null)
  fi

  local queue_size=0
  if [[ -f "$QUEUE_FILE" ]]; then
    queue_size=$(wc -l < "$QUEUE_FILE")
  fi

  if [[ "$queue_size" -ge "$config_max" ]]; then
    echo "QUEUE_FULL: max=${config_max} current=${queue_size}" >&2
    exit 1
  fi

  _py "
import json
rec = {
    'ts': '${ts}',
    'card_id': '${card_id}',
    'priority': '${priority}',
    'payload': ${payload},
    'attempts': 0,
    'status': 'queued',
}
with open('${QUEUE_FILE}', 'a') as fh:
    fh.write(json.dumps(rec) + '\n')
" 2>/dev/null

  _log_resilience "$card_id" "enqueued" "priority=${priority}"
  echo "ENQUEUED: card_id=${card_id} priority=${priority} ts=${ts}"
}

# ── Subcommand: dequeue ──────────────────────────────────────────────────────
cmd_dequeue() {
  local card_id="" limit="5" cards_file="$CARDS_FILE"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --card-id) card_id="$2"; shift 2 ;;
      --limit)   limit="$2";   shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$card_id" ]] && _die "--card-id is required"

  if [[ ! -f "$QUEUE_FILE" ]]; then
    echo "Queue empty — no queued messages"
    exit 0
  fi

  local endpoint
  endpoint="$(_lookup_endpoint "$card_id" "$cards_file")"

  if [[ -z "$endpoint" ]]; then
    echo "UNREACHABLE: card_id=${card_id} no endpoint configured"
    exit 1
  fi

  # Attempt delivery for pending messages
  _py "
import json, sys

card_id = '${card_id}'
limit = ${limit}
endpoint = '${endpoint}'

# Read all queued items, process up to limit for this card
try:
    with open('${QUEUE_FILE}') as fh:
        lines = fh.readlines()
except:
    lines = []

pending = []
delivered = 0
failed = 0

import subprocess, time
for line in lines:
    line = line.strip()
    if not line:
        continue
    try:
        rec = json.loads(line)
    except:
        continue
    if rec.get('card_id') != card_id:
        continue
    if rec.get('status') == 'delivered':
        continue
    if delivered + failed >= limit:
        break

    # Attempt delivery via curl
    try:
        payload_json = json.dumps(rec.get('payload', {}))
        result = subprocess.run(
            ['curl', '-sf', '--max-time', '10', '-X', 'POST',
             f'{endpoint}/message',
             '-H', 'Content-Type: application/json',
             '-d', payload_json],
            capture_output=True, text=True, timeout=15
        )
        if result.returncode == 0:
            rec['status'] = 'delivered'
            rec['delivered_at'] = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
            delivered += 1
        else:
            rec['attempts'] = rec.get('attempts', 0) + 1
            if rec['attempts'] >= 5:
                rec['status'] = 'dead_letter'
            failed += 1
    except Exception:
        rec['attempts'] = rec.get('attempts', 0) + 1
        if rec['attempts'] >= 5:
            rec['status'] = 'dead_letter'
        failed += 1

    # Write back as JSONL line
    print(json.dumps(rec))

print(f'DELIVERED: {delivered}')
print(f'FAILED: {failed}')
print(f'PENDING: {len(pending)}')
" 2>/dev/null

  exit 0
}

# ── Subcommand: status ───────────────────────────────────────────────────────
cmd_status() {
  local card_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --card-id) card_id="$2"; shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  echo "═══════════════════════════════════════════════"
  echo "EXTERNAL PLATFORM RESILIENCE STATUS"
  echo "═══════════════════════════════════════════════"
  echo ""

  # Queue stats
  local total_queued=0 total_delivered=0 total_dead=0
  if [[ -f "$QUEUE_FILE" ]]; then
    local stats
    stats=$(_py "
import json, collections
counts = collections.Counter()
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
            if '${card_id}' and rec.get('card_id') != '${card_id}':
                continue
            counts[rec.get('status', 'queued')] += 1
except:
    pass
for k, v in sorted(counts.items()):
    print(f'{k}:{v}')
" 2>/dev/null)

    echo "--- Outbound Queue ---"
    if [[ -n "$stats" ]]; then
      echo "$stats" | while IFS=: read -r status count; do
        echo "  ${status}: ${count}"
      done
    else
      echo "  (empty)"
    fi
  else
    echo "--- Outbound Queue ---"
    echo "  (no queue file)"
  fi

  echo ""
  echo "Principle: corp unreachable never blocks (SE-271 S7 coherence)."
  echo "Local mode continues with outgoing queue."
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
[[ $# -lt 1 ]] && _usage

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  probe)    cmd_probe    "$@" ;;
  enqueue)  cmd_enqueue  "$@" ;;
  dequeue)  cmd_dequeue  "$@" ;;
  status)   cmd_status   "$@" ;;
  *)        _usage ;;
esac
