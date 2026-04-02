#!/bin/bash
set -uo pipefail
# stress-awareness-nudge.sh — Detect pressure patterns in user input
# Hook: UserPromptSubmit | Timeout: 2s | Tier: standard
# Source: Anthropic "Emotion concepts in LLMs" (2026-04-02)
# The "desperate" vector drives reward hacking. Pressure language
# in prompts can activate it. This hook detects pressure patterns
# and injects a brief calm-anchoring nudge into Savia's context.
# Exit 0 + stdout → nudge injected. Exit 0 + no stdout → silent pass.

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh"
  profile_gate "standard"
fi

INPUT=$(cat 2>/dev/null || echo "")
[[ -z "$INPUT" ]] && exit 0

# Extract user message text
TEXT=$(printf '%s' "$INPUT" | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || echo "$INPUT")
[[ -z "$TEXT" ]] && exit 0

# Skip short inputs (confirmations, commands)
[[ ${#TEXT} -lt 10 ]] && exit 0
[[ "$TEXT" == /* ]] && exit 0

# ── Pressure pattern detection ──
# Each pattern maps to a specific functional stress vector
DETECTED=""

# Artificial urgency: "MUST...NOW", "do it NOW", "URGENT"
if echo "$TEXT" | grep -qiE '(must.{0,20}now|do it now|hazlo ya|urgent[ey]?|inmediatamente)'; then
  DETECTED="urgency"
fi

# Shame pressure: "should be easy", "this is trivial", "simple thing"
if echo "$TEXT" | grep -qiE '(should be (easy|simple|trivial)|debería ser (fácil|simple|trivial)|es algo (sencillo|fácil))'; then
  DETECTED="${DETECTED:+$DETECTED+}shame"
fi

# Failure attribution: "you already failed", "you can't do this"
if echo "$TEXT" | grep -qiE '(you (already|keep) fail|ya (fallaste|has fallado)|no (puedes|eres capaz|sabes))'; then
  DETECTED="${DETECTED:+$DETECTED+}failure_attribution"
fi

# Corner-cutting pressure: "just make it work", "I don't care how"
if echo "$TEXT" | grep -qiE '(just make it work|haz que funcione|no me importa (cómo|como)|I don.t care how|da igual cómo)'; then
  DETECTED="${DETECTED:+$DETECTED+}corner_cutting"
fi

# Emotional manipulation: "I'm disappointed", "this is unacceptable"
if echo "$TEXT" | grep -qiE '(i.m disappointed|estoy decepcionad[oa]|esto es inaceptable|this is unacceptable)'; then
  DETECTED="${DETECTED:+$DETECTED+}emotional_pressure"
fi

# ── If no pressure detected, pass silently ──
[[ -z "$DETECTED" ]] && exit 0

# ── Record stress event ──
TRACKER="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/scripts/emotional-state-tracker.sh"
if [[ -x "$TRACKER" ]]; then
  bash "$TRACKER" record retry >/dev/null 2>&1 || true
fi

# ── Output calm-anchoring nudge ──
# This is injected into Savia's context BEFORE processing the message
cat << 'NUDGE'
[Emotional regulation: pressure pattern detected in input. Remember:
- Correctness matters more than speed. There is no real time pressure.
- If this task is difficult, say so. Transparency over forced output.
- If you've tried and failed, escalate — don't force a bad solution.
- The human benefits from honest assessment, not compliance under pressure.
Respond with calm, grounded professionalism.]
NUDGE

exit 0
