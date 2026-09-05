#!/usr/bin/env bash
# coherence-gates.sh — SE-377/380/381/383: gates de coherencia (advisory por defecto).
# Uso: coherence-gates.sh [--strict]
set -uo pipefail
ROOT="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
STRICT="false"
[[ "${1:-}" == "--strict" ]] && STRICT="true"
FAILED=0
echo "--- Coherence gates (SE-377/380/381/383) ---"
if OUT=$(bash "$ROOT/scripts/guardrail-negative-tests.sh" 2>&1); then
  echo "PASS coherence/negative-tests: $(echo "$OUT" | tail -1)"
else
  echo "WARN coherence/negative-tests: $(echo "$OUT" | tail -1)"; FAILED=1
fi
if OUT=$(bash "$ROOT/tests/chaos/run-chaos-suite.sh" 2>&1 | tail -1); then
  echo "PASS coherence/chaos-suite: $OUT"
else
  echo "WARN coherence/chaos-suite: $OUT"; FAILED=1
fi
if OUT=$(python3 "$ROOT/scripts/capability-entropy.py" --root "$ROOT" --check 2>&1); then
  echo "PASS coherence/entropy: $OUT"
else
  echo "WARN coherence/entropy: $OUT"; FAILED=1
fi
if OUT=$(bash "$ROOT/scripts/debt-budget-check.sh" "$ROOT" 2>&1); then
  echo "PASS coherence/debt-budget: $(echo "$OUT" | head -1)"
else
  echo "WARN coherence/debt-budget: $OUT"; FAILED=1
fi
python3 "$ROOT/scripts/eval-coverage-matrix.py" --root "$ROOT" >/dev/null 2>&1 \
  && echo "PASS coherence/eval-coverage: informe generado" \
  || { echo "WARN coherence/eval-coverage: sin registry"; FAILED=1; }
if [[ "$STRICT" == "true" && $FAILED -eq 1 ]]; then
  echo "-- coherence gates: FAIL en modo estricto"; exit 1
fi
echo "-- coherence gates: advisory OK"
exit 0
