#!/usr/bin/env bash
# validate-spec-status.sh — SPEC-184
# SPEC docs must have status: in {PROPOSED,APPROVED,IMPLEMENTED,APPLIED,REJECTED,DEPRECATED,DRAFT}.
# Always exits 0.
set -uo pipefail

FILE="${1:-}"
[[ -f "$FILE" ]] || exit 0

case "$FILE" in
  */docs/propuestas/SPEC-*.md|*/docs/propuestas/SE-*.md) ;;
  *) exit 0 ;;
esac

# status is in frontmatter
fm=$(awk '/^---$/{c++; if(c==2)exit; if(c==1)next} c==1' "$FILE")
status=$(echo "$fm" | grep -E "^status:" | head -1 | sed -E 's/^status:[[:space:]]*//;s/[[:space:]]*#.*//;s/[[:space:]]+$//')

[[ -z "$status" ]] && exit 0  # already covered by validate-frontmatter

case "$status" in
  PROPOSED|APPROVED|IMPLEMENTED|APPLIED|REJECTED|DEPRECATED|DRAFT) ;;
  *)
    echo "[WARN][spec-status][$FILE] status '$status' not in enum {PROPOSED,APPROVED,IMPLEMENTED,APPLIED,REJECTED,DEPRECATED,DRAFT}" >&2
    ;;
esac

exit 0
