#!/usr/bin/env bash
# learning-rollback.sh — SCL-001 S2: rollback instantáneo de una entrada del sustrato
#
# Deshace la activación (o última transición) de una learning proposal o entrada
# de criterio/memoria/skill a su estado anterior, vía git, dejando:
#   - el sustrato idéntico al estado previo (diff vacío salvo registro),
#   - un registro auditable del motivo y del p_consistent antes/después.
#
# No es un `git revert` manual del operador: es un comando que registra POR QUÉ
# se revirtió (feedback para el bucle). Reversible por diseño (CRIT-022).
#
# Usage:
#   learning-rollback.sh --file <path> --reason <motivo> \
#     [--p-before <L>] [--p-after <L>] [--ledger <path>] [--no-git]
#
# Exit codes: 0 ok, 2 usage, 3 file missing/unchanged
#
# Ref: docs/specs/SCL-001-aprendizaje-continuo.spec.md (S2, AC-2.3)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FILE=""
REASON=""
P_BEFORE=""
P_AFTER=""
LEDGER="${SCL_LEDGER:-$ROOT/output/learning-loop/rollback.jsonl}"
NO_GIT=false

usage() {
  sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE="$2"; shift 2 ;;
    --reason) REASON="$2"; shift 2 ;;
    --p-before) P_BEFORE="$2"; shift 2 ;;
    --p-after) P_AFTER="$2"; shift 2 ;;
    --ledger) LEDGER="$2"; shift 2 ;;
    --no-git) NO_GIT=true; shift ;;
    -h|--help) usage ;;
    *) shift ;;
  esac
done

[[ -z "$FILE" || -z "$REASON" ]] && usage
[[ -f "$FILE" ]] || { echo "ERROR: file not found: $FILE" >&2; exit 3; }

# ── Find git repo (or use --no-git for isolated tests) ──
GIT_ROOT=""
if ! $NO_GIT; then
  GIT_ROOT="$(git -C "$(dirname "$FILE")" rev-parse --show-toplevel 2>/dev/null || echo "")"
fi

ID=$(grep -m1 '^id: ' "$FILE" | sed 's/^id: //' || basename "$FILE" .md)

if [[ -n "$GIT_ROOT" ]]; then
  REL="${FILE#"$GIT_ROOT"/}"
  # Does the file have uncommitted changes? If yes, discard them (rollback = restore HEAD state).
  if git -C "$GIT_ROOT" status --porcelain -- "$REL" 2>/dev/null | grep -q '^ M\|^M '; then
    PREV=$(git -C "$GIT_ROOT" show HEAD:"$REL" 2>/dev/null)
    git -C "$GIT_ROOT" checkout -- "$REL" 2>/dev/null || { echo "ERROR: git checkout failed" >&2; exit 3; }
    CURRENT=$(cat "$FILE")
    if [[ -z "$PREV" ]]; then
      # File added but not committed — remove it entirely (rollback = delete uncommitted artifact)
      rm -f "$FILE"
    fi
  else
    echo "NOOP: file unchanged vs git HEAD — nothing to roll back" >&2
  fi
else
  # No git: emulate rollback by restoring lifecycle to proposed + tombstone (test path)
  if ! grep -q '^lifecycle:' "$FILE"; then
    echo "ERROR: no lifecycle field and no git — cannot roll back" >&2
    exit 3
  fi
  sed -i 's/^lifecycle: .*/lifecycle: proposed/' "$FILE"
  sed -i 's/^provenance: .*/provenance: INFERRED/' "$FILE"
  sed -i "/^tombstone:/d" "$FILE"
  sed -i "/^lifecycle:/a tombstone: rolled-back $(date -u +%Y-%m-%dT%H:%M:%SZ) — $REASON" "$FILE"
fi

# ── Record rollback (feedback for the loop) ──
mkdir -p "$(dirname "$LEDGER")"
{
  printf '%s' '{"id":"'"$ID"'","event":"rollback","reason":"'"$REASON"'",'
  printf '%s' '"p_consistent_before":"'"$P_BEFORE"'","p_consistent_after":"'"$P_AFTER"'",'
  printf '%s' '"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","actor":"agent"}'
  echo ""
} >> "$LEDGER"

echo "ROLLBACK: $ID — $REASON"
exit 0
