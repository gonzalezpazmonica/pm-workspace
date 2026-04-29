#!/usr/bin/env bash
# banner.sh — SPEC-125 Slice 1: render the tribunal verdict banner.
#
# Reads aggregate JSON from stdin (or --file), produces a markdown banner
# string that gets prepended to the draft (WARN) or replaces the draft entirely
# with the vetoed-content-marked version (VETO). PASS produces empty output.
#
# Usage:
#   cat aggregate.json | banner.sh --draft "$(cat draft.txt)"
#   banner.sh --file aggregate.json --draft "..."
#
# Exit codes:
#   0  ok (banner on stdout, may be empty for PASS)
#   2  usage / args invalid
#   3  aggregate file missing
#
# Output format (stdout):
#   PASS  → empty string (caller delivers original draft unchanged)
#   WARN  → "<banner>\n\n<original draft>"
#   VETO  → "<veto banner with original quoted as blocked>"
#
# Reference: SPEC-125 § 4 (banner format).

set -uo pipefail

AGG_FILE=""
DRAFT=""

usage() {
  sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)  AGG_FILE="$2"; shift 2 ;;
    --draft) DRAFT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage ;;
  esac
done

if [[ -z "$DRAFT" ]]; then
  echo "ERROR: --draft <text> required" >&2
  exit 2
fi

# Read aggregate JSON
if [[ -n "$AGG_FILE" ]]; then
  if [[ ! -f "$AGG_FILE" ]]; then
    echo "ERROR: aggregate file not found: $AGG_FILE" >&2
    exit 3
  fi
  AGG=$(cat "$AGG_FILE")
else
  AGG=$(cat)
fi

# Extract verdict using python (consistent with aggregate.sh)
VERDICT=$(python3 -c "
import json,sys
try:
  d = json.loads('''$AGG''')
  print(d.get('verdict','PASS'))
except Exception:
  print('PASS')
" 2>/dev/null)

CONSENSUS=$(python3 -c "
import json,sys
try:
  d = json.loads('''$AGG''')
  s = d.get('consensus_score', 'null')
  print(s)
except Exception:
  print('null')
" 2>/dev/null)

VETO_JUDGES=$(python3 -c "
import json,sys
try:
  d = json.loads('''$AGG''')
  print(','.join(d.get('veto_judges', [])))
except Exception:
  print('')
" 2>/dev/null)

# ── Render per verdict ──────────────────────────────────────────────────────

case "$VERDICT" in
  PASS)
    # Empty output → caller delivers draft unchanged
    :
    ;;

  WARN)
    cat <<EOF
> [TRIBUNAL: WARN] consensus_score=$CONSENSUS — al menos un juez tiene dudas.
> Razones: revisa los archivos de juicio listados en el audit JSON antes de aplicar.
> Considera verificar antes de actuar.

EOF
    printf '%s\n' "$DRAFT"
    ;;

  VETO)
    cat <<EOF
> [TRIBUNAL: VETO] La recomendación que iba a darte contradice tu propia memoria/reglas.
> Jueces que vetaron: ${VETO_JUDGES:-(none cited)}
>
> Recomendación original (NO entregada — marca como bloqueada para auditabilidad):
>
EOF
    # Quote the draft line by line as blockquote
    while IFS= read -r line; do
      printf '> %s\n' "$line"
    done <<< "$DRAFT"
    cat <<EOF
>
> Reformulación obligada: investigar el problema real, no bypassearlo. Si no puedes
> reformular sin contradecir reglas/memoria, abstente explícitamente.
EOF
    ;;

  *)
    echo "ERROR: unknown verdict '$VERDICT'" >&2
    exit 4
    ;;
esac
