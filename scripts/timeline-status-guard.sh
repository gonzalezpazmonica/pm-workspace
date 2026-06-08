#!/usr/bin/env bash
# timeline-status-guard.sh — SPEC-182 Slice 4: suggest timeline-append when status changes
# Invoked as a PostCommit hint (not a blocking hook)
# Ref: docs/propuestas/SPEC-182-bitemporal-timeline-frontmatter.md
set -uo pipefail

SCRIPT_NAME="$(basename "$0")"
APPEND_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/timeline-append.sh"

# ── Mode flags ────────────────────────────────────────────────────────────────
CHECK_ONLY=false
JSON_OUTPUT=false

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

PostCommit guard: detects when a markdown file's status: changed in the last
commit but no new timeline: entry was added. Emits HINTS (non-blocking).

Options:
  --check   Analyse only, suppress hint output (dry mode)
  --json    Output JSON array of files needing timeline update
  --help    Show this help
EOF
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    --check|--dry-run) CHECK_ONLY=true ;;
    --json)            JSON_OUTPUT=true ;;
    --help|-h)         usage ;;
    *) echo "ERROR: unknown option: $arg" >&2; exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────

# Extract status value from a diff hunk (old or new side)
_extract_status_from_diff() {
  local diff_text="$1"
  # Lines starting with + or - that contain "^status:"
  echo "$diff_text" | grep -E '^[+-]status:' | sed 's/^[+-]status:[[:space:]]*//' | head -1
}

# Check whether a file has a timeline: block in HEAD
_has_timeline_entry() {
  local file="$1"
  git show "HEAD:$file" 2>/dev/null | grep -q "^timeline:" && return 0
  return 1
}

# Count timeline entries in HEAD version of file
_timeline_entry_count_head() {
  local file="$1"
  git show "HEAD:$file" 2>/dev/null | grep -c "^  - from:" 2>/dev/null || echo 0
}

# Count timeline entries in HEAD~1 version of file (0 if file didn't exist)
_timeline_entry_count_prev() {
  local file="$1"
  git show "HEAD~1:$file" 2>/dev/null | grep -c "^  - from:" 2>/dev/null || echo 0
}

# ── Main logic ────────────────────────────────────────────────────────────────

# Collect changed .md files in last commit
mapfile -t CHANGED_MD < <(git diff HEAD~1 HEAD --name-only 2>/dev/null | grep '\.md$' || true)

if [[ "${#CHANGED_MD[@]}" -eq 0 ]]; then
  [[ "$JSON_OUTPUT" == "true" ]] && echo "[]"
  exit 0
fi

NEEDS_TIMELINE=()

for file in "${CHANGED_MD[@]}"; do
  # Skip if file doesn't exist in HEAD (deleted)
  git show "HEAD:$file" > /dev/null 2>&1 || continue

  # Get the diff for this specific file
  FILE_DIFF="$(git diff HEAD~1 HEAD -- "$file" 2>/dev/null || true)"

  # Extract old and new status lines from diff
  OLD_STATUS="$(echo "$FILE_DIFF" | grep '^-status:' | sed 's/^-status:[[:space:]]*//' | head -1 || true)"
  NEW_STATUS="$(echo "$FILE_DIFF" | grep '^+status:' | sed 's/^+status:[[:space:]]*//' | head -1 || true)"

  # No status change → skip
  [[ -z "$OLD_STATUS" || -z "$NEW_STATUS" ]] && continue
  [[ "$OLD_STATUS" == "$NEW_STATUS" ]] && continue

  # Status changed — check if a new timeline entry was added
  prev_count="$(_timeline_entry_count_prev "$file")"
  head_count="$(_timeline_entry_count_head "$file")"

  if [[ "$head_count" -le "$prev_count" ]]; then
    NEEDS_TIMELINE+=("$file|$NEW_STATUS")
  fi
done

# ── Get commit message for hint ───────────────────────────────────────────────
COMMIT_MSG="$(git log -1 --pretty=%s 2>/dev/null || echo 'recent commit')"

# ── Output ────────────────────────────────────────────────────────────────────

if [[ "$JSON_OUTPUT" == "true" ]]; then
  # Build JSON array
  first=true
  printf '['
  for entry in "${NEEDS_TIMELINE[@]}"; do
    file="${entry%%|*}"
    new_status="${entry##*|}"
    [[ "$first" == "true" ]] && first=false || printf ','
    printf '{"file":"%s","new_status":"%s","hint":"bash scripts/timeline-append.sh status %s %s \"%s\""}' \
      "$file" "$new_status" "$file" "$new_status" "$COMMIT_MSG"
  done
  printf ']\n'
  exit 0
fi

if [[ "$CHECK_ONLY" == "true" ]]; then
  # Analyse only: print count to stdout, no hints to stderr
  echo "Files needing timeline update: ${#NEEDS_TIMELINE[@]}"
  exit 0
fi

# Default: emit hints to stderr (non-blocking)
for entry in "${NEEDS_TIMELINE[@]}"; do
  file="${entry%%|*}"
  new_status="${entry##*|}"
  echo "[TIMELINE-HINT] ${file}: status changed to '${new_status}' without timeline entry. Run: bash scripts/timeline-append.sh status ${file} ${new_status} \"${COMMIT_MSG}\"" >&2
done

exit 0
