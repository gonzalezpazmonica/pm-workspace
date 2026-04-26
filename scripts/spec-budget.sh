#!/usr/bin/env bash
# spec-budget.sh — SE-074 Slice 1.5 — dynamic retry budget per spec effort
#
# Maps spec effort field (S/M/L) to a Poisson-clipped retry budget.
# Inspired by Kohli et al. 2026 "Loop, Think, & Generalize" (arXiv:2604.07822):
# variable iteration count per task instead of fixed limit avoids both
# under-allocating (small tasks fail) and overthinking (large tasks waste
# compute past convergence).
#
# Algorithm: budget(spec) = clip(Poisson(lambda_effort), 2, 8)
#   lambda_S=2, lambda_M=3, lambda_L=5
#
# Determinism: when SPEC_BUDGET_DETERMINISTIC=1 (default in tests/CI),
# returns lambda directly without sampling. Production: pseudo-Poisson via
# Knuth algorithm seeded by hash(spec_id).
#
# Usage:
#   bash scripts/spec-budget.sh <effort>            # one of S, M, L
#   bash scripts/spec-budget.sh <effort> <spec_id>  # deterministic seed
#
# Exit codes:
#   0 — budget printed to stdout
#   2 — invalid effort
#
# Reference: SE-074 Slice 1.5 (docs/propuestas/SE-074-parallel-spec-execution.md)
# Reference: Kohli et al. 2026, arXiv:2604.07822

set -uo pipefail

EFFORT="${1:-}"
SPEC_ID="${2:-default}"
R_MIN="${SPEC_BUDGET_R_MIN:-2}"
R_MAX="${SPEC_BUDGET_R_MAX:-8}"
DETERMINISTIC="${SPEC_BUDGET_DETERMINISTIC:-1}"

if [[ -z "${EFFORT}" ]]; then
  echo "Usage: spec-budget.sh <S|M|L> [spec_id]" >&2
  exit 2
fi

case "${EFFORT^^}" in
  S) LAMBDA=2 ;;
  M) LAMBDA=3 ;;
  L) LAMBDA=5 ;;
  *) echo "ERROR: effort must be one of S, M, L (got: ${EFFORT})" >&2; exit 2 ;;
esac

# Clip helper
clip() {
  local v="$1" lo="$2" hi="$3"
  if [[ "$v" -lt "$lo" ]]; then v=$lo; fi
  if [[ "$v" -gt "$hi" ]]; then v=$hi; fi
  echo "$v"
}

if [[ "${DETERMINISTIC}" == "1" ]]; then
  # Deterministic mode: return lambda clipped (used in tests/CI for repeatability)
  clip "${LAMBDA}" "${R_MIN}" "${R_MAX}"
  exit 0
fi

# Poisson sample via Knuth algorithm, seeded by hash(spec_id) for reproducibility per spec
SEED=$(echo -n "${SPEC_ID}" | cksum | awk '{print $1}')
RANDOM=$((SEED % 32768))

# Knuth Poisson: returns k such that product of uniform(0,1) drops below e^-lambda
# bash lacks float; integer arithmetic via 1e6 scaling
# poisson_limit = e^-lambda × 1e6  (precomputed for the 3 effort tiers)
case "${LAMBDA}" in
  2) POISSON_LIMIT=135335 ;; # e^-2 × 1e6
  3) POISSON_LIMIT=49787 ;;  # e^-3 × 1e6
  5) POISSON_LIMIT=6738 ;;   # e^-5 × 1e6
  *) POISSON_LIMIT=135335 ;;
esac

PRODUCT=1000000
K=0
MAX_ITER=20  # bound iterations: bash RANDOM has bias, prevent runaway
while [[ "${PRODUCT}" -gt "${POISSON_LIMIT}" && "${K}" -lt "${MAX_ITER}" ]]; do
  K=$((K + 1))
  U=$((RANDOM % 1000000 + 1))
  PRODUCT=$((PRODUCT * U / 1000000))
done

# Knuth returns k-1 (k is the count where product first dropped below)
SAMPLED=$((K > 0 ? K - 1 : 0))
clip "${SAMPLED}" "${R_MIN}" "${R_MAX}"
