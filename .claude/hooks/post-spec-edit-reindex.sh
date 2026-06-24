#!/usr/bin/env bash
set -uo pipefail
# post-spec-edit-reindex.sh — SE-222 S2 PostToolUse hook
#
# Trigger: PostToolUse for Edit|Write when the file path matches
#          docs/propuestas/*.md (excluding INDEX.md and LOG.md).
#
# Action:  Regenerate docs/propuestas/INDEX.md via
#          scripts/propuestas-index-gen.sh.
#
# Rate-limit: 1 regeneration per N seconds (default 60). Prevents thrashing
#             when a batch of edits hits propuestas/ in quick succession.
#
# Always exits 0. Toggle via SAVIA_PROPUESTAS_REINDEX_ENABLED=false.
#
# Reference: docs/propuestas/SE-222-okf-adoptable-patterns.md (Slice S2)

# Global toggle
if [[ "${SAVIA_PROPUESTAS_REINDEX_ENABLED:-true}" == "false" ]]; then
  exit 0
fi

INPUT=$(cat 2>/dev/null) || exit 0
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null) || exit 0

[[ -z "$FILE_PATH" ]] && exit 0

# Match docs/propuestas/*.md (but skip INDEX.md / LOG.md to avoid self-trigger)
case "$FILE_PATH" in
  */docs/propuestas/*.md|docs/propuestas/*.md) ;;
  *) exit 0 ;;
esac

basename_f="$(basename "$FILE_PATH")"
case "$basename_f" in
  INDEX.md|LOG.md|index.md|log.md) exit 0 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)"
GEN_SCRIPT="$ROOT/scripts/propuestas-index-gen.sh"
[[ -x "$GEN_SCRIPT" ]] || exit 0

# Rate-limit: stamp file
STAMP_DIR="${SAVIA_HOOK_STATE_DIR:-/tmp/savia-hooks}"
mkdir -p "$STAMP_DIR" 2>/dev/null || exit 0
STAMP="$STAMP_DIR/post-spec-edit-reindex.stamp"
COOLDOWN_SECONDS="${SAVIA_REINDEX_COOLDOWN:-60}"

now=$(date +%s)
if [[ -f "$STAMP" ]]; then
  last=$(cat "$STAMP" 2>/dev/null || echo 0)
  if [[ -n "$last" && "$last" =~ ^[0-9]+$ ]]; then
    elapsed=$((now - last))
    if [[ "$elapsed" -lt "$COOLDOWN_SECONDS" ]]; then
      # Within cooldown, skip
      exit 0
    fi
  fi
fi

# Regenerate (background, so we don't block the tool response)
(
  bash "$GEN_SCRIPT" >/dev/null 2>&1
  printf '%s' "$now" > "$STAMP"
) &

exit 0
