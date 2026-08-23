#!/usr/bin/env bash
# test-coverage-ratchet.sh — SE-339: ratchet de cobertura de tests para hooks críticos
# Ref: docs/specs/SE-339-test-coverage-ratchet.spec.md
# Cierra deuda 2.1 (test-coverage 23%): asegura que los hooks de seguridad
# críticos tienen test BATS, con umbral no-decreciente.
#
# Usage:
#   bash scripts/test-coverage-ratchet.sh                # report
#   bash scripts/test-coverage-ratchet.sh --threshold N  # umbral custom
#   bash scripts/test-coverage-ratchet.sh --ci           # exit 1 si < umbral
#
# Exit: 0 ok · 1 FAIL (cobertura < umbral) · 2 usage
# PURE_BASH — sin LLM, sin red (CRIT-001, RN-04).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

THRESHOLD=100
CI_MODE=false
ALLOWLIST="$ROOT/tests/hooks/critical-hooks.txt"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --ci) CI_MODE=true; shift ;;
    -h|--help)
      sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "ERROR: opcion desconocida: $1" >&2; exit 2 ;;
  esac
done

[[ "$THRESHOLD" =~ ^[0-9]+$ ]] || { echo "ERROR: --threshold debe ser entero" >&2; exit 2; }
[[ -f "$ALLOWLIST" ]] || { echo "ERROR: allowlist no encontrada: $ALLOWLIST" >&2; exit 2; }

HOOK_DIR="$ROOT/.claude/hooks"
TOTAL=0; COVERED=0; UNCOVERED=()

while IFS= read -r hook; do
  [[ -z "$hook" ]] && continue
  [[ "$hook" == \#* ]] && continue
  TOTAL=$((TOTAL + 1))
  HOOK_FILE="$HOOK_DIR/$hook.sh"
  [[ -f "$HOOK_FILE" ]] || { UNCOVERED+=("$hook (no existe el hook)"); continue; }
  # pipefail-safe: test -f explícito (un glob sin match no rompe el pipeline)
  if [[ -f "$ROOT/tests/test-$hook.bats" || -f "$ROOT/tests/hooks/test-$hook.bats" ]]; then
    COVERED=$((COVERED + 1))
  else
    UNCOVERED+=("$hook")
  fi
done < "$ALLOWLIST"

if [[ "$TOTAL" -eq 0 ]]; then
  echo "ERROR: allowlist vacia" >&2; exit 2
fi

PCT=$(( COVERED * 100 / TOTAL ))

echo "=== Test Coverage Ratchet (SE-339) ==="
echo "  Hooks criticos: $TOTAL  cubiertos: $COVERED  cobertura: ${PCT}% (umbral ${THRESHOLD}%)"
if [[ ${#UNCOVERED[@]} -gt 0 ]]; then
  echo "  Sin test BATS:"
  for h in "${UNCOVERED[@]}"; do echo "    - $h"; done
fi

if $CI_MODE; then
  if [[ "$PCT" -lt "$THRESHOLD" ]]; then
    echo "FAIL: cobertura ${PCT}% < umbral ${THRESHOLD}% — añade BATS a los hooks listados"
    exit 1
  fi
  echo "PASS: cobertura ${PCT}% >= ${THRESHOLD}%"
fi
exit 0