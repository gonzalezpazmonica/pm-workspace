#!/usr/bin/env bash
# debt-budget-check.sh — SE-376: verifica deuda actual <= target del wave activo.
# Nunca sube baseline: un target mayor que en origin/main = fallo.
set -uo pipefail
ROOT="${1:-.}"
YAML="$ROOT/docs/propuestas/SE-376-debt-budget.yaml"
[[ -f "$YAML" ]] || { echo "FAIL: no hay SE-376-debt-budget.yaml"; exit 1; }

WAVE=$(grep -oP '^current_wave:\s*\K[0-9]+' "$YAML")
TARGET=$(grep -oP "^\s*${WAVE}:\s*\K[0-9]+" "$YAML")
[[ -n "$WAVE" && -n "$TARGET" ]] || { echo "FAIL: budget yaml malformado"; exit 1; }

# anti-baseline-raise: el target del wave activo no puede crecer vs origin/main
if git -C "$ROOT" rev-parse --verify -q origin/main >/dev/null; then
  OLD_TARGET=$(git -C "$ROOT" show "origin/main:docs/propuestas/SE-376-debt-budget.yaml" 2>/dev/null \
    | grep -oP "^\s*${WAVE}:\s*\K[0-9]+" || true)
  [[ -n "$OLD_TARGET" && "$TARGET" -gt "$OLD_TARGET" ]] && {
    echo "FAIL: target del wave $WAVE subió ($OLD_TARGET -> $TARGET) — ratchet violated"; exit 1; }
fi

CURRENT=$(bash "$ROOT/scripts/skill-maturity-audit.sh" 2>/dev/null \
  | awk '/Total:/{t=$2} /Calibrated:/{c=$2} END{print t-c}')
[[ -n "$CURRENT" ]] || { echo "FAIL: no se pudo medir la deuda"; exit 1; }

if [[ "$CURRENT" -gt "$TARGET" ]]; then
  echo "FAIL: deuda actual ($CURRENT) > target wave $WAVE ($TARGET)"
  exit 1
fi
echo "PASS: deuda $CURRENT <= target wave $WAVE ($TARGET)"
[[ "$WAVE" == "0" ]] && echo "INFO: wave 0 = baseline freeze; avanzar wave requiere decisión humana"
exit 0
