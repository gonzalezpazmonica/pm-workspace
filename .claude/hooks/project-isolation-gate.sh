#!/usr/bin/env bash
set -uo pipefail
# project-isolation-gate.sh — SE-093 Zero Project Leakage: enforce trust zones.
# PreToolUse hook. BLOCKS cross-project references unless SAVIA_ALLOW_CROSS_PROJECT=1.
#
# Trust zones (jailbreak research §3.4): each project is a zone with its own
# trust boundary. Data crossing the boundary requires explicit consent. WARN
# without enforcement (previous behavior) was insufficient — promoted to BLOCK
# with override per SE-073 (defense-in-depth, capability-based isolation).
#
# Override: export SAVIA_ALLOW_CROSS_PROJECT=1 before running the tool call.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"

HOOK_INPUT=$(timeout 2 cat /dev/stdin 2>/dev/null) || true
: "${HOOK_INPUT:=}"

WORKSPACE="${SAVIA_WORKSPACE_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ACTIVE_FILE="${WORKSPACE}/.savia/active-project"
ACTIVE=""
[[ -n "${SAVIA_ACTIVE_PROJECT:-}" ]] && ACTIVE="$SAVIA_ACTIVE_PROJECT"
[[ -z "$ACTIVE" ]] && [[ -f "$ACTIVE_FILE" ]] && ACTIVE=$(head -1 "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')
[[ -z "$ACTIVE" ]] && exit 0  # no active project → nothing to enforce

PROJECTS_DIR="${WORKSPACE}/projects"
[[ ! -d "$PROJECTS_DIR" ]] && exit 0

# Scan tool input for cross-project references
for proj_dir in "$PROJECTS_DIR"/*/; do
  [[ -d "$proj_dir" ]] || continue
  pname=$(basename "$proj_dir")
  [[ "$pname" == "$ACTIVE" ]] && continue
  [[ "$pname" == "savia-web" ]] && continue

  if echo "$HOOK_INPUT" | grep -q "projects/${pname}/" 2>/dev/null; then
    if [[ "${SAVIA_ALLOW_CROSS_PROJECT:-0}" == "1" ]]; then
      # Override active: log to audit but allow
      AUDIT_LOG="${WORKSPACE}/output/cross-project-audit.jsonl"
      mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || true
      ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
      printf '{"ts":"%s","active":"%s","cross_ref":"%s","override":true}\n' \
        "$ts" "$ACTIVE" "$pname" >> "$AUDIT_LOG" 2>/dev/null || true
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"CROSS-PROJECT (override allowed): %s while active is %s"}}\n' "$pname" "$ACTIVE"
      continue
    fi
    # BLOCK
    echo "BLOCKED [Project Isolation Gate]: cross-project ref to '$pname' while active is '$ACTIVE'." >&2
    echo "  Override (one-shot): SAVIA_ALLOW_CROSS_PROJECT=1 <command>" >&2
    echo "  Or: change active project (.savia/active-project)." >&2
    exit 2
  fi
done

exit 0
