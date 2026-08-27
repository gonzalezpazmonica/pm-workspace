#!/usr/bin/env bash
# test-coverage-ratchet.sh — Ratchet no-decreciente de cobertura (SE-339)
#
# Mide cuántos hooks CRÍTICOS (tests/hooks/critical-hooks.txt) tienen test
# BATS y falla en --ci si el ratio baja del umbral. El umbral es persistente
# en config/test-coverage.conf y NUNCA se baja para que CI pase (RN-01).
# No genera tests automáticamente (CRIT-009). PURE_BASH, sin red (CRIT-001).
#
# Uso:
#   test-coverage-ratchet.sh [--threshold N] [--ci] [--conf FILE]
#     --threshold N   % mínimo de hooks críticos con BATS (default 100);
#                     si se pasa, se persiste en config/test-coverage.conf
#     --ci            exit 1 si cobertura < umbral
#   Exit: 0 ok · 1 FAIL · 2 usage

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CRITICAL_FILE="${SAVIA_CRITICAL_HOOKS_FILE:-$ROOT/tests/hooks/critical-hooks.txt}"
CONF_FILE="$ROOT/config/test-coverage.conf"
CI=false
PERSIST=false
THRESHOLD=100

# Baseline: umbral desde conf (si existe); el flag --threshold lo sobreescribe
if [[ -f "$CONF_FILE" ]]; then
  # shellcheck disable=SC1091
  source "$CONF_FILE" 2>/dev/null || true
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold) THRESHOLD="$2"; PERSIST=true; shift 2 ;;
    --ci) CI=true; shift ;;
    --conf) CONF_FILE="$2"; shift 2 ;;
    --help|-h) sed -n '2,15p' "${BASH_SOURCE[0]}" | grep -E '^#' | sed 's/^#//'; exit 0 ;;
    *) echo "Uso: test-coverage-ratchet.sh [--threshold N] [--ci]" >&2; exit 2 ;;
  esac
done

# Persistir umbral explícito (RN-01: el umbral vive en conf, no en el flag diario)
if $PERSIST; then
  mkdir -p "$(dirname "$CONF_FILE")"
  printf 'THRESHOLD=%s\n' "$THRESHOLD" > "$CONF_FILE"
  echo "  (umbral persistido: THRESHOLD=$THRESHOLD en $CONF_FILE)"
fi

[[ -f "$CRITICAL_FILE" ]] || { echo "ERROR: $CRITICAL_FILE no existe" >&2; exit 2; }

hooks=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="${line//[[:space:]]/}"
  [[ -n "$line" ]] && hooks+=("$line")
done < "$CRITICAL_FILE"

total=${#hooks[@]}
covered=0
uncovered=()
for h in "${hooks[@]}"; do
  # Cubierto si algún .bats referencia el script del hook (<name>.sh o su path)
  if grep -rl "${h}.sh" "$ROOT/tests" --include="*.bats" >/dev/null 2>&1; then
    covered=$((covered + 1))
  else
    uncovered+=("$h")
  fi
done

ratio=$(( 100 * covered / total ))   # floor

echo "test-coverage-ratchet: $covered/$total hooks críticos con BATS ($ratio%)"
if [[ ${#uncovered[@]} -gt 0 ]]; then
  echo "  SIN TEST (generar incrementalmente):"
  for h in "${uncovered[@]}"; do echo "    - $h"; done
fi

if $CI; then
  if (( ratio < THRESHOLD )); then
    echo "FAIL: cobertura $ratio% < umbral $THRESHOLD% (RN-01: no bajar el umbral para que CI pase)" >&2
    exit 1
  fi
  echo "OK: cobertura $ratio% >= umbral $THRESHOLD%"
fi
exit 0
