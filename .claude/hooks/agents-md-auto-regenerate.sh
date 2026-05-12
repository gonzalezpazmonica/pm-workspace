#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# agents-md-auto-regenerate.sh — SE-078 Stop hook
#
# When a session edits .claude/agents/*.md, regenerate AGENTS.md so the
# cross-frontend mirror never drifts. Async, non-blocking — failures are
# logged but never stop the session.
#
# Registered in .claude/settings.json under Stop array.
#
# Reference: SE-078 (docs/propuestas/SE-078-agents-md-cross-frontend.md)
# Reference: docs/rules/domain/agents-md-source-of-truth.md

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  source "$LIB_DIR/profile-gate.sh" && profile_gate "automation"
fi

ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LOG_DIR="${ROOT}/output/agent-runs"
LOG_FILE="${LOG_DIR}/agents-md-regen.log"
mkdir -p "${LOG_DIR}"

cd "${ROOT}" 2>/dev/null || exit 0

# Drain stdin even if we don't read it — Claude Code Stop hooks send a JSON
# payload on stdin that, left unread, can deadlock the parent in some shells.
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(timeout 2 cat 2>/dev/null) || true
fi
: "${INPUT:=}"

# Detect whether the session changed any agent files (staged or unstaged).
changed=$(git status --porcelain -- .claude/agents/ 2>/dev/null | head -1 || true)
if [[ -z "$changed" ]]; then
  exit 0  # silent no-op
fi

# Regenerate. The exec form prevents a hung subprocess from blocking Stop.
{
  echo "=== $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  bash "${ROOT}/scripts/agents-md-generate.sh" --apply 2>&1
  diff_out=$(git diff -- AGENTS.md 2>/dev/null | head -40 || true)
  if [[ -n "$diff_out" ]]; then
    rows=$(echo "$diff_out" | grep -c '^[+-]| ' || echo 0)
    echo "agents-md: regenerated, ${rows} row(s) changed" >&2
  fi
} >> "${LOG_FILE}" 2>&1

exit 0
