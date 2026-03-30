#!/usr/bin/env bash
# test-coverage-checker.sh — Verify every script has a corresponding test
# SPEC-055: Reports missing tests for scripts/ (mandatory)
# Usage: bash scripts/test-coverage-checker.sh [--json]
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JSON_MODE=false
[[ "${1:-}" == "--json" ]] && JSON_MODE=true

MISSING=()
COVERED=0
TOTAL=0

for script in "$PROJECT_ROOT"/scripts/*.sh; do
  [[ -f "$script" ]] || continue
  base=$(basename "$script" .sh)
  [[ "$base" == test-* || "$base" == test_* ]] && continue
  ((TOTAL++))
  found=false
  for pat in "test-${base}.bats" "test_${base}.bats"; do
    if find "$PROJECT_ROOT/tests" -name "$pat" -type f 2>/dev/null | grep -q .; then
      found=true; break
    fi
  done
  $found && ((COVERED++)) || MISSING+=("$base")
done

COV=$(( TOTAL > 0 ? COVERED * 100 / TOTAL : 100 ))

if $JSON_MODE; then
  M_JSON=$(printf '"%s",' "${MISSING[@]}" 2>/dev/null | sed 's/,$//')
  cat <<EOF
{"mandatory_total":$TOTAL,"mandatory_covered":$COVERED,"coverage_percent":$COV,"missing_mandatory":[${M_JSON:-}]}
EOF
else
  echo "Test Coverage: $COVERED / $TOTAL scripts ($COV%)"
  if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Missing tests:"
    for m in "${MISSING[@]}"; do echo "  - scripts/$m.sh"; done
  fi
fi
