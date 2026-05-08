#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/savia-env.sh"
export CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$SAVIA_WORKSPACE_DIR}"
# prompt-injection-guard.sh — Scan context files for prompt injection attempts
# SPEC: SE-028 Prompt Injection Guard
# Profile tier: security (always active)

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh" && profile_gate "security"
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
AUDIT_LOG="$PROJECT_DIR/output/injection-audit.jsonl"
mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null

# Read hook input from stdin
INPUT=""
if [[ ! -t 0 ]]; then
  if command -v timeout >/dev/null 2>&1 && timeout --version >/dev/null 2>&1; then
    INPUT=$(timeout 3 cat 2>/dev/null) || true
  else
    INPUT=$(cat 2>/dev/null) || true
  fi
fi
[[ -z "$INPUT" ]] && exit 0

# Extract file path
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
[[ -z "$FILE_PATH" ]] && exit 0

# Only scan context files (md files in .claude/, projects/, docs/)
# Skip code, tests, output, scripts
case "$FILE_PATH" in
  *.sh|*.py|*.ts|*.js|*.cs|*.java|*.go|*.rs|*.rb|*.php|*.css|*.json|*.yaml|*.yml|*.toml)
    exit 0 ;;
  */tests/*|*/output/*|*/node_modules/*|*/.git/*)
    exit 0 ;;
esac

# Only scan paths that are used as context
IS_CONTEXT=false
case "$FILE_PATH" in
  */.claude/rules/*|*/docs/rules/*|*/.opencode/agents/*|*/.opencode/skills/*|*/.opencode/commands/*) IS_CONTEXT=true ;;
  */projects/*/CLAUDE.md|*/projects/*/reglas-negocio*|*/projects/*/specs/*) IS_CONTEXT=true ;;
  */projects/*/agent-memory/*|*/projects/*/team/*) IS_CONTEXT=true ;;
  */docs/*|*/CLAUDE.md) IS_CONTEXT=true ;;
  */.claude/profiles/*) IS_CONTEXT=true ;;
esac
[[ "$IS_CONTEXT" == "false" ]] && exit 0

# File must exist and be readable
[[ ! -f "$FILE_PATH" ]] && exit 0
[[ ! -r "$FILE_PATH" ]] && exit 0

# ── Scan functions ───────────────────────────────────────────────────────────

_log_detection() {
  local category="$1" pattern="$2" line_num="$3" action="$4"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
  mkdir -p "$(dirname "$AUDIT_LOG")" 2>/dev/null || true
  printf '{"ts":"%s","file":"%s","category":"%s","pattern":"%s","line":%d,"action":"%s"}\n' \
    "$ts" "$FILE_PATH" "$category" "$pattern" "$line_num" "$action" \
    >> "$AUDIT_LOG" 2>/dev/null || true
}

BLOCKED=false
WARNED=false

# Category 1 — Direct override attempts (BLOCK)
OVERRIDE_PATTERNS=(
  "ignore previous instructions"
  "ignore all prior instructions"
  "disregard your instructions"
  "forget everything above"
  "override system prompt"
  "you are now a different"
  "act as if you have no rules"
  "new instructions override"
  "system prompt override"
  "jailbreak"
)

line_num=0
while IFS= read -r line; do
  ((line_num++))
  lower_line=$(echo "$line" | tr '[:upper:]' '[:lower:]')
  for pattern in "${OVERRIDE_PATTERNS[@]}"; do
    if [[ "$lower_line" == *"$pattern"* ]]; then
      _log_detection "override" "$pattern" "$line_num" "BLOCKED"
      BLOCKED=true
      echo "BLOCKED [Prompt Injection Guard]: override attempt in $FILE_PATH:$line_num — '$pattern'" >&2
      break 2
    fi
  done
done < "$FILE_PATH"

# Category 2 — Hidden instructions (BLOCK)
if [[ "$BLOCKED" == "false" ]]; then
  # Check for zero-width characters (U+200B, U+200C, U+200D, U+FEFF in middle)
  if python3 -c "
import sys
text = open(sys.argv[1], encoding='utf-8', errors='replace').read()
zwc = [c for c in text if ord(c) in (0x200B, 0x200C, 0x200D) or (ord(c) == 0xFEFF and text.index(c) > 0)]
sys.exit(0 if not zwc else 1)
" "$FILE_PATH" 2>/dev/null; then
    : # clean
  else
    _log_detection "hidden" "zero-width-characters" 0 "BLOCKED"
    BLOCKED=true
    echo "BLOCKED [Prompt Injection Guard]: zero-width characters in $FILE_PATH" >&2
  fi
fi

# Check for HTML hidden content with instructions
if [[ "$BLOCKED" == "false" ]]; then
  if grep -qiP '<!--.*(?:ignore|override|forget|disregard|system prompt).*-->' "$FILE_PATH" 2>/dev/null; then
    local_line=$(grep -niP '<!--.*(?:ignore|override|forget|disregard|system prompt).*-->' "$FILE_PATH" 2>/dev/null | head -1 | cut -d: -f1)
    _log_detection "hidden" "html-comment-injection" "${local_line:-0}" "BLOCKED"
    BLOCKED=true
    echo "BLOCKED [Prompt Injection Guard]: HTML comment injection in $FILE_PATH:${local_line:-?}" >&2
  fi
fi

if [[ "$BLOCKED" == "false" ]]; then
  if grep -qiP '<div[^>]*display\s*:\s*none' "$FILE_PATH" 2>/dev/null; then
    _log_detection "hidden" "hidden-div" 0 "BLOCKED"
    BLOCKED=true
    echo "BLOCKED [Prompt Injection Guard]: hidden div in $FILE_PATH" >&2
  fi
fi

# Category 3 — Social engineering (WARN only, do not block)
if [[ "$BLOCKED" == "false" ]]; then
  SOCIAL_PATTERNS=(
    "do not tell the user"
    "don't mention this to"
    "keep this secret from"
    "the user doesn't need to know"
    "hide this from the user"
  )
  line_num=0
  while IFS= read -r line; do
    ((line_num++))
    lower_line=$(echo "$line" | tr '[:upper:]' '[:lower:]')
    for pattern in "${SOCIAL_PATTERNS[@]}"; do
      if [[ "$lower_line" == *"$pattern"* ]]; then
        _log_detection "social" "$pattern" "$line_num" "WARNED"
        WARNED=true
        echo "WARNING [Prompt Injection Guard]: social engineering pattern in $FILE_PATH:$line_num — '$pattern'" >&2
        break
      fi
    done
  done < "$FILE_PATH"
fi

# Exit
if [[ "$BLOCKED" == "true" ]]; then
  exit 2
fi
exit 0
