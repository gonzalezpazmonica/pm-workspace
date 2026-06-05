#!/usr/bin/env bash
# twin-refresh.sh — Recalcula predicciones del twin sin LLM (SPEC-169 AC-3, AC-V2)
# Usage: bash scripts/twin-refresh.sh {slug} [--dry-run]
# Exit: 0 OK | 2 ERROR
# Determinista: lee evidence_refs, calcula 4 predicciones, escribe diff auditable
set -uo pipefail
export LC_NUMERIC=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${TWIN_ROOT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
LINTER="$SCRIPT_DIR/twin-linter.sh"
TELEMETRY_DIR="${ROOT_DIR}/output/twin-runs"

SLUG="${1:-}"
DRY_RUN="${2:-}"

[[ -z "$SLUG" ]] && { echo "Usage: twin-refresh.sh {slug} [--dry-run]" >&2; exit 2; }

TWIN_FILE="${ROOT_DIR}/projects/${SLUG}/twin.md"
[[ ! -f "$TWIN_FILE" ]] && { echo "ERROR: twin not found: ${TWIN_FILE}" >&2; exit 2; }

PROJECT_DIR="${ROOT_DIR}/projects/${SLUG}"
CLAUDE_MD="${PROJECT_DIR}/CLAUDE.md"
BACKLOG_DIR="${PROJECT_DIR}/backlog"
SPRINTS_DIR="${PROJECT_DIR}/sprints"

START_TS=$(date +%s%N)

# ── Evidence collection (deterministic, no LLM) ──────────────────────────────

# sprint_slip: based on open items in latest sprint dir
SPRINT_SLIP_VAL=0.2
SPRINT_SLIP_CONF=0.6
SPRINT_SLIP_REF="${SPRINTS_DIR}"
if [[ -d "$SPRINTS_DIR" ]]; then
  sprint_count=$(find "$SPRINTS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  # Heuristic: if >1 sprint dir, check if latest has open items
  if [[ "$sprint_count" -gt 0 ]]; then
    latest_sprint=$(find "$SPRINTS_DIR" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)
    open_count=$(find "$latest_sprint" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    SPRINT_SLIP_VAL=$(awk -v o="$open_count" 'BEGIN{v=o>5?0.5:o>2?0.3:0.1; printf "%.2f",v}')
    SPRINT_SLIP_CONF=0.65
    SPRINT_SLIP_REF="${latest_sprint}"
  fi
fi

# next_blocker: check CLAUDE.md for any BLOCKED or bloqueante keywords
NEXT_BLOCKER_VAL="no blockers detected"
NEXT_BLOCKER_CONF=0.7
NEXT_BLOCKER_REF="${CLAUDE_MD}"
if [[ -f "$CLAUDE_MD" ]]; then
  if grep -qiE "BLOCKED|bloqueante|bloqueado|pending.*extern" "$CLAUDE_MD" 2>/dev/null; then
    NEXT_BLOCKER_VAL=$(grep -iEm1 "BLOCKED|bloqueante|bloqueado|pending.*extern" "$CLAUDE_MD" | head -c 80 | tr -d '"')
    NEXT_BLOCKER_CONF=0.8
  fi
fi

# scope_drift: count unplanned items in backlog vs sprint count
SCOPE_DRIFT_VAL=0.05
SCOPE_DRIFT_CONF=0.6
SCOPE_DRIFT_REF="${BACKLOG_DIR}"
if [[ -d "$BACKLOG_DIR" ]]; then
  backlog_items=$(find "$BACKLOG_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  SCOPE_DRIFT_VAL=$(awk -v b="$backlog_items" 'BEGIN{v=b>20?0.3:b>10?0.15:0.05; printf "%.2f",v}')
fi

# aggregate_health: derive from slip + blocker
HEALTH_VAL="green"
HEALTH_CONF=0.75
HEALTH_REF="${TWIN_FILE}"
SLIP_NUM=$(awk -v s="$SPRINT_SLIP_VAL" 'BEGIN{printf "%.0f",s*10}')
if [[ "$SLIP_NUM" -ge 4 ]] || [[ "$NEXT_BLOCKER_VAL" != "no blockers detected" ]]; then
  HEALTH_VAL="yellow"
fi
if [[ "$SLIP_NUM" -ge 6 ]]; then
  HEALTH_VAL="red"
  HEALTH_CONF=0.8
fi

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── Build updated twin ────────────────────────────────────────────────────────
# Read existing body (everything after second ---)
BODY=$(awk '/^---$/{c++; if(c==2){found=1;next}} found{print}' "$TWIN_FILE")

NEW_TWIN=$(cat << TWIN
---
twin_id: "${SLUG}"
spec_version: "1.0"
last_refresh: "${NOW}"
stale_after_days: 14
token_budget: 2000
health: ${HEALTH_VAL}
predictions:
  sprint_slip:
    value: ${SPRINT_SLIP_VAL}
    confidence: ${SPRINT_SLIP_CONF}
    evidence_ref: "${SPRINT_SLIP_REF}"
  next_blocker:
    value: "${NEXT_BLOCKER_VAL}"
    confidence: ${NEXT_BLOCKER_CONF}
    evidence_ref: "${NEXT_BLOCKER_REF}"
  scope_drift:
    value: ${SCOPE_DRIFT_VAL}
    confidence: ${SCOPE_DRIFT_CONF}
    evidence_ref: "${SCOPE_DRIFT_REF}"
  aggregate_health:
    value: ${HEALTH_VAL}
    confidence: ${HEALTH_CONF}
    evidence_ref: "${HEALTH_REF}"
---
${BODY}
TWIN
)

# ── Diff output (always shown) ────────────────────────────────────────────────
OLD_HEALTH=$(grep -E "^health:" "$TWIN_FILE" | head -1 | sed 's/.*: *//')
OLD_REFRESH=$(grep -E "^last_refresh:" "$TWIN_FILE" | head -1 | sed 's/.*: *//' | tr -d '"')
echo "=== twin-refresh diff: ${SLUG} ==="
echo "  health:       ${OLD_HEALTH} → ${HEALTH_VAL}"
echo "  last_refresh: ${OLD_REFRESH} → ${NOW}"
echo "  sprint_slip:  ${SPRINT_SLIP_VAL} (conf ${SPRINT_SLIP_CONF})"
echo "  next_blocker: ${NEXT_BLOCKER_VAL} (conf ${NEXT_BLOCKER_CONF})"
echo "  scope_drift:  ${SCOPE_DRIFT_VAL} (conf ${SCOPE_DRIFT_CONF})"

[[ "$DRY_RUN" == "--dry-run" ]] && { echo "[dry-run] no changes written."; exit 0; }

# Write updated twin
printf '%s\n' "$NEW_TWIN" > "$TWIN_FILE"

# Validate result
bash "$LINTER" "$TWIN_FILE" >/dev/null 2>&1 || { echo "ERROR: refresh produced invalid twin" >&2; exit 2; }

# ── Telemetry (AC-8) ─────────────────────────────────────────────────────────
END_TS=$(date +%s%N)
ELAPSED_MS=$(( (END_TS - START_TS) / 1000000 ))
mkdir -p "$TELEMETRY_DIR"
REFRESH_LOG="${TELEMETRY_DIR}/refresh-${SLUG}.jsonl"
printf '{"ts":"%s","slug":"%s","health":"%s","elapsed_ms":%d,"slip":%.2f}\n' \
  "$NOW" "$SLUG" "$HEALTH_VAL" "$ELAPSED_MS" "$SPRINT_SLIP_VAL" >> "$REFRESH_LOG" 2>/dev/null || true

echo "OK: refresh complete in ${ELAPSED_MS}ms"
exit 0
