#!/usr/bin/env bash
# spec-status-drift-audit.sh — Detect specs marked PROPOSED but implemented on disk.
#
# Heuristic: a spec is "likely implemented" if it has >= N CHANGELOG.d/ references
# (artifact evidence of completed batches). The configurable cutoff prevents
# false positives on specs that are still in progress.
#
# Usage:
#   spec-status-drift-audit.sh                # report only
#   spec-status-drift-audit.sh --min-refs 2   # custom cutoff (default 2)
#   spec-status-drift-audit.sh --json
#
# Exit codes:
#   0 — no drift detected
#   1 — drift present (proposals to re-classify)
#   2 — usage error
#
# Ref: Era 186 spec status drift sweep; companion to claude-md-drift-check.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROPOSALS_DIR="$PROJECT_ROOT/docs/propuestas"
CHANGELOG_DIR="$PROJECT_ROOT/CHANGELOG.d"
MIN_REFS=2
JSON=0

usage() {
  cat <<EOF
Usage: $0 [--min-refs N] [--json]

Scans docs/propuestas/ for specs with status: PROPOSED that have >= N
references in CHANGELOG.d/ fragments (evidence of implementation).

Options:
  --min-refs N     Minimum CHANGELOG.d references to flag drift (default 2)
  --json           JSON output
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --min-refs) MIN_REFS="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown flag '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

[[ ! -d "$PROPOSALS_DIR" ]] && { echo "ERROR: proposals dir not found: $PROPOSALS_DIR" >&2; exit 2; }
[[ ! -d "$CHANGELOG_DIR" ]] && { echo "ERROR: CHANGELOG.d not found: $CHANGELOG_DIR" >&2; exit 2; }

DRIFTED=()
SCANNED=0

count_references() {
  local spec_id="$1"
  grep -l "$spec_id" "$CHANGELOG_DIR"/*.md 2>/dev/null | wc -l | tr -d ' '
}

for f in "$PROPOSALS_DIR"/SE-*.md; do
  [[ -f "$f" ]] || continue
  SCANNED=$((SCANNED + 1))
  grep -q '^status:[[:space:]]*PROPOSED' "$f" || continue
  # Exempt specs explicitly tagged low-priority (intentionally deferred backlog).
  # Rationale: priority: Baja signals "do-when-there-is-demand", not drift.
  if grep -qE '^priority:[[:space:]]*(Baja|Low)' "$f"; then
    continue
  fi
  spec_id=$(grep -m1 '^id:' "$f" | awk '{print $2}')
  [[ -z "$spec_id" ]] && continue
  refs=$(count_references "$spec_id")
  if [[ "$refs" -ge "$MIN_REFS" ]]; then
    DRIFTED+=("$spec_id|$refs|$(basename "$f")")
  fi
done

EXIT=0
[[ ${#DRIFTED[@]} -gt 0 ]] && EXIT=1

if [[ "$JSON" -eq 1 ]]; then
  printf '{"verdict":"%s","scanned":%d,"min_refs":%d,"drifted_count":%d,"drifted":[' \
    "$([ $EXIT -eq 0 ] && echo PASS || echo FAIL)" "$SCANNED" "$MIN_REFS" "${#DRIFTED[@]}"
  sep=""
  for row in "${DRIFTED[@]}"; do
    IFS='|' read -r sid refs fname <<< "$row"
    printf '%s{"id":"%s","refs":%d,"file":"%s"}' "$sep" "$sid" "$refs" "$fname"
    sep=","
  done
  printf ']}\n'
else
  echo "=== SPEC Status Drift Audit ==="
  echo ""
  echo "Proposals scanned: $SCANNED"
  echo "Cutoff:            >=$MIN_REFS CHANGELOG.d references"
  echo "Drifted:           ${#DRIFTED[@]}"
  echo ""
  if [[ ${#DRIFTED[@]} -gt 0 ]]; then
    echo "Specs likely implemented but still marked PROPOSED:"
    for row in "${DRIFTED[@]}"; do
      IFS='|' read -r sid refs fname <<< "$row"
      printf "  %s  (refs=%d)  %s\n" "$sid" "$refs" "$fname"
    done
    echo ""
  fi
  echo "VERDICT: $([ $EXIT -eq 0 ] && echo PASS || echo FAIL)"
fi

exit $EXIT
