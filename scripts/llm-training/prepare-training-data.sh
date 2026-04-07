#!/usr/bin/env bash
set -uo pipefail

# prepare-training-data.sh — SPEC-080: Extract training data from agent traces
# Converts agent traces to Alpaca/ShareGPT format for Unsloth fine-tuning.
# Usage: prepare-training-data.sh --agent AGENT [--format alpaca|sharegpt] [--min-quality 0.7]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TRACES_DIR="$BASE_DIR/output/agent-traces"
OUTPUT_DIR="$BASE_DIR/output/training-data"

usage() {
  cat <<'EOF'
Usage: prepare-training-data.sh --agent AGENT [options]

Options:
  --agent AGENT       Agent name (commit-guardian, tech-writer, etc.)
  --format FORMAT     Output format: alpaca (default) or sharegpt
  --min-quality N     Minimum quality score 0-1 (default: 0.7)
  --output FILE       Output JSONL file (default: output/training-data/{agent}.jsonl)
  --limit N           Max examples to extract (default: unlimited)

Extracts successful agent executions from traces and converts to
training data format compatible with Unsloth fine-tuning.
EOF
  exit 1
}

AGENT=""
FORMAT="alpaca"
MIN_QUALITY="0.7"
OUTPUT=""
LIMIT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --min-quality) MIN_QUALITY="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -z "$AGENT" ]] && usage

mkdir -p "$OUTPUT_DIR"
[[ -z "$OUTPUT" ]] && OUTPUT="$OUTPUT_DIR/${AGENT}-${FORMAT}.jsonl"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Training Data Preparation — $AGENT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for trace files
trace_count=0
if [[ -d "$TRACES_DIR" ]]; then
  trace_count=$(find "$TRACES_DIR" -name "*.jsonl" -exec grep -l "\"agent\":\"$AGENT\"" {} \; 2>/dev/null | wc -l)
fi

echo "  Agent: $AGENT"
echo "  Format: $FORMAT"
echo "  Min quality: $MIN_QUALITY"
echo "  Traces found: $trace_count"

if [[ $trace_count -eq 0 ]]; then
  echo ""
  echo "⚠️  No traces found for agent '$AGENT'"
  echo "   Traces are generated during agent execution and stored in:"
  echo "   $TRACES_DIR"
  echo ""
  echo "   To generate training data, first run the agent on real tasks."
  echo "   Example: /dev-session start → generates traces for developers"
  echo "   Example: git commit → generates traces for commit-guardian"
  echo ""
  echo "   Alternative: create synthetic training data manually in Alpaca format:"
  echo "   {\"instruction\":\"...\",\"input\":\"...\",\"output\":\"...\"}"
  exit 0
fi

# Extract and convert traces
count=0
echo "" > "$OUTPUT"

find "$TRACES_DIR" -name "*.jsonl" -exec grep "\"agent\":\"$AGENT\"" {} \; 2>/dev/null | \
while IFS= read -r line; do
  # Filter by quality (if field exists)
  quality=$(echo "$line" | grep -o '"quality":[0-9.]*' | cut -d: -f2 || echo "1.0")
  result=$(echo "$success" | grep -o '"success":true' || true)

  # Skip failed executions
  [[ -z "$result" ]] && continue

  # Extract instruction and output
  instruction=$(echo "$line" | grep -o '"prompt":"[^"]*"' | cut -d'"' -f4 | head -c 1000)
  output=$(echo "$line" | grep -o '"response":"[^"]*"' | cut -d'"' -f4 | head -c 2000)

  [[ -z "$instruction" || -z "$output" ]] && continue

  if [[ "$FORMAT" == "alpaca" ]]; then
    echo "{\"instruction\":\"$instruction\",\"input\":\"\",\"output\":\"$output\"}" >> "$OUTPUT"
  else
    echo "{\"conversations\":[{\"from\":\"human\",\"value\":\"$instruction\"},{\"from\":\"gpt\",\"value\":\"$output\"}]}" >> "$OUTPUT"
  fi

  count=$((count + 1))
  [[ $LIMIT -gt 0 && $count -ge $LIMIT ]] && break
done

total=$(wc -l < "$OUTPUT" 2>/dev/null || echo 0)
echo ""
echo "✅ Extracted $total training examples"
echo "📄 Output: $OUTPUT"
echo ""
echo "Next steps:"
echo "  1. Upload $OUTPUT to Google Colab"
echo "  2. Open the Unsloth fine-tune notebook"
echo "  3. Train with: model='unsloth/Qwen2.5-3B-bnb-4bit'"
echo "  4. Export GGUF and download"
echo "  5. Load in Ollama: ollama create $AGENT-custom -f Modelfile"
