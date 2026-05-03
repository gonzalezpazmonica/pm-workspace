#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# cognitive-debt-hypothesis-first.sh — SPEC-107 I1 PreToolUse hook.
#
# Phase 1 mode: WARNING ONLY. Never blocks. Reads recent commits and emits
# a stderr nudge if the user is editing production code without a recent
# `Hypothesis:` commit trailer.
#
# Phase 2 (deferred) will add the actual block + escape hatch.
#
# Privacy: reads only local git log, never invokes LLM (CD-01).
# Phase 1 fail-safe: any error → exit 0 (warning, never blocks — CD-02).
#
# Reference: SPEC-107 (`docs/propuestas/SPEC-107-ai-cognitive-debt-mitigation.md`)
# Phase: 1 (warning only). Phase 2 escalates to soft-block with --skip-cognitive escape.

# Phase 1 design: warning-only. Never exit non-zero.
trap 'exit 0' ERR

ROOT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$ROOT_DIR" 2>/dev/null || exit 0

# Skip if not in a git repo (no commits to inspect)
[ -d .git ] || exit 0

# Look at the last 5 commits on this branch. If ≥1 has a Hypothesis: trailer,
# we consider the user "in flow" and skip the nudge.
recent_commits=$(git log -5 --format='%B' 2>/dev/null || echo "")
if printf '%s' "$recent_commits" | grep -qiE '^Hypothesis: ' 2>/dev/null; then
  exit 0
fi

# Not in a flow with hypothesis trailers. Nudge to stderr (warning, never block).
# Only nudge once per session — use marker in /tmp.
SESSION="${CLAUDE_SESSION_ID:-$$}"
MARKER="/tmp/cognitive-debt-nudge-$SESSION"
[ -f "$MARKER" ] && exit 0
touch "$MARKER" 2>/dev/null || true

cat >&2 <<'NUDGE'
[cognitive-debt I1 — Phase 1 warning, not blocking]
Tip: añadir un trailer `Hypothesis: <tu hipótesis>` al próximo commit ayuda
con la consolidación de memoria episódica (Roediger-Karpicke, MIT 2025).
Phase 2 lo hará obligatorio con escape `--skip-cognitive`. Por ahora solo
es un nudge — sin bloqueo.

Disable: bash scripts/cognitive-debt.sh disable
NUDGE

exit 0
