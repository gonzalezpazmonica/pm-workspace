#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# emergency-mode-readiness.sh — Run LocalAI readiness check on SessionStart
# Event: SessionStart | Async: true | Tier: standard
# SPEC-122: LocalAI emergency-mode hardening (AC-03)
#
# Skips silently unless EMERGENCY_MODE_ENABLED=true. When enabled, runs
# scripts/localai-readiness-check.sh and logs the verdict to
# output/emergency-mode/readiness.jsonl. Never blocks SessionStart — the
# check is informational, the user decides whether to /emergency-mode activate.

# Profile gate — only standard/strict tiers run this check.
LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
[[ -f "$LIB_DIR/profile-gate.sh" ]] && source "$LIB_DIR/profile-gate.sh" && profile_gate "standard"

# Consume stdin (hook protocol) without blocking.
timeout 2 cat >/dev/null 2>&1 || true

# Feature flag — silent skip if not enabled.
[[ "${EMERGENCY_MODE_ENABLED:-false}" != "true" ]] && exit 0

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SCRIPT="$REPO_ROOT/scripts/localai-readiness-check.sh"
LOG_DIR="$REPO_ROOT/output/emergency-mode"
LOG="$LOG_DIR/readiness.jsonl"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")

[[ ! -x "$SCRIPT" ]] && {
  mkdir -p "$LOG_DIR" 2>/dev/null || true
  printf '{"ts":"%s","verdict":"SKIP","reason":"readiness-check missing"}\n' \
    "$TIMESTAMP" >> "$LOG" 2>/dev/null
  exit 0
}

mkdir -p "$LOG_DIR" 2>/dev/null || true

# Run readiness check with timeout — fire-and-forget, never block.
RESULT=$(timeout 10 bash "$SCRIPT" --json 2>/dev/null || echo '{"verdict":"TIMEOUT"}')
VERDICT=$(printf '%s' "$RESULT" | grep -oE '"verdict"[[:space:]]*:[[:space:]]*"[A-Z]+"' | head -1 | grep -oE '[A-Z]+')
VERDICT="${VERDICT:-UNKNOWN}"

printf '{"ts":"%s","verdict":"%s"}\n' "$TIMESTAMP" "$VERDICT" >> "$LOG" 2>/dev/null

# Surface high-priority verdicts to stderr for user visibility (non-blocking).
case "$VERDICT" in
  FAIL)
    echo "⚠️  emergency-mode: LocalAI readiness FAIL — local fallback NOT available" >&2
    ;;
  WARN)
    echo "💡 emergency-mode: LocalAI readiness WARN — see output/emergency-mode/readiness.jsonl" >&2
    ;;
esac

exit 0
