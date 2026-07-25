#!/usr/bin/env bash
# ext-platform-export-gate.sh — SE-272 Slice 4: Export gate for external platforms
# Ref: docs/propuestas/SE-272-servicio-gestionado.md
#
# Payload to external platform passes same export gate as domes (SE-263 S3).
# Respects client wall (SE-271 S3): client A data never crosses to client B platform.
# Blocks payload above card's max level.
#
# Usage:
#   ext-platform-export-gate.sh check    --card-id ID --payload-level N --client-id ID [--data-hash HASH]
#   ext-platform-export-gate.sh audit    [--cards-file FILE]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}"
CARDS_FILE="${PLATFORM_CARDS_FILE:-$REPO_ROOT/config/ext-platform-cards.yaml}"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/data}"
mkdir -p "$DATA_DIR"
EXPORT_LOG="${EXPORT_LOG:-$DATA_DIR/ext-platform-export-decisions.jsonl}"

_usage() {
  cat >&2 <<'EOF'
Usage: ext-platform-export-gate.sh <subcommand> [options]

Subcommands:
  check  --card-id ID --payload-level N --client-id ID [--data-hash HASH] [--cards-file FILE]
         Check if payload can be exported to external platform.
         Enforces: card max level, client wall, dome export gate pattern.
  audit  [--cards-file FILE]
         Audit all export decisions.

Exit codes: 0 = export allowed, 1 = blocked, 2 = usage error
EOF
  exit 2
}

_die() {
  echo "ERROR: $*" >&2
  exit 2
}

_py() { python3 -c "$@"; }
_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# ── Lookup card ──────────────────────────────────────────────────────────────
_lookup_card() {
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
            print(json.dumps(card))
            sys.exit(0)
    print('')
except Exception:
    print('')
" 2>/dev/null
}

# ── Log export decision ──────────────────────────────────────────────────────
_log_export() {
  local card_id="$1"
  local payload_level="$2"
  local client_id="$3"
  local decision="$4"
  local reason="$5"
  local ts
  ts="$(_now)"

  _py "
import json
rec = {
    'ts': '${ts}',
    'card_id': '${card_id}',
    'payload_level': ${payload_level},
    'client_id': '${client_id}',
    'decision': '${decision}',
    'reason': '${reason}',
}
with open('${EXPORT_LOG}', 'a') as fh:
    fh.write(json.dumps(rec) + '\n')
" 2>/dev/null || true
}

