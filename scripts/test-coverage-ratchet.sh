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
#                     si se pasa, se persiste en --conf; nunca por debajo del persistido
#     --ci            exit 1 si cobertura < umbral
#   Exit: 0 ok · 1 FAIL · 2 usage

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CRITICAL_FILE="${SAVIA_CRITICAL_HOOKS_FILE:-$ROOT/tests/hooks/critical-hooks.txt}"
CONF_FILE="$ROOT/config/test-coverage.conf"
CI=false
PERSIST=false
THRESHOLD_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold) [[ $# -ge 2 ]] || { echo "ERROR: --threshold requiere valor" >&2; exit 2; }
                 THRESHOLD_ARG="$2"; PERSIST=true; shift 2 ;;
    --ci) CI=true; shift ;;
    --conf) [[ $# -ge 2 ]] || { echo "ERROR: --conf requiere valor" >&2; exit 2; }
            CONF_FILE="$2"; shift 2 ;;
    --help|-h) sed -n '2,15p' "${BASH_SOURCE[0]}" | grep -E '^#' | sed 's/^#//'; exit 0 ;;
    *) echo "Uso: test-coverage-ratchet.sh [--threshold N] [--ci] [--conf FILE]" >&2; exit 2 ;;
  esac
done

if [[ -n "$THRESHOLD_ARG" && ! "$THRESHOLD_ARG" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --threshold debe ser un entero >= 0: $THRESHOLD_ARG" >&2
  exit 2
fi
[[ -n "$THRESHOLD_ARG" ]] && THRESHOLD_ARG=$((10#$THRESHOLD_ARG))

# Baseline persistido (tras parsear, para que --conf apunte al fichero correcto).
# Se lee como dato, no con source: el conf no ejecuta código.
THRESHOLD=100
if [[ -f "$CONF_FILE" ]]; then
  persisted=$(sed -n 's/^THRESHOLD=\([0-9][0-9]*\)[[:space:]]*$/\1/p' "$CONF_FILE" | head -1)
  [[ -n "$persisted" ]] && THRESHOLD=$((10#$persisted))
fi

# Persistir umbral explícito (RN-01: el umbral vive en conf y es no-decreciente;
# bajarlo exige editar el conf en un PR revisado, no un flag).
if $PERSIST; then
  if (( THRESHOLD_ARG < THRESHOLD )); then
    echo "ERROR: RN-01 — el umbral no baja por flag ($THRESHOLD_ARG < $THRESHOLD persistido en $CONF_FILE)" >&2
    exit 2
  fi
  THRESHOLD="$THRESHOLD_ARG"
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
