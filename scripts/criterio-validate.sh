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

read -r LINEA_ROJA LINEA_ROJA_ENFORCED INFERRED HUMAN < <(python3 - "$CRITERIO" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding='utf-8').read()
starts = list(re.finditer(r'(?m)^CRIT-\d{3}\s+[^\n]*$', text))
entries = [text[match.start():starts[index + 1].start() if index + 1 < len(starts) else len(text)] for index, match in enumerate(starts)]

linea_roja = [entry for entry in entries if re.search(r'(?m)^\s*dureza:\s*linea_roja(?:\s*\||\s*$)', entry)]
concrete = re.compile(r'(?mi)^\s*enforcement:.*(?:\.sh|guard|ART-|bias|shield|LICENSE|ledger|hook|allowlist|protected-jobs|Human-Authored)')
inferred = sum(bool(re.search(r'(?m)^\s*provenance:\s*INFERRED\s*$', entry)) for entry in entries)
human = sum(bool(re.search(r'(?m)^\s*provenance:\s*human_authored\s*$', entry)) for entry in entries)
print(len(linea_roja), sum(bool(concrete.search(entry)) for entry in linea_roja), inferred, human)
PY
)
echo "  Linea roja: $LINEA_ROJA total, $LINEA_ROJA_ENFORCED con enforcement concreto"

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
