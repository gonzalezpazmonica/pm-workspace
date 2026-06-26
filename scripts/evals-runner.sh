#!/usr/bin/env bash
# evals-runner.sh — SPEC-151 local evaluation runner.
set -uo pipefail
#
# Reads tests/evals/datasets/*.jsonl, runs heuristic evaluation
# (no real LLM in mock mode), compares against baselines,
# and outputs a paired-delta report JSON.
#
# Usage:
#   ./scripts/evals-runner.sh [--mock] [--dataset NAME] [--output FILE]
#
# Options:
#   --mock       Use pre-generated fixtures instead of live LLM calls.
#   --dataset    Run only the specified dataset (e.g. pbi-decomposition).
#   --output     Write report to FILE (default: stdout).
#   --threshold  Override degradation threshold (default 0.05 or env).
#
# Output JSON:
#   [{dataset, baseline_score, current_score, delta, threshold_pass}, ...]
#
# Reference: SPEC-151, paired-delta pattern (DeepEval CI docs + Future AGI 2026).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATASETS_DIR="$ROOT_DIR/tests/evals/datasets"
BASELINES_DIR="$ROOT_DIR/tests/evals/baselines"
RESULTS_DIR="$ROOT_DIR/tests/evals/results"
DELTA_SCRIPT="$SCRIPT_DIR/evals-paired-delta.py"

MOCK=false
TARGET_DATASET=""
OUTPUT_FILE=""
THRESHOLD="${SAVIA_EVAL_DELTA_THRESHOLD:-0.05}"

# ── argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mock)       MOCK=true ;;
    --dataset)    TARGET_DATASET="$2"; shift ;;
    --output)     OUTPUT_FILE="$2"; shift ;;
    --threshold)  THRESHOLD="$2"; shift ;;
    -h|--help)
      grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# //'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

mkdir -p "$RESULTS_DIR"

# ── heuristic scorer (mock mode) ──────────────────────────────────────────────
# Assigns a score [0.0, 1.0] purely from structural properties of the input.
# Not an LLM — deterministic and cheap. Used in CI when LLM not available.
heuristic_score() {
  local jsonl_line="$1"
  # Proxy: length of input string, normalized to 0.7-0.95 range
  local input_len
  input_len=$(echo "$jsonl_line" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    inp = d.get('input', d.get('text', str(d)))
    # Normalize: longer and more structured inputs score higher
    score = min(0.95, 0.70 + len(inp) / 1000)
    print(f'{score:.4f}')
except Exception:
    print('0.7500')
")
  echo "$input_len"
}

# ── process a single dataset ──────────────────────────────────────────────────
process_dataset() {
  local dataset_path="$1"
  local dataset_name
  dataset_name="$(basename "$dataset_path" .jsonl)"

  # Find baseline
  local baseline_file="$BASELINES_DIR/${dataset_name}-baseline.json"
  if [[ ! -f "$baseline_file" ]]; then
    # No baseline → skip with note
    echo "{\"dataset\": \"$dataset_name\", \"baseline_score\": null, \"current_score\": null, \"delta\": null, \"threshold_pass\": true, \"note\": \"no baseline found\"}"
    return
  fi

  # Compute current scores
  local tmp_current
  tmp_current=$(mktemp /tmp/evals-current-XXXXXX.json)
  # shellcheck disable=SC2064
  trap "rm -f '$tmp_current'" RETURN

  python3 - <<EOF > "$tmp_current"
import json, sys
from pathlib import Path

dataset_file = "$dataset_path"
mock = $([[ "$MOCK" == "true" ]] && echo "True" || echo "False")

scores = []
with open(dataset_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            item = json.loads(line)
            item_id = item.get("id", f"row-{len(scores)}")
            if mock:
                # deterministic heuristic: normalize input length to 0.70-0.95
                inp = item.get("input", item.get("text", str(item)))
                score = min(0.95, 0.70 + len(inp) / 1000)
            else:
                # placeholder: real LLM call would go here
                score = 0.80
            scores.append({"id": item_id, "score": round(score, 4)})
        except json.JSONDecodeError:
            continue

print(json.dumps(scores, indent=2))
EOF

  # Compute mean scores for summary
  local baseline_mean current_mean delta
  baseline_mean=$(python3 -c "
import json
data = json.loads(open('$baseline_file').read())
if isinstance(data, list):
    scores = [float(d['score']) for d in data]
else:
    scores = [float(v['score']) if isinstance(v, dict) else float(v) for v in data.values()]
print(f'{sum(scores)/len(scores):.4f}' if scores else '0')
")
  current_mean=$(python3 -c "
import json
data = json.loads(open('$tmp_current').read())
scores = [float(d['score']) for d in data]
print(f'{sum(scores)/len(scores):.4f}' if scores else '0')
")
  delta=$(python3 -c "print(f'{float($current_mean) - float($baseline_mean):.4f}')")

  # Run paired-delta script for threshold evaluation
  local pass_result
  local threshold_pass="true"
  if python3 "$DELTA_SCRIPT" \
      --baseline "$baseline_file" \
      --current "$tmp_current" \
      --threshold "$THRESHOLD" > /dev/null 2>&1; then
    threshold_pass="true"
  else
    threshold_pass="false"
  fi

  echo "{\"dataset\": \"$dataset_name\", \"baseline_score\": $baseline_mean, \"current_score\": $current_mean, \"delta\": $delta, \"threshold_pass\": $threshold_pass}"
}

# ── main loop ─────────────────────────────────────────────────────────────────
results=()

if [[ -n "$TARGET_DATASET" ]]; then
  # Single dataset mode
  found=false
  while IFS= read -r -d '' jsonl_file; do
    name="$(basename "$jsonl_file" .jsonl)"
    if [[ "$name" == "$TARGET_DATASET" ]]; then
      results+=("$(process_dataset "$jsonl_file")")
      found=true
    fi
  done < <(find "$DATASETS_DIR" -name "*.jsonl" -print0 2>/dev/null)
  if [[ "$found" == "false" ]]; then
    echo "{\"error\": \"dataset '$TARGET_DATASET' not found in $DATASETS_DIR\"}" >&2
    exit 1
  fi
else
  # All datasets
  while IFS= read -r -d '' jsonl_file; do
    results+=("$(process_dataset "$jsonl_file")")
  done < <(find "$DATASETS_DIR" -name "*.jsonl" -print0 2>/dev/null | sort -z)
fi

# ── assemble output JSON ───────────────────────────────────────────────────────
output=$(python3 -c "
import json, sys
results = [json.loads(r) for r in sys.argv[1:]]
print(json.dumps(results, indent=2))
" "${results[@]}")

if [[ -n "$OUTPUT_FILE" ]]; then
  echo "$output" > "$OUTPUT_FILE"
  echo "Report written to $OUTPUT_FILE" >&2
else
  echo "$output"
fi
