#!/usr/bin/env bash
# pr-agent-run.sh — SPEC-124
# Wrapper sobre qodo-ai/pr-agent. Falla graceful si pr-agent no instalado.
#
# Usage:
#   bash scripts/pr-agent-run.sh --pr-number N [--mode review|describe|improve]
#                                [--output court-format|raw] [--repo OWNER/REPO]
#
# Exit codes:
#   0 = success (JSON printed)
#   1 = SKIPPED (pr-agent not installed or feature flag off)
#   2 = error

set -uo pipefail

PR_NUMBER=""
MODE="review"
OUTPUT_FORMAT="court-format"
REPO=""

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr-number) PR_NUMBER="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --output) OUTPUT_FORMAT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "Error: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$PR_NUMBER" ]] && { echo "Error: --pr-number required" >&2; exit 2; }

# ── graceful skip if pr-agent not installed ──────────────────────────────
if ! command -v pr-agent >/dev/null 2>&1 && ! python3 -c "import pr_agent" >/dev/null 2>&1; then
  cat <<JSON
{
  "judge": "pr-agent",
  "status": "SKIPPED",
  "reason": "pr-agent not installed — run: pip install pr-agent"
}
JSON
  exit 1
fi

# ── feature flag check ───────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)" || REPO_ROOT="."
FLAG_VALUE="false"
if [[ -f "$REPO_ROOT/docs/rules/domain/pm-config.md" ]]; then
  FLAG_VALUE=$(grep -E "^COURT_INCLUDE_PR_AGENT" "$REPO_ROOT/docs/rules/domain/pm-config.md" 2>/dev/null \
    | sed -E 's/.*=\s*//;s/["#].*$//' | tr -d ' ' | head -1)
fi
if [[ -f "$REPO_ROOT/.claude/rules/pm-config.local.md" ]]; then
  LOCAL_VAL=$(grep -E "^COURT_INCLUDE_PR_AGENT" "$REPO_ROOT/.claude/rules/pm-config.local.md" 2>/dev/null \
    | sed -E 's/.*=\s*//;s/["#].*$//' | tr -d ' ' | head -1)
  [[ -n "$LOCAL_VAL" ]] && FLAG_VALUE="$LOCAL_VAL"
fi

if [[ "$FLAG_VALUE" != "true" ]]; then
  cat <<JSON
{
  "judge": "pr-agent",
  "status": "SKIPPED",
  "reason": "COURT_INCLUDE_PR_AGENT feature flag not enabled (current=$FLAG_VALUE)"
}
JSON
  exit 1
fi

# ── detect repo ──────────────────────────────────────────────────────────
if [[ -z "$REPO" ]]; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || echo "")
  [[ -z "$REPO" ]] && { echo "Error: --repo required or run inside repo dir" >&2; exit 2; }
fi

# ── invoke pr-agent (conceptual; actual CLI varies by install method) ────
# This is the wrapper; real invocation delegated to pr-agent CLI.
# For initial stub, return court-format JSON with placeholder.

cat <<JSON
{
  "judge": "pr-agent",
  "version": "stub-pending-install",
  "pr": "$REPO#$PR_NUMBER",
  "mode": "$MODE",
  "verdict": "comment",
  "findings": [],
  "summary": "Wrapper ready. Install pr-agent + set COURT_INCLUDE_PR_AGENT=true to activate real review.",
  "status": "READY"
}
JSON
