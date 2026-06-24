#!/usr/bin/env bash
# cognitive-debt-check.sh — SPEC-107 PostTurn hook.
#
# Emits a WARN banner on stderr when the active session exceeds
# COGNITIVE_DEBT_SESSION_LIMIT hours (default 4h).
#
# Master switch: SAVIA_COGNITIVE_MONITOR=on|off  (default off — opt-in).
# Constraint CD-04: opt-in by default. Never invokes LLM (CD-01).
# Always exits 0 — never blocks work (CD-02).
#
# Integration: register as PostTurn hook in .claude/settings.json.
# Reference: SPEC-107, MIT arXiv 2506.08872.

set -uo pipefail

# ── master switch ──────────────────────────────────────────────────────────────
MONITOR="${SAVIA_COGNITIVE_MONITOR:-off}"
if [[ "$MONITOR" != "on" ]]; then
  exit 0
fi

# ── configuration ──────────────────────────────────────────────────────────────
SESSION_LIMIT_HOURS="${COGNITIVE_DEBT_SESSION_LIMIT:-4}"
SESSION_START_FILE="${SAVIA_SESSION_START_FILE:-/tmp/savia-session-start}"

# ── session start tracking ─────────────────────────────────────────────────────
# If no session start marker exists, create one and exit (first turn).
if [[ ! -f "$SESSION_START_FILE" ]]; then
  date +%s > "$SESSION_START_FILE"
  exit 0
fi

# ── compute elapsed hours ──────────────────────────────────────────────────────
SESSION_START=$(cat "$SESSION_START_FILE" 2>/dev/null || date +%s)
NOW=$(date +%s)
ELAPSED_SECONDS=$(( NOW - SESSION_START ))
ELAPSED_HOURS=$(echo "scale=1; $ELAPSED_SECONDS / 3600" | bc 2>/dev/null || echo "0")

# bc may not be available; fallback via awk
if ! command -v bc &>/dev/null; then
  ELAPSED_HOURS=$(awk "BEGIN {printf \"%.1f\", $ELAPSED_SECONDS / 3600}")
fi

# ── threshold check ────────────────────────────────────────────────────────────
# Convert to integer for comparison (strip decimal)
ELAPSED_INT=$(echo "$ELAPSED_HOURS" | cut -d. -f1)
LIMIT_INT=$(echo "$SESSION_LIMIT_HOURS" | cut -d. -f1)

if (( ELAPSED_INT >= LIMIT_INT )); then
  echo "⚠  COGNITIVE-DEBT WARN: Sesión activa: ${ELAPSED_HOURS}h. Considera tomar un descanso de 15min. (SPEC-107)" >&2
fi

exit 0
