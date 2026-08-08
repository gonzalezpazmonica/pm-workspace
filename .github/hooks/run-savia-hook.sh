#!/usr/bin/env bash
# run-savia-hook.sh — SE-180 single launcher for Copilot CLI hooks
#
# Resolves workspace root via multiple strategies so Copilot CLI can locate
# the underlying hook regardless of its current working directory or env vars:
#
#   1) $COPILOT_PROJECT_DIR if set
#   2) $CLAUDE_PROJECT_DIR if set
#   3) Script's own directory (this file is at <root>/.github/hooks/)
#   4) git rev-parse --show-toplevel
#   5) pwd as last resort
#
# Then runs `.github/hooks/wrap-for-copilot.sh <hook>` so the underlying hook's
# Claude Code output schema is translated to Copilot CLI's flat schema.
#
# Usage:  run-savia-hook.sh <hook-relative-path>
#   where <hook-relative-path> is rooted at the workspace, e.g.
#       run-savia-hook.sh .opencode/hooks/session-init.sh
#       run-savia-hook.sh scripts/check-daemon-auth.sh
#
# stdin is passed through. stderr is passed through. Exit code preserved.
#
# Reference: SE-180

set -uo pipefail

HOOK_REL="${1:-}"
if [[ -z "$HOOK_REL" ]]; then
  echo "run-savia-hook: missing hook path argument" >&2
  exit 4
fi
shift

# Resolve workspace root
ROOT=""
for cand in "${COPILOT_PROJECT_DIR:-}" "${CLAUDE_PROJECT_DIR:-}"; do
  if [[ -n "$cand" && -d "$cand" ]]; then
    ROOT="$cand"
    break
  fi
done
if [[ -z "$ROOT" ]]; then
  # Script's own directory should be <root>/.github/hooks/
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ "$SCRIPT_DIR" == */.github/hooks ]]; then
    ROOT="${SCRIPT_DIR%/.github/hooks}"
  fi
fi
if [[ -z "$ROOT" ]]; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
fi
if [[ -z "$ROOT" ]]; then
  ROOT="$PWD"
fi

WRAPPER="$ROOT/.github/hooks/wrap-for-copilot.sh"
HOOK_ABS="$ROOT/$HOOK_REL"

if [[ ! -f "$WRAPPER" ]]; then
  echo "run-savia-hook: wrapper not found at $WRAPPER (ROOT=$ROOT)" >&2
  exit 4
fi

if [[ ! -f "$HOOK_ABS" ]]; then
  echo "run-savia-hook: hook not found at $HOOK_ABS (ROOT=$ROOT)" >&2
  exit 4
fi

exec "$WRAPPER" "$HOOK_ABS" "$@"
