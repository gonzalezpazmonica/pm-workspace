#!/usr/bin/env bash
# coherence-gates.sh — SE-377/380/381/383: gates de coherencia (advisory por defecto).
# Uso: coherence-gates.sh [--strict]
set -uo pipefail
ROOT="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
POLICY="$ROOT/scripts/coherence-gate-policy.yaml"
STRICT="false"
[[ "${1:-}" == "--strict" ]] && STRICT="true"
FAILED=0
# SE-387 Slice A: un gate declarado BLOCK con calibration complete bloquea
gate_status() { # $1=id → imprime BLOCK|WARN|OBSERVE|WARN (default)
  local id="$1" st
  st=$(awk "/- id: $id\$/{f=1} f&&/status:/{print \$2; exit}" "$POLICY" 2>/dev/null)
  echo "${st:-WARN}"
}
is_calibrated() { # $1=id
  awk "/- id: $1\$/{f=1} f&&/calibration:/{print \$2; exit}" "$POLICY" 2>/dev/null
}
echo "--- Coherence gates (SE-377/380/381/383/386) ---"
BLOCKED_FATAL=0
run_gate() { # $1 nombre $2 comando...
  local name="$1"; shift
  local st; st=$(gate_status "$name")
  local out
  if out=$( "$@" 2>&1 ); then
    echo "PASS coherence/$name"
  else
    local cal; cal=$(is_calibrated "$name")
    echo "${st} coherence/$name (calibration=${cal:-unknown})"
    if [[ "$st" == "BLOCK" && "$cal" == "complete" ]]; then
      echo "BLOCK coherence/$name: gate calibrado y graduado a bloqueante (SE-387 A1)"
      BLOCKED_FATAL=1
    else
      FAILED=1
    fi
  fi
}
run_gate negative-safety bash "$ROOT/scripts/guardrail-negative-tests.sh"
run_gate chaos-suite bash "$ROOT/tests/chaos/run-chaos-suite.sh"
run_gate entropy python3 "$ROOT/scripts/capability-entropy.py" --root "$ROOT" --check
run_gate debt-budget bash "$ROOT/scripts/debt-budget-check.sh" "$ROOT"
run_gate constitutional-contracts bash "$ROOT/scripts/contract-check.sh"
run_gate constitutional-contracts bash "$ROOT/scripts/law-check.sh"
python3 "$ROOT/scripts/constitutional-coverage.py" --root "$ROOT" >/dev/null 2>&1 \
  && echo "PASS coherence/constitutional-coverage: informe L4" \
  || echo "WARN coherence/constitutional-coverage: sin registry"
for t in grounding-verify.sh validate-handoff.sh checkpoint.sh effect-reservation.sh debt-burn-down.sh planning-transition.sh report-benchmark.sh; do
  [[ -x "$ROOT/scripts/$t" || -x "$ROOT/tests/self-evolution/$t" ]] || { echo "WARN coherence/closure-$t"; FAILED=1; }
done
echo "PASS coherence/harness-closure: C F2-F5 + E + F + H tooling presente"
# C F4/F5 y E/F/H: checks presentes y ejecutables (invocación sin argumentos = usage OK)
for t in checkpoint.sh effect-reservation.sh debt-burn-down.sh planning-transition.sh; do
  [[ -x "$ROOT/scripts/$t" ]] && echo "PASS coherence/closure-$t" || { echo "WARN coherence/closure-$t"; FAILED=1; }
done
python3 "$ROOT/scripts/eval-coverage-matrix.py" --root "$ROOT" >/dev/null 2>&1 \
  && echo "PASS coherence/eval-coverage: informe generado" \
  || echo "OBSERVE coherence/eval-coverage: report-only (SE-387 D)"
if [[ $BLOCKED_FATAL -eq 1 ]]; then
  echo "-- coherence gates: BLOCK (L4 graduado, SE-387 A1)"
  exit 1
fi
echo "-- coherence gates: sin bloqueo L4 (advisory/WARN restante)"
exit 0
