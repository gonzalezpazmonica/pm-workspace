#!/usr/bin/env bash
export LC_ALL=C
# learning-report.sh — SCL-001 S3: reporte periódico de aprendizaje (ventana)
#
# Consolida el bucle: cuántas propuestas se capturaron, cuántas se activaron,
# y el ΔL de p_consistent medido entre inicio y fin de ventana. Si ΔL ≤ 0 y
# hubo 0 activaciones, emite la cadena "Savia no aprendió esta ventana" — el
# no-aprendizaje es resultado de primera clase (ART-04, radical honesty).
#
# Determinista: lee un JSON de entrada con los conteos; no ejecuta nada más.
#
# Usage:
#   learning-report.sh --window <id> \
#     --captured <N> --activated <N> \
#     --p-consistent-before <0-1> --p-consistent-after <0-1> \
#     [--output <path>] [--json]
#
# Exit codes: 0 ok, 2 usage
#
# Ref: docs/specs/SCL-001-aprendizaje-continuo.spec.md (S3, AC-3.3)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WINDOW=""; CAPTURED=""; ACTIVATED=""; P_BEFORE=""; P_AFTER=""
OUTPUT=""
JSON=false

usage() {
  sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --window) WINDOW="$2"; shift 2 ;;
    --captured) CAPTURED="$2"; shift 2 ;;
    --activated) ACTIVATED="$2"; shift 2 ;;
    --p-consistent-before) P_BEFORE="$2"; shift 2 ;;
    --p-consistent-after) P_AFTER="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --json) JSON=true; shift ;;
    -h|--help) usage ;;
    *) shift ;;
  esac
done

[[ -z "$WINDOW" || -z "$CAPTURED" || -z "$ACTIVATED" || -z "$P_BEFORE" || -z "$P_AFTER" ]] && usage

# ΔL measured via the deterministic metric (weights 0.5/0.3/0.2, divergence+ignorance neutral by default)
L_BEFORE=$(awk -v p="$P_BEFORE" 'BEGIN{printf "%.6f", 0.5*p + 0.3*1 + 0.2*1}')
L_AFTER=$(awk -v p="$P_AFTER" 'BEGIN{printf "%.6f", 0.5*p + 0.3*1 + 0.2*1}')
DELTA=$(awk -v a="$L_AFTER" -v b="$L_BEFORE" 'BEGIN{printf "%.6f", a-b}')

LEARNED=true
if awk -v d="$DELTA" 'BEGIN{exit !(d<=0)}' && [[ "$ACTIVATED" -eq 0 ]]; then
  LEARNED=false
fi

VERDICT="Savia aprendió esta ventana"
if [[ "$LEARNED" == "false" ]]; then
  VERDICT="Savia no aprendió esta ventana"
fi

if $JSON; then
  printf '{"window":"%s","captured":%s,"activated":%s,"p_consistent_before":%s,"p_consistent_after":%s,"L_before":%s,"L_after":%s,"delta_L":%s,"verdict":"%s","learned":%s}\n' \
    "$WINDOW" "$CAPTURED" "$ACTIVATED" "$P_BEFORE" "$P_AFTER" "$L_BEFORE" "$L_AFTER" "$DELTA" "$VERDICT" "$LEARNED"
else
  echo "=== Reporte de aprendizaje: $WINDOW ==="
  echo "Propuestas capturadas: $CAPTURED"
  echo "Propuestas activadas:  $ACTIVATED"
  echo "p_consistent: $P_BEFORE → $P_AFTER"
  echo "L: $L_BEFORE → $L_AFTER (ΔL=$DELTA)"
  echo ""
  echo "$VERDICT"
fi

if [[ -n "$OUTPUT" ]]; then
  mkdir -p "$(dirname "$OUTPUT")"
  printf '{"window":"%s","captured":%s,"activated":%s,"p_consistent_before":%s,"p_consistent_after":%s,"L_before":%s,"L_after":%s,"delta_L":%s,"verdict":"%s","learned":%s}\n' \
    "$WINDOW" "$CAPTURED" "$ACTIVATED" "$P_BEFORE" "$P_AFTER" "$L_BEFORE" "$L_AFTER" "$DELTA" "$VERDICT" "$LEARNED" > "$OUTPUT"
fi
exit 0
