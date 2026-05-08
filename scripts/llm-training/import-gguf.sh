#!/usr/bin/env bash
set -uo pipefail

# import-gguf.sh — SPEC-080: Import fine-tuned GGUF model into Ollama
# Usage: import-gguf.sh --model PATH --name NAME [--system PROMPT]

usage() {
  cat <<'EOF'
Usage: import-gguf.sh --model PATH --name NAME [--system PROMPT_FILE]

  --model PATH       Path to the .gguf file (downloaded from Colab)
  --name NAME        Ollama model name (e.g., commit-guardian-custom)
  --system FILE      System prompt file (default: from agent .md)

Creates an Ollama Modelfile and imports the fine-tuned model.
After import, use: ollama run NAME
EOF
  exit 1
}

MODEL_PATH=""
MODEL_NAME=""
SYSTEM_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL_PATH="$2"; shift 2 ;;
    --name) MODEL_NAME="$2"; shift 2 ;;
    --system) SYSTEM_FILE="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -z "$MODEL_PATH" || -z "$MODEL_NAME" ]] && usage

if [[ ! -f "$MODEL_PATH" ]]; then
  echo "❌ Model file not found: $MODEL_PATH"
  exit 1
fi

# Build system prompt
SYSTEM_PROMPT="You are a specialized AI assistant."
if [[ -n "$SYSTEM_FILE" && -f "$SYSTEM_FILE" ]]; then
  SYSTEM_PROMPT=$(cat "$SYSTEM_FILE")
elif [[ -f ".opencode/agents/${MODEL_NAME%.custom*}.md" ]]; then
  # Extract system prompt from agent definition (skip frontmatter)
  agent_file=".opencode/agents/${MODEL_NAME%-custom}.md"
  if [[ -f "$agent_file" ]]; then
    SYSTEM_PROMPT=$(sed -n '/^---$/,/^---$/d;p' "$agent_file" | head -50)
  fi
fi

# Create Modelfile
MODELFILE=$(mktemp)
trap "rm -f '$MODELFILE'" EXIT

cat > "$MODELFILE" << EOF
FROM $MODEL_PATH

SYSTEM """
$SYSTEM_PROMPT
"""

PARAMETER temperature 0.3
PARAMETER num_predict 2048
PARAMETER stop "<|im_end|>"
PARAMETER stop "<|endoftext|>"
EOF

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Importing GGUF → Ollama"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Model: $MODEL_PATH"
echo "  Name: $MODEL_NAME"
echo "  Size: $(du -sh "$MODEL_PATH" | cut -f1)"
echo ""

ollama create "$MODEL_NAME" -f "$MODELFILE" 2>&1

if [[ $? -eq 0 ]]; then
  echo ""
  echo "✅ Model imported: $MODEL_NAME"
  echo "   Test: ollama run $MODEL_NAME"
  echo "   List: ollama list"
else
  echo "❌ Import failed"
  exit 1
fi
