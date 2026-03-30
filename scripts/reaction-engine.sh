#!/bin/bash
# reaction-engine.sh — SPEC-050 Phase 1: Reaction Engine
# Given an event type and context JSON, outputs the recommended reaction.
# Usage: bash scripts/reaction-engine.sh <event-type> <context-json>
# Events: ci-failure, review-changes-requested, test-failure, approved-and-green
# Context JSON: {"attempt": N, "pr_url": "...", "agent": "...", "logs": "..."}

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: reaction-engine.sh <event-type> <context-json>"
  echo "Given an event (ci-failure, review-changes-requested, test-failure, approved-and-green)"
  echo "and context JSON, outputs the recommended reaction."
  exit 0
fi

if [[ $# -lt 2 ]]; then
  echo '{"error": "Usage: reaction-engine.sh <event-type> <context-json>"}' >&2
  exit 1
fi

EVENT_TYPE="$1"
CONTEXT_JSON="$2"

# Delegate to Python for structured logic
exec python3 "${SCRIPT_DIR}/reaction-engine-core.py" "$EVENT_TYPE" "$CONTEXT_JSON"
