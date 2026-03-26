#!/usr/bin/env bash
# shield-ner-hook.sh — Savia Shield Capa 1.5: NER hook wrapper
# SEC-013 FIX: Wires shield-ner-scan.py into the PreToolUse chain
# Exit 0 = clean/skip, Exit 2 = PII detected (block write)
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
NER_SCRIPT="$PROJECT_DIR/scripts/shield-ner-scan.py"

# Skip if Presidio not installed (graceful degradation)
if ! python3 -c "import presidio_analyzer" 2>/dev/null; then
  exit 0
fi

[[ ! -f "$NER_SCRIPT" ]] && exit 0

# Read hook input
INPUT=""
if [[ ! -t 0 ]]; then
  if command -v timeout >/dev/null 2>&1 && timeout --version >/dev/null 2>&1; then
    INPUT=$(timeout 3 cat 2>/dev/null) || true
  else
    INPUT=$(cat 2>/dev/null) || true
  fi
fi

[[ -z "$INPUT" ]] && exit 0

# Extract file_path and content
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
CONTENT=$(printf '%s' "$INPUT" | jq -r '(.tool_input.content // .tool_input.new_string // "")[:5000]' 2>/dev/null) || exit 0

[[ -z "$FILE_PATH" ]] && exit 0
[[ ${#CONTENT} -lt 20 ]] && exit 0

# Only scan public destinations
case "$FILE_PATH" in
  */projects/*|*.local.*|*/output/*|*private-agent-memory*|*/config.local/*|*/.savia/*|*/.claude/sessions/*|*settings.local.json*) exit 0 ;;
esac

# Skip security doc files
case "$FILE_PATH" in
  *data-sovereignty*|*ollama-classify*|*shield-ner*|*test-data-sovereignty*) exit 0 ;;
esac

# Find glossary
GLOSSARY_ARG=""
for g in "$PROJECT_DIR"/projects/*/GLOSSARY-MASK.md; do
  [[ -f "$g" ]] && GLOSSARY_ARG="--glossary $g" && break
done

# Run NER scan with threshold 0.7
RESULT=$(echo "$CONTENT" | python3 "$NER_SCRIPT" $GLOSSARY_ARG --threshold 0.7 2>/dev/null)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 1 ]]; then
  echo "BLOQUEADO [Capa 1.5 NER]: Entidades PII detectadas en destino publico: $FILE_PATH" >&2
  echo "$RESULT" >&2
  exit 2
fi

exit 0
