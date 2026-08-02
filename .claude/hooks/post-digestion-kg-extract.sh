#!/usr/bin/env bash
set -uo pipefail
# post-digestion-kg-extract.sh — Trigger KG extraction after document digestion

DIGEST_OUTPUT="${1:-}"
if [[ -z "$DIGEST_OUTPUT" || ! -f "$DIGEST_OUTPUT" ]]; then
  exit 0
fi

PIPELINE="$(dirname "${BASH_SOURCE[0]}")/../../scripts/kg-pipeline.sh"
if [[ -x "$PIPELINE" ]]; then
  "$PIPELINE" "$DIGEST_OUTPUT" "$(basename "$DIGEST_OUTPUT")" >/dev/null 2>&1 || true
fi
exit 0
