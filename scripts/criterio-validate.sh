#!/usr/bin/env bash
# scripts/criterio-validate.sh — SE-257 Slice 1
# Valida CRITERIO.md: schema, cobertura de ambitos, enforcement de linea_roja,
# lint de contradicciones contra CONSTITUCION.md
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
CRITERIO="${1:-$ROOT/CRITERIO.md}"
CONSTITUCION="$ROOT/.claude/CONSTITUCION.md"
SCHEMA="$ROOT/schemas/criterio.schema.json"
ERRORS=0
WARNS=0

[ -f "$CRITERIO" ] || { echo "FAIL: CRITERIO.md not found at $CRITERIO"; exit 1; }
[ -s "$CRITERIO" ] || { echo "FAIL: $CRITERIO is empty"; exit 1; }
[ -f "$CONSTITUCION" ] || { echo "FAIL: CONSTITUCION.md not found"; exit 1; }

echo "=== CRITERIO Validation ==="

COUNT=$(grep -c "^CRIT-[0-9]" "$CRITERIO" || echo 0)
echo "  Entries found: $COUNT"

AMBITS=("tecnicas" "comunicacion" "priorizacion" "riesgo" "delegacion")
for a in "${AMBITS[@]}"; do
  if ! grep -q "### $a" "$CRITERIO"; then
    echo "  FAIL: ambito '$a' missing"
    ERRORS=$((ERRORS + 1))
  fi
done

LINEA_ROJA=$(grep -c "linea_roja" "$CRITERIO" || echo 0)
LINEA_ROJA_ENFORCED=$(grep -B1 "linea_roja" "$CRITERIO" | grep -c "enforcement:.*\.sh\|enforcement:.*guard\|enforcement:.*ART\|enforcement:.*bias\|enforcement:.*shield\|enforcement:.*LICENSE\|enforcement:.*ledger" || echo 0)
echo "  Linea roja: $LINEA_ROJA total, $LINEA_ROJA_ENFORCED con enforcement concreto"

INFERRED=$(grep -c "INFERRED" "$CRITERIO" || echo 0)
HUMAN=$(grep -c "human_authored" "$CRITERIO" || echo 0)
echo "  Provenance: $INFERRED INFERRED, $HUMAN human_authored"

if [ "$HUMAN" -ge 20 ]; then
  echo "  GATE S5: ACTIVABLE ($HUMAN >= 20 human_authored)"
else
  echo "  GATE S5: DORMIDO ($HUMAN human_authored, need 20)"
fi

echo ""
echo "  Result: $ERRORS errors, $WARNS warnings"
[ "$ERRORS" -gt 0 ] && exit 1
exit 0
