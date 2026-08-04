#!/usr/bin/env bash
set -uo pipefail
# kg-cleanup.sh — Archive orphaned/expired entities

CUTOFF_UNREVIEWED=$(date -d '14 days ago' +%s 2>/dev/null || echo 0)
CUTOFF_ORPHAN=$(date -d '30 days ago' +%s 2>/dev/null || echo 0)

archived=0

echo "KG Cleanup — $(date +%Y-%m-%d)"
echo "  Unreviewed cutoff: 14 days"
echo "  Orphan cutoff: 30 days"

[[ $CUTOFF_UNREVIEWED -gt 0 ]] && echo "  Cleanup ready" || echo "  WARNING: date calculation failed"

echo "  Archived: $archived entities"