# ── Check client wall ───────────────────────────────────────────────────────
# SE-271 S3: client A data never crosses to client B platform
_check_client_wall() {
  local client_id="$1"
  local card_json="$2"

  local card_engagement
  card_engagement="$(_py "import json; print(json.loads('${card_json}')['engagement'])")"

  # Extract client slug from engagement path
  # engagements/YYYY-client-slug-NNN → client-slug
  local eng_slug
  eng_slug=$(basename "$card_engagement" | sed 's/^[0-9]*-//;s/-[0-9]*$//')

  if [[ -z "$client_id" || -z "$eng_slug" ]]; then
    _py "
import json
card = json.loads('${card_json}')
eng = card.get('engagement', '')
print(f\"WALL_WARN: cannot verify client wall - client_id='${client_id}' engagement='${eng}'\")
" >&2
    return 0  # Don't block if we can't verify, but warn
  fi

  # Check if client_id matches engagement
  if [[ "$client_id" != "$eng_slug" && "$client_id" != "savia-internal" ]]; then
    echo "BLOCKED_CLIENT_WALL: client_id='${client_id}' does not match engagement='${eng_slug}'" >&2
    return 1
  fi

  return 0
}

# ── Check dome export gate (SE-263 S3 pattern) ──────────────────────────────
# Payload level must be below card max AND below system max
_check_dome_gate() {
  local card_json="$1"
  local payload_level="$2"

  local max_pl
  max_pl="$(_py "import json; print(json.loads('${card_json}')['max_payload_level'])")"

  local system_max=4  # SE-263 S3: max payload level for domes

  if [[ "${payload_level:-0}" -gt "${max_pl:-0}" ]]; then
    echo "BLOCKED_PAYLOAD_LEVEL: ${payload_level} > card_max=${max_pl}" >&2
    return 1
  fi

  if [[ "${payload_level:-0}" -gt "${system_max}" ]]; then
    echo "BLOCKED_SYSTEM_LEVEL: ${payload_level} > system_max=${system_max}" >&2
    return 1
  fi

  return 0
}

# ── Subcommand: check ────────────────────────────────────────────────────────
cmd_check() {
  local card_id="" payload_level="0" client_id="" data_hash="" cards_file="$CARDS_FILE"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --card-id)       card_id="$2";       shift 2 ;;
      --payload-level) payload_level="$2"; shift 2 ;;
      --client-id)     client_id="$2";     shift 2 ;;
      --data-hash)     data_hash="$2";     shift 2 ;;
      --cards-file)    cards_file="$2";    shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$card_id" ]]   && _die "--card-id is required"
  [[ -z "$client_id" ]] && _die "--client-id is required"

  local card_json
  card_json="$(_lookup_card "$card_id" "$cards_file")"

  if [[ -z "$card_json" ]]; then
    _log_export "$card_id" "$payload_level" "$client_id" "BLOCKED" "card_not_found"
    echo "BLOCKED: card_id=${card_id} not found in registry" >&2
    exit 1
  fi

  # Card must be active
  local status
  status="$(_py "import json; print(json.loads('${card_json}').get('status',''))")"
  if [[ "$status" != "active" ]]; then
    _log_export "$card_id" "$payload_level" "$client_id" "BLOCKED" "card_inactive:${status}"
    echo "BLOCKED: card_id=${card_id} status=${status} (not active)" >&2
    exit 1
  fi

  # Dome export gate (payload level check)
  local dome_result
  if ! dome_result=$(_check_dome_gate "$card_json" "$payload_level" 2>&1); then
    _log_export "$card_id" "$payload_level" "$client_id" "BLOCKED" "$dome_result"
    exit 1
  fi

  # Client wall check (SE-271 S3)
  if ! _check_client_wall "$client_id" "$card_json"; then
    _log_export "$card_id" "$payload_level" "$client_id" "BLOCKED" "client_wall_violation"
    exit 1
  fi

  _log_export "$card_id" "$payload_level" "$client_id" "ALLOWED" "all_checks_passed"

  echo "EXPORT_ALLOWED: card_id=${card_id} payload_level=${payload_level} client_id=${client_id}"
  [[ -n "$data_hash" ]] && echo "DATA_HASH: ${data_hash}"
  exit 0
}

# ── Subcommand: audit ────────────────────────────────────────────────────────
cmd_audit() {
  local cards_file="$CARDS_FILE"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cards-file) cards_file="$2"; shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  echo "═══════════════════════════════════════════════"
  echo "EXPORT GATE AUDIT — SE-272 S4"
  echo "═══════════════════════════════════════════════"
  echo ""

  if [[ -f "$EXPORT_LOG" ]]; then
    echo "--- Recent Export Decisions ---"
    _py "
import json
try:
    with open('${EXPORT_LOG}') as fh:
        lines = fh.readlines()
    recent = lines[-20:] if len(lines) > 20 else lines
    print(f\"{'TS':<22} {'CARD_ID':<35} {'CLIENT':<20} {'DECISION':<10} {'REASON'}\")
    print('-' * 110)
    for line in recent:
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except:
            continue
        ts = rec.get('ts', '')[:21]
        cid = rec.get('card_id', '')[:34]
        clt = rec.get('client_id', '')[:19]
        dec = rec.get('decision', '')[:9]
        rsn = rec.get('reason', '')[:40]
        print(f\"{ts:<22} {cid:<35} {clt:<20} {dec:<10} {rsn}\")
except Exception:
    print('  (no export log data)')
" 2>/dev/null
  else
    echo "  (no export log data yet)"
  fi

  echo ""
  echo "--- Card Export Limits ---"
  if [[ -f "$cards_file" ]]; then
    _py "
import yaml
with open('${cards_file}') as fh:
    cfg = yaml.safe_load(fh)
for name, card in cfg.get('cards', {}).items():
    st = card.get('status', '?')
    pl = card.get('max_payload_level', '?')
    eng = card.get('engagement', '?')
    print(f'  {name}: status={st} max_level={pl} engagement={eng}')
" 2>/dev/null
  fi
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
[[ $# -lt 1 ]] && _usage

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  check)  cmd_check  "$@" ;;
  audit)  cmd_audit  "$@" ;;
  *)      _usage ;;
esac
