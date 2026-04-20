#!/usr/bin/env bash
# changelog-consolidate-if-needed.sh — SE-053 Slice 1 post-merge automation.
#
# Consolidate CHANGELOG.d/ fragments to CHANGELOG.md si el count supera
# un umbral, evitando acumulación post-merge. Envoltorio idempotente
# sobre scripts/changelog-consolidate.sh.
#
# Diseñado para correr en:
#   - CI post-merge a main (GHA workflow)
#   - Git post-merge hook (.git/hooks/post-merge)
#   - Cron daily
#
# Usage:
#   changelog-consolidate-if-needed.sh                    # auto threshold 20
#   changelog-consolidate-if-needed.sh --threshold 10
#   changelog-consolidate-if-needed.sh --dry-run
#   changelog-consolidate-if-needed.sh --json
#
# Exit codes:
#   0 — below threshold OR consolidated successfully
#   1 — consolidation failed
#   2 — usage error
#
# Ref: SE-053, CHANGELOG.d/README.md
# Safety: read-only except cuando invoca changelog-consolidate.sh. set -uo pipefail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

THRESHOLD=20
DRY_RUN=0
JSON=0

usage() {
  cat <<EOF
Usage:
  $0 [--threshold N] [--dry-run] [--json]

Options:
  --threshold N    Fragment count above which consolidation runs (default 20)
  --dry-run        Report state, don't consolidate
  --json           JSON output

Wrapper idempotente post-merge sobre changelog-consolidate.sh.
Ref: SE-053.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || [[ "$THRESHOLD" -lt 1 ]]; then
  echo "ERROR: --threshold must be positive integer" >&2; exit 2
fi

FRAGMENTS_DIR="$PROJECT_ROOT/CHANGELOG.d"
CONSOLIDATE="$PROJECT_ROOT/scripts/changelog-consolidate.sh"

[[ ! -d "$FRAGMENTS_DIR" ]] && { echo "ERROR: CHANGELOG.d not found" >&2; exit 2; }
[[ ! -x "$CONSOLIDATE" ]] && { echo "ERROR: changelog-consolidate.sh not executable" >&2; exit 2; }

# Count fragments (exclude README.md)
COUNT=$(find "$FRAGMENTS_DIR" -maxdepth 1 -name "*.md" -not -name "README.md" -type f 2>/dev/null | wc -l)

ACTION="noop"
EXIT_CODE=0

if [[ "$COUNT" -lt "$THRESHOLD" ]]; then
  ACTION="below_threshold"
elif [[ "$DRY_RUN" -eq 1 ]]; then
  ACTION="would_consolidate"
else
  # Run consolidation
  if bash "$CONSOLIDATE" 2>&1 | tail -3; then
    ACTION="consolidated"
  else
    ACTION="failed"
    EXIT_CODE=1
  fi
fi

if [[ "$JSON" -eq 1 ]]; then
  cat <<JSON
{"action":"$ACTION","fragments":$COUNT,"threshold":$THRESHOLD,"dry_run":$DRY_RUN}
JSON
else
  echo "=== SE-053 Changelog Consolidate-If-Needed ==="
  echo ""
  echo "Fragments:    $COUNT"
  echo "Threshold:    $THRESHOLD"
  echo "Action:       $ACTION"
  echo ""
  case "$ACTION" in
    below_threshold) echo "Below threshold — no consolidation needed." ;;
    would_consolidate) echo "(dry-run) Would consolidate $COUNT fragments." ;;
    consolidated) echo "✅ Consolidated $COUNT fragments into CHANGELOG.md." ;;
    failed) echo "❌ Consolidation failed — check changelog-consolidate.sh." ;;
  esac
fi

exit $EXIT_CODE
