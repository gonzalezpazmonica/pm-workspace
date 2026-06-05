#!/usr/bin/env bash
# twin-decay-check.sh — Escanea todos los twins y marca STALE los que superaron stale_after_days
# Spec: SPEC-169 (decay policy)
# Usage: bash scripts/twin-decay-check.sh [--fix]
# --fix: ejecuta twin-refresh.sh en cada twin STALE
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${TWIN_ROOT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
LINTER="$SCRIPT_DIR/twin-linter.sh"
REFRESH="$SCRIPT_DIR/twin-refresh.sh"
FIX_MODE="${1:-}"

STALE_COUNT=0
OK_COUNT=0

while IFS= read -r twin_file; do
  slug=$(echo "$twin_file" | sed "s|${ROOT_DIR}/projects/||;s|/twin.md||")
  exit_code=0
  bash "$LINTER" "$twin_file" >/dev/null 2>&1 || exit_code=$?
  if [[ "$exit_code" -eq 1 ]]; then
    echo "STALE: ${slug}"
    STALE_COUNT=$((STALE_COUNT + 1))
    if [[ "$FIX_MODE" == "--fix" ]]; then
      bash "$REFRESH" "$slug" >/dev/null 2>&1 && echo "  → refreshed OK" || echo "  → refresh FAILED"
    fi
  elif [[ "$exit_code" -eq 0 ]]; then
    OK_COUNT=$((OK_COUNT + 1))
  fi
done < <(find "${ROOT_DIR}/projects" -name "twin.md" -type f 2>/dev/null | sort)

echo "decay-check: ${OK_COUNT} OK, ${STALE_COUNT} STALE"
[[ "$STALE_COUNT" -gt 0 ]] && exit 1
exit 0
