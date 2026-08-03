#!/usr/bin/env bash
set -uo pipefail
# post-digestion-kg-extract.sh — Trigger KG extraction after document digestion

DIGEST_OUTPUT="${1:-}"
PIPELINE="$(dirname "${BASH_SOURCE[0]}")/../../scripts/kg-pipeline.sh"

if [[ -z "$DIGEST_OUTPUT" || ! -f "$DIGEST_OUTPUT" ]]; then
  if [[ ! -t 0 ]]; then
    # stdin fallback (workspace-structure requires hooks to read stdin)
    INPUT=$(cat)
    if [[ -x "$PIPELINE" && -n "$INPUT" ]]; then
      echo "$INPUT" | "$PIPELINE" - "stdin-digest" >/dev/null 2>&1 || true
    fi
  fi
  exit 0
fi

if [[ -x "$PIPELINE" ]]; then
  "$PIPELINE" "$DIGEST_OUTPUT" "$(basename "$DIGEST_OUTPUT")" >/dev/null 2>&1 || true
fi
exit 0
