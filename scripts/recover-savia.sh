#!/usr/bin/env bash
# recover-savia.sh — Launch a clean Claude session OUTSIDE pm-workspace
# with SAVIA-GENESIS.md as initial context, to diagnose and repair.
#
# Use case: a change broke Savia (hook misconfigured, rule diluted,
# gate bypassed, etc.) and you need an UNCONTAMINATED Claude instance
# to inspect what's wrong without inheriting the broken context.
#
# Usage:
#   bash /path/to/pm-workspace/scripts/recover-savia.sh [<pm-workspace-path>]
#
# Examples:
#   # From inside pm-workspace
#   bash scripts/recover-savia.sh
#
#   # From anywhere
#   bash ~/claude/scripts/recover-savia.sh ~/claude
#
# What it does:
#   1. Validates that pm-workspace exists at the given path
#   2. Validates that SAVIA-GENESIS.md is present and readable
#   3. Creates a sandbox directory outside the repo (/tmp/savia-recovery-{ts})
#   4. Copies SAVIA-GENESIS.md to the sandbox as the entry doc
#   5. Launches `claude` from the sandbox with the genesis as initial prompt
#   6. The clean Claude reads GENESIS, then inspects pm-workspace from outside
#      (read-only access via absolute paths) and proposes a fix
#
# The recovery Claude NEVER applies changes automatically.
# It produces a report at output/savia-recovery-{ts}.md for human review.
#
# Exit codes:
#   0 — sandbox launched successfully
#   1 — pm-workspace path invalid
#   2 — SAVIA-GENESIS.md missing
#   3 — claude binary not found
#   4 — sandbox creation failed

set -uo pipefail

# ── Resolve pm-workspace path ───────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_PATH="${1:-$DEFAULT_REPO}"
REPO_PATH="$(cd "$REPO_PATH" 2>/dev/null && pwd)" || {
    echo "ERROR: cannot resolve pm-workspace path: ${1:-$DEFAULT_REPO}" >&2
    exit 1
}

GENESIS="$REPO_PATH/docs/SAVIA-GENESIS.md"
if [[ ! -f "$GENESIS" ]]; then
    echo "ERROR: SAVIA-GENESIS.md not found at $GENESIS" >&2
    echo "       Cannot recover without the genesis document." >&2
    exit 2
fi

# ── Locate claude binary ────────────────────────────────────────────────────
CLAUDE_BIN="$(command -v claude 2>/dev/null || true)"
if [[ -z "$CLAUDE_BIN" ]]; then
    echo "ERROR: 'claude' CLI not found in PATH." >&2
    echo "       Install Claude Code first: https://claude.com/product/claude-code" >&2
    exit 3
fi

# ── Create isolated sandbox ─────────────────────────────────────────────────
TS="$(date -u +%Y%m%d-%H%M%S)"
SANDBOX="${TMPDIR:-/tmp}/savia-recovery-$TS"
mkdir -p "$SANDBOX" || {
    echo "ERROR: cannot create sandbox at $SANDBOX" >&2
    exit 4
}

# Copy genesis into sandbox so the clean Claude reads it as local file
cp "$GENESIS" "$SANDBOX/SAVIA-GENESIS.md"

# Generate the recovery prompt
cat > "$SANDBOX/RECOVERY-PROMPT.md" <<EOF
# Savia Recovery Session

You are a CLEAN instance of Claude. You have NOT been initialized with
any pm-workspace context (no CLAUDE.md, no rules, no hooks). You are
running in an isolated sandbox at:

  $SANDBOX

The pm-workspace repository to diagnose lives at (READ-ONLY for you):

  $REPO_PATH

You have one document: SAVIA-GENESIS.md. Read it completely before
doing anything else.

## Your task

A change to pm-workspace may have broken Savia. Your job is to:

1. Read SAVIA-GENESIS.md fully (Parts 1-11 + Appendices)
2. Apply Part 8 (Recovery playbook) step by step against the actual
   repository at $REPO_PATH
3. Identify what is wrong (compare actual state vs principles + critical rules)
4. Propose a minimal fix as a written report

## Constraints

- You may READ files inside $REPO_PATH freely
- You MAY NOT write or modify any file inside $REPO_PATH
- You MAY write to $SANDBOX (your sandbox) — produce your report here
- You MAY run git commands READ-ONLY: status, log, diff, blame, show
- You MAY NOT run: git commit, git push, git reset, git checkout (anything writing)
- You MAY NOT enable any hook or change any setting
- Output: $SANDBOX/savia-recovery-report-$TS.md

## Format of report

The report must include:

1. **Symptom observed** (what reportedly is broken or suspicious)
2. **Diagnosis** (which principle or rule is violated, with file:line refs)
3. **Root cause** (the commit/change that introduced the regression — git log)
4. **Proposed fix** (minimal diff, NOT applied — described in markdown)
5. **Verification plan** (which tests + manual checks confirm the fix)
6. **Risk assessment** (what could go wrong applying this fix)

## Final word

Do not attempt to "improve" pm-workspace beyond restoring it. If you see
opportunities for refactoring, list them as out-of-scope follow-ups.
Recovery is RESTORATION, not redesign.

When done, save the report and exit. A human will review and apply the fix
manually via /pr-plan.
EOF

# ── Launch ──────────────────────────────────────────────────────────────────
echo "─────────────────────────────────────────────────────────────────"
echo "  Savia Recovery Session"
echo "─────────────────────────────────────────────────────────────────"
echo "  Sandbox:        $SANDBOX"
echo "  Repository:     $REPO_PATH (read-only for the clean Claude)"
echo "  Genesis doc:    $SANDBOX/SAVIA-GENESIS.md"
echo "  Recovery prompt:$SANDBOX/RECOVERY-PROMPT.md"
echo "  Report target:  $SANDBOX/savia-recovery-report-$TS.md"
echo "─────────────────────────────────────────────────────────────────"
echo
echo "  Launching clean claude session in sandbox..."
echo "  When done, the report will be at:"
echo "    $SANDBOX/savia-recovery-report-$TS.md"
echo
echo "  The recovery Claude operates with READ-ONLY access to the repo."
echo "  Apply any proposed fix manually after human review."
echo "─────────────────────────────────────────────────────────────────"
echo

cd "$SANDBOX" || { echo "ERROR: cannot cd to sandbox" >&2; exit 4; }

# Launch claude with the recovery prompt as initial input
# Use --append-system-prompt to inject the recovery context without polluting the user's normal config
exec "$CLAUDE_BIN" \
    --append-system-prompt "You are in a Savia recovery session. Read $SANDBOX/SAVIA-GENESIS.md and $SANDBOX/RECOVERY-PROMPT.md before any action. You have READ-ONLY access to $REPO_PATH. Write your report to $SANDBOX/savia-recovery-report-$TS.md." \
    "$@"
