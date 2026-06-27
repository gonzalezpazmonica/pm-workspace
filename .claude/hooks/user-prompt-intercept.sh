#!/bin/bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# user-prompt-intercept.sh — SPEC-015 context gate + session hot-file injection
# Hook: UserPromptSubmit | Timeout: 3s
# Exit 0 + stdout → injected as context Claude sees before the user message.
# Exit 0 + no stdout → pass through silently.
# Exit 2 → block the message (we never block user input).
#
# Two jobs:
#   1. On first prompt of session: inject session-hot.md (previous session context)
#   2. On every prompt: inject active project hint if in a project dir

# Read user input from stdin (JSON with user's message)
USER_INPUT=$(cat 2>/dev/null || echo "")

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh"
  profile_gate "standard"
fi

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ_SLUG=$(echo "$REPO_ROOT" | sed 's|[/:\]|-|g; s|^-||')
SESSION_HOT="$HOME/.claude/projects/$PROJ_SLUG/memory/session-hot.md"
SAVIA_TMP="${TMPDIR:-${HOME}/.savia/tmp}"
mkdir -p "$SAVIA_TMP" 2>/dev/null || true
STATE_FILE="$SAVIA_TMP/savia-prompt-hook-$$-injected"

# Skip if empty, slash command, or very short confirmations
INPUT_TEXT=$(echo "$USER_INPUT" | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "$USER_INPUT")
if [[ -z "$INPUT_TEXT" ]] || [[ "$INPUT_TEXT" == /* ]] || [[ ${#INPUT_TEXT} -lt 3 ]]; then
  exit 0
fi

# Skip simple confirmations (Context Gate — SPEC-015 step 0)
if echo "$INPUT_TEXT" | grep -qiE '^(s[ií]|no|ok|vale|claro|hecho|listo|cancelar|adelante|gracias|y|n)$'; then
  exit 0
fi

OUTPUT=""

# Job 1: Inject session-hot.md on first real prompt (once per process tree)
GLOBAL_STATE="$SAVIA_TMP/savia-session-hot-injected-$(date +%Y%m%d)"
if [[ -f "$SESSION_HOT" ]] && [[ ! -f "$GLOBAL_STATE" ]]; then
  HOT_CONTENT=$(head -20 "$SESSION_HOT" 2>/dev/null || true)
  if [[ -n "$HOT_CONTENT" ]]; then
    OUTPUT="[Previous session context]
$HOT_CONTENT
[End previous session context]"
    touch "$GLOBAL_STATE" 2>/dev/null || true
  fi
fi

# Job 2: Detect active project from CWD
CWD="${CLAUDE_CWD:-$(pwd)}"
PROJECTS_DIR="$REPO_ROOT/projects"
if [[ "$CWD" == "$PROJECTS_DIR"/* ]]; then
  PROJECT=$(echo "$CWD" | sed "s|$PROJECTS_DIR/||" | cut -d'/' -f1)
  if [[ -n "$PROJECT" ]] && [[ -f "$PROJECTS_DIR/$PROJECT/CLAUDE.md" ]]; then
    OUTPUT="${OUTPUT:+$OUTPUT
}[Active project: $PROJECT]"
  fi
fi

# Job 3: SE-230 Auto-Loop Gate (opt-in via SAVIA_AUTO_LOOP=enabled)
# Skips if SAVIA_LOOP_CONTEXT is set (already inside a loop — recursion blocked by gate itself).
if [[ "${SAVIA_AUTO_LOOP:-}" == "enabled" ]] && [[ ${#INPUT_TEXT} -gt 10 ]]; then
  AUTO_LOOP_GATE="$REPO_ROOT/scripts/auto-loop-gate.sh"
  if [[ -f "$AUTO_LOOP_GATE" ]]; then
    GATE_OUTPUT=$(bash "$AUTO_LOOP_GATE" --request "$INPUT_TEXT" 2>/dev/null || true)
    if [[ -n "$GATE_OUTPUT" ]]; then
      GATE_DECISION=$(echo "$GATE_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('decision',''))" 2>/dev/null || true)
      if [[ "$GATE_DECISION" == "PROPOSE_LOOP" ]]; then
        PROPOSAL=$(echo "$GATE_OUTPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
p = d.get('proposal_text') or ''
print(p.replace('\\\\n', '\n'))
" 2>/dev/null || true)
        if [[ -n "$PROPOSAL" ]]; then
          OUTPUT="${OUTPUT:+$OUTPUT
}[SE-230 Auto-Loop Gate]
$PROPOSAL
[End Auto-Loop Gate]"
          # Write proposal to tmp file for hooks that cannot use stdout
          echo "$PROPOSAL" > "$SAVIA_TMP/auto-loop-proposal-$$.txt" 2>/dev/null || true
        fi
      elif [[ "$GATE_DECISION" == "CLARIFY_NEEDED" ]]; then
        CLARIFY=$(echo "$GATE_OUTPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('proposal_text') or '')
" 2>/dev/null || true)
        if [[ -n "$CLARIFY" ]]; then
          OUTPUT="${OUTPUT:+$OUTPUT
}[SE-230 Clarification needed]
$CLARIFY
[End Clarification]"
        fi
      fi
    fi
  fi
fi

# Output context injection (if any)
if [[ -n "$OUTPUT" ]]; then
  echo "$OUTPUT"
fi

exit 0
