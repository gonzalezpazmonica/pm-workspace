#!/usr/bin/env bash
# ext-platform-card-validate.sh — SE-272 Slice 4: Validate external platform card
# Ref: docs/propuestas/SE-272-servicio-gestionado.md
#
# Validates external platform card: id, organization, public key,
# exposed skills, allowed skills, max payload, engagement.
# Different from instance card (SE-263).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}"
CARDS_FILE="${PLATFORM_CARDS_FILE:-$REPO_ROOT/config/ext-platform-cards.yaml}"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/data}"
mkdir -p "$DATA_DIR"
VALIDATION_LOG="${VALIDATION_LOG:-$DATA_DIR/ext-platform-card-validations.jsonl}"

_usage() {
  cat >&2 <<'EOF'
Usage: ext-platform-card-validate.sh <subcommand> [options]

Subcommands:
  validate      --card-id ID [--cards-file FILE]
                Validate a single external platform card. Exit 0 = valid.
  verify-key    --card-id ID --signature SIG --data DATA [--cards-file FILE]
                Verify a signature against the card's public key (stub).
  list-active   [--cards-file FILE]
                List all active platform cards.

Exit codes: 0 = valid, 1 = invalid, 2 = usage error
EOF
  exit 2
}

_die() {
  echo "ERROR: $*" >&2
  exit 2
}

_py() { python3 -c "$@"; }
_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# ── Card schema fields ───────────────────────────────────────────────────────
REQUIRED_FIELDS=("id" "organization" "public_key" "exposed_skills" "allowed_skills" "max_payload_level" "engagement")

# ── Validate card structure ──────────────────────────────────────────────────
_validate_card_structure() {
  local card_json="$1"

  _py "
import json, sys

card = json.loads('${card_json}')
errors = []
for f in ['id', 'organization', 'public_key', 'exposed_skills', 'allowed_skills', 'max_payload_level', 'engagement']:
    if f not in card:
        errors.append(f'missing_field:{f}')
if not card.get('id'):
    errors.append('empty_id')
if not card.get('organization'):
    errors.append('empty_organization')
if not card.get('public_key', '').startswith('ssh-'):
    errors.append('invalid_public_key_format:must_start_with_ssh-')
if not isinstance(card.get('exposed_skills'), list):
    errors.append('exposed_skills_must_be_list')
if not isinstance(card.get('allowed_skills'), list):
    errors.append('allowed_skills_must_be_list')
pl = card.get('max_payload_level', -1)
if not isinstance(pl, int) or pl < 0:
    errors.append('max_payload_level_must_be_non_negative_int')
if not card.get('engagement'):
    errors.append('empty_engagement')
if errors:
    print('INVALID: ' + ', '.join(errors))
else:
    print('VALID')
" 2>/dev/null
}

# ── Validate skills are subset ──────────────────────────────────────────────
_validate_skills_subset() {
  local card_json="$1"

  _py "
import json, sys

card = json.loads('${card_json}')
exposed = set(card.get('exposed_skills', []))
allowed = set(card.get('allowed_skills', []))
errors = []
if not allowed.issubset(exposed):
    extra = allowed - exposed
    errors.append(f'allowed_not_in_exposed:{\",\".join(sorted(extra))}')
elif not allowed:
    errors.append('allowed_skills_is_empty_allowlist_cannot_be_empty')
if errors:
    print('INVALID: ' + ', '.join(errors))
else:
    print('VALID')
" 2>/dev/null
}

# ── Log validation ───────────────────────────────────────────────────────────
_log_validation() {
  local card_id="$1"
  local verdict="$2"
  local reason="$3"
  local ts
  ts="$(_now)"

  _py "
import json
rec = {'ts': '${ts}', 'card_id': '${card_id}', 'verdict': '${verdict}', 'reason': '${reason}'}
with open('${VALIDATION_LOG}', 'a') as fh:
    fh.write(json.dumps(rec) + '\n')
" 2>/dev/null || true
}

# ── Lookup card in registry ─────────────────────────────────────────────────
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
    for key, card in cards.items():
        if card.get('id') == '${card_id}':
            print(json.dumps(card))
            sys.exit(0)
    print('')
except Exception:
    print('')
" 2>/dev/null
}

# ── Subcommand: validate ─────────────────────────────────────────────────────
cmd_validate() {
  local card_id="" cards_file="$CARDS_FILE"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --card-id)    card_id="$2";    shift 2 ;;
      --cards-file) cards_file="$2"; shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$card_id" ]] && _die "--card-id is required"

  local card_json
  card_json="$(_lookup_card "$card_id" "$cards_file")"

  if [[ -z "$card_json" ]]; then
    _log_validation "$card_id" "INVALID" "not_found_in_registry"
    echo "INVALID: card_id=${card_id} not found in registry" >&2
    exit 1
  fi

  # Check structure
  local struct_result
  struct_result="$(_validate_card_structure "$card_json")"
  if [[ "$struct_result" != "VALID" ]]; then
    _log_validation "$card_id" "INVALID" "$struct_result"
    echo "${struct_result}" >&2
    exit 1
  fi

  # Check skills subset
  local skills_result
  skills_result="$(_validate_skills_subset "$card_json")"
  if [[ "$skills_result" != "VALID" ]]; then
    _log_validation "$card_id" "INVALID" "$skills_result"
    echo "${skills_result}" >&2
    exit 1
  fi

  # Check status
  local status
  status="$(_py "
