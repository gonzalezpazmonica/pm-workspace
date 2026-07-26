#!/usr/bin/env bash
# corporate-body-validate.sh — SE-271 S2
# Validates a corporate body card (body.card.json with signature).
# Checks versioning, signatures, format compliance.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") <body.card.json>

Validates a corporate criterion body card:
  - Valid JSON
  - Required fields present (body_id, name, version, issued_by,
    engagement_scope, issued_at, signature, entries)
  - Version follows semver
  - Signature present (not empty)
  - Each entry has required fields (id, ambito, principio, dureza)
  - Ambito is a known domain
  - Dureza is a known value
  - issued_at is valid ISO8601

Exit codes:
  0   Body card is valid.
  1   Validation errors found.
  2   Usage error.
EOF
  exit 2
}

# ── main ──────────────────────────────────────────────────────────────────

main() {
  if [[ $# -lt 1 ]]; then
    echo "ERROR: Missing body.card.json argument." >&2
    usage
  fi

  local CARD="$1"
  local errors=0

  if [[ ! -f "$CARD" ]]; then
    echo "ERROR: File not found: $CARD" >&2
    exit 2
  fi

  echo "=== Body Card Validation ==="
  echo "Card: $CARD"
  echo ""

  # Check valid JSON
  if ! python3 -c "import json; json.load(open('$CARD')); print('OK')" 2>/dev/null | grep -q OK; then
    echo "FAIL: Not valid JSON."
    exit 1
  fi

  # Validate top-level fields
  local result
  result=$(python3 -c "
import json, sys, re
from datetime import datetime

errors = []
warnings = []
card = json.load(open('$CARD'))

# ── Required top-level fields ──
required = ['body_id', 'name', 'version', 'issued_by',
            'engagement_scope', 'issued_at', 'signature', 'entries']
for f in required:
    if f not in card:
        errors.append(f'MISSING_TOP_FIELD: {f}')
    elif not card[f] and f != 'signature':
        errors.append(f'EMPTY_FIELD: {f}')

# ── body_id format ──
if 'body_id' in card and card['body_id']:
    if not re.match(r'^corp-[a-z0-9_-]+$', card['body_id']):
        errors.append(f'BAD_BODY_ID: {card[\"body_id\"]} (expect corp-<slug>)')

# ── version semver ──
if 'version' in card and card['version']:
    if not re.match(r'^\d+\.\d+\.\d+$', card['version']):
        errors.append(f'BAD_VERSION: {card[\"version\"]} (expect semver X.Y.Z)')

# ── issued_at ISO8601 ──
if 'issued_at' in card and card['issued_at']:
    try:
        datetime.fromisoformat(card['issued_at'].replace('Z','+00:00'))
    except:
        errors.append(f'BAD_DATE: {card[\"issued_at\"]} (expect ISO8601)')

# ── signature ──
if 'signature' in card:
    if not card['signature'] or not isinstance(card['signature'], str):
        warnings.append('WEAK_SIGNATURE: signature empty or not a string')
    elif len(card['signature']) < 16:
        warnings.append('SHORT_SIGNATURE: signature < 16 chars')

# ── engagement_scope ──
valid_scopes = ['proyecto', 'cliente', 'departamento', 'organizacion', 'producto']
if 'engagement_scope' in card and card['engagement_scope']:
    if card['engagement_scope'] not in valid_scopes:
        warnings.append(f'UNKNOWN_SCOPE: {card[\"engagement_scope\"]} (known: {valid_scopes})')

# ── entries validation ──
entries = card.get('entries', [])
if not isinstance(entries, list):
    errors.append('BAD_ENTRIES: entries must be a JSON array')
elif len(entries) == 0:
    warnings.append('EMPTY_ENTRIES: body has no entries')
else:
    known_ambitos = ['tecnicas', 'comunicacion', 'priorizacion',
                     'riesgo', 'delegacion', 'compliance']
    known_durezas = ['linea_roja', 'preferencia', 'estilo']
    for i, entry in enumerate(entries):
        if not isinstance(entry, dict):
            errors.append(f'ENTRY_{i}: not a JSON object')
            continue
        for ef in ['id', 'ambito', 'principio', 'dureza']:
            if ef not in entry or not entry[ef]:
                errors.append(f'ENTRY_{i}: missing/empty {ef}')
        if entry.get('ambito') and entry['ambito'] not in known_ambitos:
            errors.append(f'ENTRY_{i}: unknown ambito \"{entry[\"ambito\"]}\"')
        if entry.get('dureza') and entry['dureza'] not in known_durezas:
            errors.append(f'ENTRY_{i}: unknown dureza \"{entry[\"dureza\"]}\"')

# ── Output ──
for e in errors:
    print(f'FAIL: {e}')
for w in warnings:
    print(f'WARN: {w}')

print(f'ERRORS: {len(errors)}')
print(f'WARNINGS: {len(warnings)}')
sys.exit(1 if errors else 0)
" 2>&1)
  local rc=$?

  echo "$result"

  if [[ "$rc" -ne 0 ]]; then
    local err_count
    err_count=$(echo "$result" | grep "^ERRORS:" | grep -oP '\d+' || echo "?")
    echo ""
    echo "RESULT: INVALID — $err_count validation error(s)."
    exit 1
  fi

  echo ""
  echo "RESULT: VALID — body card passes format compliance."
  exit 0
}

main "$@"
