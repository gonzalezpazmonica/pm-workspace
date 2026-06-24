#!/usr/bin/env bash
# speculative-telemetry-report.sh — Telemetry dashboard for SE-220 (Slice 4).
#
# Reads output/speculative-execution-telemetry.jsonl and computes:
#   - cache_hit_rate       (cache_hit=true / total records with cache_hit field)
#   - avg_latency_saved_ms (mean of latency_saved_ms where cache_hit=true)
#   - prediction_accuracy  (records where predicted ∩ actual non-empty / records with actual)
#   - total_speculative_executions (records with speculative_launched=true)
#
# GO/CONTINUE criteria:  cache_hit_rate >= 0.30 AND avg_latency_saved_ms >= 100
# KILL criteria:         prediction_accuracy < 0.50 OR cache_hit_rate < 0.10
# Otherwise:             TUNE
#
# Usage:
#   bash scripts/speculative-telemetry-report.sh [--json] [--file PATH]
#
# Output: human-readable table (default) or JSON (--json)
#
# Ref: SE-220 — Speculative Tool Execution, Slice 4

set -uo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────
OUTPUT_JSON=false
TELEMETRY_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)        OUTPUT_JSON=true;          shift ;;
    --file)        TELEMETRY_FILE="$2";       shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--json] [--file PATH]"
      echo "  --json        Output as JSON instead of text table"
      echo "  --file PATH   Path to telemetry JSONL (default: output/speculative-execution-telemetry.jsonl)"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Resolve paths ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PYTHON="${PYTHON:-python3}"

if [[ -z "$TELEMETRY_FILE" ]]; then
  TELEMETRY_FILE="$ROOT_DIR/output/speculative-execution-telemetry.jsonl"
fi

# ── Check telemetry file exists ───────────────────────────────────────────────
if [[ ! -f "$TELEMETRY_FILE" ]]; then
  if [[ "$OUTPUT_JSON" == "true" ]]; then
    echo '{"error": "telemetry file not found", "file": "'"$TELEMETRY_FILE"'", "verdict": "NO_DATA"}'
  else
    echo "SE-220 Speculative Execution Telemetry"
    echo "======================================="
    echo "No telemetry file found: $TELEMETRY_FILE"
    echo "Run with SAVIA_SPECULATIVE_EXECUTION=on to collect data."
  fi
  exit 0
fi

# ── Compute metrics via Python (stdlib only) ──────────────────────────────────
"$PYTHON" - "$TELEMETRY_FILE" "$OUTPUT_JSON" << 'PYEOF'
import json
import sys
from pathlib import Path

telemetry_file = Path(sys.argv[1])
output_json = sys.argv[2] == "true"

# ── Parse JSONL ──────────────────────────────────────────────────────────────
records = []
corrupt = 0
with telemetry_file.open() as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        try:
            records.append(json.loads(line))
        except json.JSONDecodeError:
            corrupt += 1

total_records = len(records)

# ── Cache hit rate ────────────────────────────────────────────────────────────
# Records that have the cache_hit field (resolve events)
resolve_records = [r for r in records if "cache_hit" in r]
hit_records = [r for r in resolve_records if r.get("cache_hit") is True]

cache_hit_rate = (
    len(hit_records) / len(resolve_records)
    if resolve_records else 0.0
)

# ── Avg latency saved ─────────────────────────────────────────────────────────
latencies = [
    float(r.get("latency_saved_ms", 0))
    for r in hit_records
    if r.get("latency_saved_ms", 0) > 0
]
avg_latency_saved_ms = (
    sum(latencies) / len(latencies) if latencies else 0.0
)

# ── Prediction accuracy ───────────────────────────────────────────────────────
# Records where "actual" is non-empty (the model actually ran the tool)
actual_records = [
    r for r in records
    if r.get("actual") and len(r.get("actual", [])) > 0
]
accurate_records = [
    r for r in actual_records
    if set(r.get("predicted", [])) & set(r.get("actual", []))
]
prediction_accuracy = (
    len(accurate_records) / len(actual_records)
    if actual_records else 0.0
)

# ── Total speculative executions ──────────────────────────────────────────────
speculative_launched = [r for r in records if r.get("speculative_launched") is True]
total_speculative_executions = len(speculative_launched)

# ── Verdict ───────────────────────────────────────────────────────────────────
# KILL:     prediction_accuracy < 0.50 OR cache_hit_rate < 0.10
# GO:       cache_hit_rate >= 0.30 AND avg_latency_saved_ms >= 100
# TUNE:     everything else

if actual_records and (prediction_accuracy < 0.50):
    verdict = "KILL"
elif resolve_records and (cache_hit_rate < 0.10):
    verdict = "KILL"
elif cache_hit_rate >= 0.30 and avg_latency_saved_ms >= 100.0:
    verdict = "GO"
elif total_records == 0:
    verdict = "NO_DATA"
else:
    verdict = "TUNE"

# ── Output ────────────────────────────────────────────────────────────────────
metrics = {
    "total_records": total_records,
    "corrupt_lines": corrupt,
    "resolve_records": len(resolve_records),
    "cache_hit_records": len(hit_records),
    "cache_hit_rate": round(cache_hit_rate, 4),
    "latency_samples": len(latencies),
    "avg_latency_saved_ms": round(avg_latency_saved_ms, 1),
    "actual_records": len(actual_records),
    "accurate_predictions": len(accurate_records),
    "prediction_accuracy": round(prediction_accuracy, 4),
    "total_speculative_executions": total_speculative_executions,
    "verdict": verdict,
    "criteria": {
        "go": "cache_hit_rate >= 0.30 AND avg_latency_saved_ms >= 100",
        "kill": "prediction_accuracy < 0.50 OR cache_hit_rate < 0.10",
        "tune": "all other cases",
    },
}

if output_json:
    print(json.dumps(metrics, indent=2))
else:
    W = 42
    def row(label, value):
        return f"  {label:<35} {value}"

    print("SE-220 Speculative Execution Telemetry")
    print("=" * W)
    print(row("Total records",         total_records))
    print(row("Corrupt lines",         corrupt))
    print()
    print("Cache Performance")
    print("-" * W)
    print(row("Resolve events",        len(resolve_records)))
    print(row("Cache hits",            len(hit_records)))
    print(row("Cache hit rate",        f"{cache_hit_rate:.1%}"))
    print(row("Latency samples",       len(latencies)))
    print(row("Avg latency saved (ms)",f"{avg_latency_saved_ms:.1f}"))
    print()
    print("Prediction Quality")
    print("-" * W)
    print(row("Records with actual",   len(actual_records)))
    print(row("Accurate predictions",  len(accurate_records)))
    print(row("Prediction accuracy",   f"{prediction_accuracy:.1%}"))
    print(row("Speculative launches",  total_speculative_executions))
    print()
    print("=" * W)
    print(f"  VERDICT: {verdict}")
    print("=" * W)
    print(f"  GO   if: cache_hit_rate >= 0.30 AND avg_latency_saved_ms >= 100")
    print(f"  KILL if: prediction_accuracy < 0.50 OR cache_hit_rate < 0.10")
    print(f"  TUNE otherwise")
PYEOF

exit 0