import json
card = json.loads('${card_json}')
print(card.get('status', 'active'))
")"

  if [[ "$status" != "active" ]]; then
    _log_validation "$card_id" "INVALID" "status_not_active:${status}"
    echo "INVALID: card_id=${card_id} status=${status} (must be active)" >&2
    exit 1
  fi

  _log_validation "$card_id" "VALID" "all_checks_passed"

  # Output card summary
  _py "
import json
c = json.loads('${card_json}')
print(f\"VALID: card_id={c['id']}\")
print(f\"  org: {c['organization']}\")
print(f\"  engagement: {c['engagement']}\")
print(f\"  max_payload_level: {c['max_payload_level']}\")
print(f\"  exposed_skills: {', '.join(c['exposed_skills'])}\")
print(f\"  allowed_skills: {', '.join(c['allowed_skills'])}\")
print(f\"  status: {c.get('status', 'active')}\")
"

  exit 0
}

# ── Subcommand: verify-key ───────────────────────────────────────────────────
cmd_verify_key() {
  local card_id="" signature="" data="" cards_file="$CARDS_FILE"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --card-id)    card_id="$2";    shift 2 ;;
      --signature)  signature="$2";  shift 2 ;;
      --data)       data="$2";       shift 2 ;;
      --cards-file) cards_file="$2"; shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$card_id" ]]   && _die "--card-id is required"
  [[ -z "$signature" ]] && _die "--signature is required"
  [[ -z "$data" ]]      && _die "--data is required"

  local card_json
  card_json="$(_lookup_card "$card_id" "$cards_file")"

  if [[ -z "$card_json" ]]; then
    echo "INVALID: card not found"
    exit 1
  fi

  local pubkey
  pubkey="$(_py "import json; print(json.loads('${card_json}')['public_key'])")"

  if command -v ssh-keygen &>/dev/null; then
    local tmp_pk tmp_sig tmp_data
    tmp_pk=$(mktemp)
    tmp_sig=$(mktemp)
    tmp_data=$(mktemp)
    echo "$pubkey" > "$tmp_pk"
    echo "$signature" > "$tmp_sig"
    echo -n "$data" > "$tmp_data"
    if ssh-keygen -Y verify -f "$tmp_pk" -n "ext-platform" -I "$card_id" -s "$tmp_sig" < "$tmp_data" 2>/dev/null; then
      echo "SIGNATURE_VALID: card_id=${card_id}"
    else
      echo "SIGNATURE_INVALID: card_id=${card_id}"
      rm -f "$tmp_pk" "$tmp_sig" "$tmp_data"
      exit 1
    fi
    rm -f "$tmp_pk" "$tmp_sig" "$tmp_data"
  else
    echo "WARNING: ssh-keygen not available, signature verification skipped"
    echo "SIGNATURE_SKIPPED: card_id=${card_id}"
  fi

  exit 0
}

# ── Subcommand: list-active ──────────────────────────────────────────────────
cmd_list_active() {
  local cards_file="$CARDS_FILE"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cards-file) cards_file="$2"; shift 2 ;;
      *) _die "Unknown option: $1" ;;
    esac
  done

  if [[ ! -f "$cards_file" ]]; then
    echo "No cards file at ${cards_file}"
    exit 0
  fi

  _py "
import yaml, json, sys
try:
    with open('${cards_file}') as fh:
        cfg = yaml.safe_load(fh)
    cards = cfg.get('cards', {})
    active = [(k, v) for k, v in cards.items() if v.get('status') == 'active']
    if not active:
        print('No active cards registered.')
        sys.exit(0)
    print(f\"{'NAME':<35} {'ID':<35} {'ORG':<25} {'PAYLOAD':>8}\")
    print('-' * 108)
    for name, card in sorted(active):
        n = name[:34]
        i = card.get('id', '')[:34]
        o = card.get('organization', '')[:24]
        pl = str(card.get('max_payload_level', '?'))
        print(f\"{n:<35} {i:<35} {o:<25} {pl:>8}\")
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
[[ $# -lt 1 ]] && _usage

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  validate)     cmd_validate     "$@" ;;
  verify-key)   cmd_verify_key   "$@" ;;
  list-active)  cmd_list_active  "$@" ;;
  *)            _usage ;;
esac
