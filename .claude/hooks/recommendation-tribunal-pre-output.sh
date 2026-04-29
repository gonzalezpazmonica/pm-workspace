#!/usr/bin/env bash
set -uo pipefail
# recommendation-tribunal-pre-output.sh — SPEC-125 Slice 1 hook.
#
# Intercepts Savia's draft output BEFORE delivery, runs the classifier, and
# convenes the Recommendation Tribunal if the draft is an actionable
# recommendation with risk_class ≥ medium.
#
# This file is the WIRE-READY hook. To activate it, add to .claude/settings.json:
#   "hooks": {
#     "PreOutput": [
#       {"matcher": "*", "hooks": [{"type": "command", "command":
#         "$CLAUDE_PROJECT_DIR/.claude/hooks/recommendation-tribunal-pre-output.sh"}]}
#     ]
#   }
#
# (The exact event name depends on Claude Code version — see docs/best-practices-claude-code.md)
#
# Until activated, this hook is a NO-OP: just an executable file living in .claude/hooks/.
# The tribunal infrastructure is delivered, but does NOT run on every turn.
#
# Activation is a separate, deliberate step the human user must take after
# reviewing the entire SPEC-125 Slice 1 batch (audit-trail dirs, judges,
# orchestrator, scripts).
#
# Exit codes (when wired):
#   0  ok — output (possibly mutated) is on stdout
#   1  fatal — block output (very rare; classifier itself broken)
#
# Reference: SPEC-125 § 7 (hook integration).


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

CLASSIFIER="$ROOT_DIR/scripts/recommendation-tribunal/classifier.sh"
AGGREGATE="$ROOT_DIR/scripts/recommendation-tribunal/aggregate.sh"
BANNER="$ROOT_DIR/scripts/recommendation-tribunal/banner.sh"

AUDIT_DIR="$ROOT_DIR/output/recommendation-tribunal/$(date +%Y-%m-%d)"
mkdir -p "$AUDIT_DIR" 2>/dev/null || true

# ── Read the draft from stdin ────────────────────────────────────────────────

DRAFT=$(cat)

# Empty draft → pass through (PreOutput hooks must be transparent for empty input)
if [[ -z "$DRAFT" ]]; then
  printf '%s' "$DRAFT"
  exit 0
fi

# ── Step 1: classify ─────────────────────────────────────────────────────────

CLASSIFICATION=$(printf '%s' "$DRAFT" | bash "$CLASSIFIER" 2>/dev/null) || {
  # Classifier broken → pass through with audit log
  printf '%s' "$DRAFT"
  exit 0
}

IS_REC=$(printf '%s' "$CLASSIFICATION" | python3 -c "
import json,sys
try: print('true' if json.load(sys.stdin).get('is_recommendation') else 'false')
except: print('false')
" 2>/dev/null)

RISK=$(printf '%s' "$CLASSIFICATION" | python3 -c "
import json,sys
try: print(json.load(sys.stdin).get('risk_class', 'low'))
except: print('low')
" 2>/dev/null)

# Skip tribunal for non-recommendations or low-risk drafts
if [[ "$IS_REC" != "true" ]] || [[ "$RISK" == "low" ]]; then
  printf '%s' "$DRAFT"
  exit 0
fi

# ── Step 2: convene 4 judges via Task tool ──────────────────────────────────
#
# NOTE: in Slice 1 this hook does NOT actually invoke the agents synchronously.
# The Task tool is not callable from a bash hook. The intended integration
# (Slice 2 follow-up) wraps this via a higher-level orchestrator that has
# Task access. For now, this hook only:
#   1. Logs that a recommendation was detected
#   2. Stores the classification in audit-trail
#   3. Passes the draft through unchanged
#
# This means until Slice 2 wires the orchestrator, the hook is essentially
# instrumentation: detect + log, no veto/banner mutation.

DRAFT_HASH=$(printf '%s' "$DRAFT" | sha256sum | awk '{print $1}')
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Persist classification audit (always)
{
  printf '{"ts":"%s","draft_hash":"%s","draft_preview":"%s","classification":%s,"verdict":"PENDING-SLICE-2","note":"Slice 1 detect-only mode"}\n' \
    "$TS" "$DRAFT_HASH" \
    "$(printf '%s' "$DRAFT" | head -c 200 | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read())[1:-1])' 2>/dev/null || echo '')" \
    "$CLASSIFICATION"
} >> "$AUDIT_DIR/$DRAFT_HASH.json" 2>/dev/null || true

# Pass through draft — Slice 1 is detection + audit only.
# Slice 2 will replace this passthrough with: orchestrator invoke → aggregate → banner mutate.
printf '%s' "$DRAFT"
exit 0
