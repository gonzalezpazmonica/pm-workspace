#!/usr/bin/env bash
# pbi-history-capture.sh — PostToolUse hook (Edit|Write)
# Captures field-level changes in PBI frontmatter and appends to ## Historial
# Trigger: edits to projects/*/backlog/pbi/PBI-*.md
set -uo pipefail

# ── Input from hook (JSON on stdin) ─────────────────────────────────────────
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)

# Fallback: try content field for Write tool
if [[ -z "$FILE_PATH" ]]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // empty' 2>/dev/null || true)
fi

# ── Guard: only PBI files ────────────────────────────────────────────────────
if [[ ! "$FILE_PATH" =~ projects/.*/backlog/pbi/PBI-.*\.md$ ]]; then
  exit 0
fi

if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# ── Read @handle from active-user.md ─────────────────────────────────────────
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
ACTIVE_USER_FILE="$REPO_ROOT/.claude/profiles/active-user.md"
AUTHOR="@system"
if [[ -f "$ACTIVE_USER_FILE" ]]; then
  SLUG=$(grep 'active_slug:' "$ACTIVE_USER_FILE" | sed 's/.*: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | tr -d ' ')
  if [[ -n "$SLUG" ]]; then
    AUTHOR="@${SLUG}"
  fi
fi

NOW=$(date '+%Y-%m-%d %H:%M')
TODAY=$(date '+%Y-%m-%d')

# ── Tracked frontmatter fields ───────────────────────────────────────────────
TRACKED_FIELDS="title type state priority estimation_sp estimation_hours assigned_to sprint tags azure_devops_id jira_id github_issue_id"

# ── Extract frontmatter value from content ───────────────────────────────────
extract_field() {
  local content="$1" field="$2"
  echo "$content" | sed -n '/^---$/,/^---$/p' | grep "^${field}:" | head -1 | \
    sed "s/^${field}: *//" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/"
}

# ── Get previous version from git ────────────────────────────────────────────
REL_PATH=$(realpath --relative-to="$REPO_ROOT" "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
OLD_CONTENT=$(git -C "$REPO_ROOT" show "HEAD:$REL_PATH" 2>/dev/null || echo "")
NEW_CONTENT=$(cat "$FILE_PATH")

# ── New file (no git history) → _created entry ───────────────────────────────
if [[ -z "$OLD_CONTENT" ]]; then
  PBI_ID=$(extract_field "$NEW_CONTENT" "id")
  [[ -z "$PBI_ID" ]] && PBI_ID="unknown"
  ENTRY="| $NOW | $AUTHOR | _created | | $PBI_ID |"
  if ! grep -q '## Historial' "$FILE_PATH"; then
    printf '\n## Historial\n| Fecha | Autor | Campo | Anterior | Nuevo |\n|-------|-------|-------|----------|-------|\n' >> "$FILE_PATH"
  fi
  echo "$ENTRY" >> "$FILE_PATH"
  # Update updated: field
  sed -i "s/^updated: .*/updated: $TODAY/" "$FILE_PATH"
  exit 0
fi

# ── Compare fields and collect changes ────────────────────────────────────────
CHANGES=""
for field in $TRACKED_FIELDS; do
  OLD_VAL=$(extract_field "$OLD_CONTENT" "$field")
  NEW_VAL=$(extract_field "$NEW_CONTENT" "$field")
  if [[ "$OLD_VAL" != "$NEW_VAL" ]]; then
    CHANGES="${CHANGES}| $NOW | $AUTHOR | $field | $OLD_VAL | $NEW_VAL |"$'\n'
  fi
done

# ── No changes detected → exit ───────────────────────────────────────────────
if [[ -z "$CHANGES" ]]; then
  exit 0
fi

# ── Ensure ## Historial section exists ────────────────────────────────────────
if ! grep -q '## Historial' "$FILE_PATH"; then
  printf '\n## Historial\n| Fecha | Autor | Campo | Anterior | Nuevo |\n|-------|-------|-------|----------|-------|\n' >> "$FILE_PATH"
fi

# ── Append change rows ────────────────────────────────────────────────────────
printf '%s' "$CHANGES" >> "$FILE_PATH"

# ── Update updated: field ─────────────────────────────────────────────────────
sed -i "s/^updated: .*/updated: $TODAY/" "$FILE_PATH"
