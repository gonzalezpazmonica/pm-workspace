#!/usr/bin/env bash
# adaptive-halting.sh — SE-074 Slice 1.5 — double-criterion halting check
#
# Decides whether a parallel-spec worker should stop iterating, based on:
#   1. Convergence: file tree hash unchanged between current and previous iter
#   2. Confidence: judge consensus + test pass rate >= confidence threshold
#
# Inspired by Kohli et al. 2026 "Loop, Think, & Generalize" (arXiv:2604.07822):
# halting requires BOTH small divergence AND high confidence — single criterion
# leads to premature stops or overthinking.
#
# Worker contract:
#   The orchestrated session writes <worktree>/.halt-state.json each iteration:
#     {
#       "iter": <int>,
#       "tree_hash": "<sha256>",
#       "confidence": 0.0-1.0,
#       "tests_passed": <bool>
#     }
#   Halt is granted when:
#     - tree_hash equals previous iteration's tree_hash (convergence)
#     - confidence >= ADAPTIVE_HALT_CONFIDENCE (default 0.75)
#     - tests_passed is true
#
# Usage:
#   bash scripts/adaptive-halting.sh should-halt <worktree>
#       Exit 0 if should halt; exit 1 otherwise. Reason printed to stderr.
#   bash scripts/adaptive-halting.sh tree-hash <worktree>
#       Compute file tree hash for caller (excludes .git, node_modules, .venv).
#
# Env:
#   ADAPTIVE_HALT_CONFIDENCE  default 0.75; valid range [0.50, 0.95]
#
# Reference: SE-074 Slice 1.5 (docs/propuestas/SE-074-parallel-spec-execution.md)
# Reference: Kohli et al. 2026, arXiv:2604.07822

set -uo pipefail

CMD="${1:-}"
WORKTREE="${2:-}"
CONFIDENCE_FLOOR="${ADAPTIVE_HALT_CONFIDENCE:-0.75}"

if [[ -z "${CMD}" || -z "${WORKTREE}" ]]; then
  echo "Usage: adaptive-halting.sh <should-halt|tree-hash> <worktree>" >&2
  exit 2
fi

# Validate confidence in [0.50, 0.95]
if ! awk -v c="${CONFIDENCE_FLOOR}" 'BEGIN { exit !(c >= 0.50 && c <= 0.95) }'; then
  echo "ERROR: ADAPTIVE_HALT_CONFIDENCE must be in [0.50, 0.95] (got ${CONFIDENCE_FLOOR})" >&2
  exit 2
fi

if [[ ! -d "${WORKTREE}" ]]; then
  echo "ERROR: worktree not found: ${WORKTREE}" >&2
  exit 1
fi

case "${CMD}" in
  tree-hash)
    # Hash of all tracked files (excluding common heavy/dynamic dirs)
    cd "${WORKTREE}" || exit 1
    find . -type f \
      -not -path './.git/*' \
      -not -path './node_modules/*' \
      -not -path './.venv/*' \
      -not -path './venv/*' \
      -not -path './.halt-state.json' \
      -not -path './.confidence-score.json' \
      -not -path './output/*' \
      -print0 \
      | sort -z \
      | xargs -0 sha256sum 2>/dev/null \
      | sha256sum \
      | awk '{print $1}'
    ;;

  should-halt)
    STATE_FILE="${WORKTREE}/.halt-state.json"
    PREV_FILE="${WORKTREE}/.halt-state.prev.json"

    if [[ ! -f "${STATE_FILE}" ]]; then
      echo "no-halt: state file missing — first iteration" >&2
      exit 1
    fi

    # Parse current state
    if ! command -v jq >/dev/null 2>&1; then
      echo "ERROR: jq required for halt check" >&2
      exit 2
    fi

    CURRENT_HASH=$(jq -r '.tree_hash // ""' "${STATE_FILE}")
    CURRENT_CONF=$(jq -r '.confidence // 0' "${STATE_FILE}")
    CURRENT_TESTS=$(jq -r '.tests_passed // false' "${STATE_FILE}")

    # First iteration: no previous to compare; record and don't halt
    if [[ ! -f "${PREV_FILE}" ]]; then
      cp "${STATE_FILE}" "${PREV_FILE}"
      echo "no-halt: first iteration (baseline established)" >&2
      exit 1
    fi

    PREV_HASH=$(jq -r '.tree_hash // ""' "${PREV_FILE}")

    # Convergence check
    if [[ "${CURRENT_HASH}" != "${PREV_HASH}" ]]; then
      cp "${STATE_FILE}" "${PREV_FILE}"
      echo "no-halt: tree changed (no convergence)" >&2
      exit 1
    fi

    # Confidence check
    if ! awk -v c="${CURRENT_CONF}" -v floor="${CONFIDENCE_FLOOR}" 'BEGIN { exit !(c >= floor) }'; then
      echo "no-halt: confidence ${CURRENT_CONF} below floor ${CONFIDENCE_FLOOR}" >&2
      exit 1
    fi

    # Tests check
    if [[ "${CURRENT_TESTS}" != "true" ]]; then
      echo "no-halt: tests not passing" >&2
      exit 1
    fi

    echo "halt: convergence + confidence ${CURRENT_CONF} >= ${CONFIDENCE_FLOOR} + tests pass" >&2
    exit 0
    ;;

  *)
    echo "Unknown command: ${CMD}" >&2
    echo "Usage: adaptive-halting.sh <should-halt|tree-hash> <worktree>" >&2
    exit 2
    ;;
esac
