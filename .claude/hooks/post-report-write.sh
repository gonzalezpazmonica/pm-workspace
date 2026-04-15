#!/usr/bin/env bash
set -uo pipefail
# post-report-write.sh — async PostToolUse hook (SPEC-106 Phase 2).
#
# Triggered after Write/Edit on a markdown file. If the file looks like a
# generated report (path or frontmatter heuristic), enqueue an async Truth
# Tribunal verification. NEVER blocks the write — just queues background work.
#
# Wiring: PostToolUse on Write|Edit, async: true. See
# .claude/rules/domain/async-hooks-config.md.
#
# Queue location: ~/.savia/truth-tribunal/queue/{run-id}.req
# Worker (separate): scripts/truth-tribunal-worker.sh consumes the queue.

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh" && profile_gate "standard"
fi

INPUT=$(cat)

# ── Extract tool + file path from PostToolUse JSON ─────────────────────────
TOOL=$(echo "$INPUT" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_name",""))' 2>/dev/null)
FILE=$(echo "$INPUT" | python3 -c 'import sys,json; d=json.load(sys.stdin); t=d.get("tool_input",{}); print(t.get("file_path") or t.get("path") or "")' 2>/dev/null)

[[ -z "$TOOL" || -z "$FILE" ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

# ── Only consider .md files ────────────────────────────────────────────────
[[ "$FILE" != *.md ]] && exit 0

# ── Skip self-recursion: never queue truth.crc files or queue files ───────
case "$FILE" in
  *.truth.crc|*/truth-tribunal/queue/*) exit 0 ;;
esac

# ── Heuristic: is this a generated report? ─────────────────────────────────
is_report=0

# 1. Path under output/ with audits/, reports/, postmortems/, ceo-, etc.
case "$FILE" in
  */output/audits/*|*/output/reports/*|*/output/postmortems/*|*/output/governance/*|*/output/compliance/*|*/output/dora/*)
    is_report=1
    ;;
  */output/*ceo-report*|*/output/*stakeholder-report*|*/output/*compliance-*|*/output/*audit-*|*/output/*-digest*|*/output/*sprint-retro*)
    is_report=1
    ;;
esac

# 2. Frontmatter `report_type:` field overrides path heuristic
if [[ $is_report -eq 0 ]]; then
  fm_type=$(awk '/^---$/{c++;next} c==1 && /^report_type[[:space:]]*:/ {gsub(/^.*:[[:space:]]*/,""); print; exit}' "$FILE" 2>/dev/null)
  [[ -n "$fm_type" ]] && is_report=1
fi

[[ $is_report -eq 0 ]] && exit 0

# ── Skip if already verified and cache is fresh ────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.."
TRIBUNAL_SH="$SCRIPT_DIR/scripts/truth-tribunal.sh"
if [[ -x "$TRIBUNAL_SH" ]]; then
  if bash "$TRIBUNAL_SH" cache-check "$FILE" >/dev/null 2>&1; then
    # Fresh cached verdict exists; nothing to do
    exit 0
  fi
fi

# ── Enqueue ────────────────────────────────────────────────────────────────
QUEUE_DIR="${TRUTH_TRIBUNAL_QUEUE:-$HOME/.savia/truth-tribunal/queue}"
mkdir -p "$QUEUE_DIR" 2>/dev/null || exit 0

run_id="TT-$(date -u +%Y%m%d-%H%M%S)-$$"
req_file="$QUEUE_DIR/${run_id}.req"
{
  echo "report_path=$FILE"
  echo "tool=$TOOL"
  echo "queued_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "session_id=${CLAUDE_SESSION_ID:-unknown}"
} > "$req_file" 2>/dev/null

# Async hook never blocks. Worker is started separately.
exit 0
