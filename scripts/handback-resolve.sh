#!/usr/bin/env bash
# handback-resolve.sh — SE-332 Handback Obligation
#
# Resolves the immediate parent of a blocked autonomous instance (escalation
# chain defined in autonomous-safety.md, Handback Obligation) and emits the
# reference-first handback artifact.
#
# Usage:
#   bash scripts/handback-resolve.sh --modo <modo|agente> --contexto-dir <dir> \
#       [--motivo <motivo>] [--intentos-restantes <n>]
#
# Exit codes:
#   0 — artifact emitted, audit trail updated
#   2 — usage error
#   5 — chain does NOT terminate in manual (invariant SE-332)
set -uo pipefail

usage() {
  echo "Usage: $0 --modo <modo|agente> --contexto-dir <dir> [--motivo <motivo>] [--intentos-restantes <n>]" >&2
  exit 2
}

MODO=""
CONTEXTO_DIR=""
MOTIVO="otro"
INTENTOS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --modo)              MODO="$2"; shift 2 ;;
    --contexto-dir)      CONTEXTO_DIR="$2"; shift 2 ;;
    --motivo)            MOTIVO="$2"; shift 2 ;;
    --intentos-restantes) INTENTOS="$2"; shift 2 ;;
    --help|-h)           usage ;;
    *)                   usage ;;
  esac
done

if [[ -z "$MODO" || -z "$CONTEXTO_DIR" ]]; then
  usage
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/savia-env.sh
source "$SCRIPT_DIR/savia-env.sh"

# ── 1. Resolve immediate parent (authority chain, not re-derived by hand) ────
PADRE="$(savia_handback_chain "$MODO")"
RC=$?
if [[ $RC -ne 0 ]]; then
  echo "ERROR: handback chain for modo='$MODO' does not terminate in manual (invariant SE-332)" >&2
  exit 5
fi

# ── 2. Sanity: contexto_dir must exist (artifact refs are not invented) ──────
if [[ ! -d "$CONTEXTO_DIR" ]]; then
  echo "ERROR: contexto-dir '$CONTEXTO_DIR' does not exist" >&2
  exit 2
fi

# ── 3. Reference-first refs: paths only, resolved relative to REPO_ROOT ─────
REPO_ROOT="${SAVIA_WORKSPACE_DIR:-$(_resolve_workspace)}"
# shellcheck disable=SC2016
REFS_DIR="$(cd "$CONTEXTO_DIR" && pwd)"
if [[ "$REFS_DIR" == "$REPO_ROOT"* ]]; then
  REL_PREFIX="${REPO_ROOT%/}/"
  REL_DIR="${REFS_DIR#"$REL_PREFIX"}"
else
  REL_DIR="$(realpath --relative-to="$REPO_ROOT" "$REFS_DIR" 2>/dev/null || echo "$CONTEXTO_DIR")"
fi

REF_NAMES=()
for n in run-record.jsonl run-record.json terminal-state.jsonl results.tsv audit.log; do
  if [[ -f "$REFS_DIR/$n" ]]; then
    REF_NAMES+=("$n")
  fi
done
if [[ ${#REF_NAMES[@]} -eq 0 ]]; then
  REF_NAMES+=("$(basename "$REFS_DIR")")
fi

# ── 4. Emit artifact (reference-first: routes, never body) ──────────────────
FECHA="$(date +%Y%m%d)"
TIMESTAMP="$(date +%Y-%m-%dT%H:%M:%S%z)"
ARTIFACT_DIR="$REPO_ROOT/output/agent-runs"
mkdir -p "$ARTIFACT_DIR"
ARTIFACT="$ARTIFACT_DIR/${MODO}-${FECHA}-handback.md"

{
  echo "---"
  echo "handback:"
  echo "  escalado_desde: $MODO"
  echo "  escalado_a: $PADRE"
  echo "  motivo: $MOTIVO"
  echo "  contexto_ref:"
  for ref in "${REF_NAMES[@]}"; do
    echo "    - ${REL_DIR}/${ref}"
  done
  if [[ -n "$INTENTOS" ]]; then
    echo "  intentos_restantes: $INTENTOS"
  fi
  echo "  timestamp: $TIMESTAMP"
  echo "---"
} > "$ARTIFACT"

# ── 5. Audit trail: handback_to (autonomous-safety.md, Auditoría) ────────────
AUDIT="$ARTIFACT_DIR/${MODO}-${FECHA}-audit.log"
{
  echo "handback_to=$PADRE timestamp=$TIMESTAMP motivo=$MOTIVO artifact=$ARTIFACT"
} >> "$AUDIT"

echo "handback artifact: $ARTIFACT"
echo "handback_to: $PADRE"
exit 0
