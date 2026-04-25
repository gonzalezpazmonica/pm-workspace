#!/usr/bin/env bash
set -uo pipefail
# memory-verified-gate.sh — SE-072 Verified Memory axiom (No Execution, No Memory)
# Event: PreToolUse | Matcher: Write | Tier: standard
#
# Blocks Write to ~/.claude/projects/-home-monica-claude/memory/*.md unless
# the content includes a citation pattern proving provenance:
#   - file:path[:line] reference (e.g. scripts/foo.sh:42)
#   - Markdown link [name](path) pointing to a file in repo
#   - explicit "Source:" or "Ref:" or "@ref" keyword
#   - frontmatter `type:` matching reference|feedback|user|project (these have
#     implicit provenance documented elsewhere in the entry)
#
# Skipped:
#   - session-journal.md, session-hot.md (ephemeral by design)
#   - MEMORY.md index file (only links, no claims)
#   - Files outside auto-memory directory
#   - When SAVIA_VERIFIED_MEMORY_DISABLED=true (escape hatch)

# Profile gate — only standard/strict tiers enforce.
LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
[[ -f "$LIB_DIR/profile-gate.sh" ]] && source "$LIB_DIR/profile-gate.sh" && profile_gate "standard"

# Read tool call JSON.
INPUT=$(timeout 2 cat 2>/dev/null) || true
[[ -z "$INPUT" ]] && exit 0

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
[[ "$TOOL" != "Write" ]] && exit 0

FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null) || exit 0

# Only enforce on auto-memory writes.
case "$FILE" in
  *"/.claude/projects/-home-monica-claude/memory/"*) ;;
  *) exit 0 ;;
esac

# Skip ephemeral / index files.
basename=$(basename "$FILE")
case "$basename" in
  MEMORY.md|session-journal.md|session-hot.md|session-summary.md) exit 0 ;;
esac

# Escape hatch.
[[ "${SAVIA_VERIFIED_MEMORY_DISABLED:-false}" == "true" ]] && exit 0

# Citation pattern detection — at least ONE of:
has_citation=0

# 1. file:path[:line] reference
echo "$CONTENT" | grep -qE '\b[a-zA-Z0-9_/-]+\.(sh|py|md|ts|js|tsx|jsx|yaml|yml|json|bats|toml|tf)(\b|:[0-9]+\b)' && has_citation=1

# 2. Markdown link to repo path
[[ "$has_citation" -eq 0 ]] && echo "$CONTENT" | grep -qE '\[[^]]+\]\([^)]*\.[a-zA-Z0-9]+\)' && has_citation=1

# 3. explicit Source/Ref keyword (case-insensitive)
[[ "$has_citation" -eq 0 ]] && echo "$CONTENT" | grep -qiE '(^|\n)[[:space:]]*(source|ref|see|@ref|reference)[[:space:]]*:' && has_citation=1

# 4. frontmatter type: reference|feedback|user|project (implicit provenance)
[[ "$has_citation" -eq 0 ]] && echo "$CONTENT" | head -10 | grep -qE '^type:[[:space:]]*(reference|feedback|user|project)' && has_citation=1

# 5. URL reference (https://, github.com/, etc.)
[[ "$has_citation" -eq 0 ]] && echo "$CONTENT" | grep -qE 'https?://[a-zA-Z0-9.-]+' && has_citation=1

if [[ "$has_citation" -eq 0 ]]; then
  cat >&2 <<EOF
[BLOCKED] memory-verified-gate (SE-072): write to $basename rejected.

Auto-memory writes must include a citation pattern proving provenance.
Add ONE of:
  - File reference:   path/to/file.sh:42
  - Markdown link:    [name](path/to/file.md)
  - Keyword line:     Source: <where> | Ref: <where> | See: <where>
  - URL:              https://...
  - Frontmatter:      type: reference|feedback|user|project

Why: SE-072 Verified Memory axiom — "No Execution, No Memory". Memory must
reflect verified facts, not draft thinking.

Escape hatch (last resort): SAVIA_VERIFIED_MEMORY_DISABLED=true bash ...
EOF
  exit 2
fi

exit 0
