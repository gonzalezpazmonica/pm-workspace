#!/usr/bin/env bash
# eval-ablation-run.sh — SE-030-A
# Runs a quality-gate evaluation with a layer ablated, to measure seam
# degradation. Compares full metrics vs ablated metrics.
# Ref: docs/propuestas/SE-030-graphrag-quality-gates.md
#
# Usage:
#   bash scripts/eval-ablation-run.sh \
#     --full-metrics FULL.json --ablated-metrics ABLATED.json \
#     --ablated-layer {retrieval|reasoning|generation|graph} [--json]
#
# Expected deltas per bytebell End-to-End Stress Test (Ene '26):
#   ablate graph    → NDCG drops ≥ 0.10, pass@1 drops ≥ 0.05
#   ablate retrieval→ all downstream metrics should drop
#
# Exit codes:
#   0 = ablation produces expected degradation (layer adds value)
#   1 = ablation delta too small (layer has questionable value — warning)
#   2 = input error

set -uo pipefail

FULL=""
ABLATED=""
ABLATED_LAYER=""
JSON_OUT=false
MIN_DELTA="0.05"

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full-metrics) FULL="$2"; shift 2 ;;
    --ablated-metrics) ABLATED="$2"; shift 2 ;;
    --ablated-layer) ABLATED_LAYER="$2"; shift 2 ;;
    --min-delta) MIN_DELTA="$2"; shift 2 ;;
    --json) JSON_OUT=true; shift ;;
    --help|-h) usage ;;
    *) echo "Error: unknown flag $1" >&2; exit 2 ;;
  esac
done

[[ -z "$FULL" ]] && { echo "Error: --full-metrics required" >&2; exit 2; }
[[ -z "$ABLATED" ]] && { echo "Error: --ablated-metrics required" >&2; exit 2; }
[[ ! -f "$FULL" ]] && { echo "Error: file not found: $FULL" >&2; exit 2; }
[[ ! -f "$ABLATED" ]] && { echo "Error: file not found: $ABLATED" >&2; exit 2; }
[[ -z "$ABLATED_LAYER" ]] && { echo "Error: --ablated-layer required" >&2; exit 2; }

# Validate ablated layer enum
case "$ABLATED_LAYER" in
  retrieval|reasoning|generation|graph) ;;
  *) echo "Error: --ablated-layer must be retrieval|reasoning|generation|graph (got '$ABLATED_LAYER')" >&2; exit 2 ;;
esac

# ── Compute deltas and assess ────────────────────────────────────────────────
python3 <<PY
import json, sys

try:
    with open("$FULL") as f: full = json.load(f)
    with open("$ABLATED") as f: ablated = json.load(f)
except Exception as e:
    sys.stderr.write(f"Error: {e}\n"); sys.exit(2)

# Metrics to track deltas on
METRICS_TO_CHECK = [
    "ndcg_at_10", "recall_at_20", "mrr", "cross_repo_precision",
    "context_coherence", "relevance", "completeness",
    "groundedness", "attribution_accuracy", "factual_accuracy",
]
# Inverse-polarity metrics (higher ablation value = worse)
INVERSE = ["hallucination"]

min_delta = $MIN_DELTA
ablated_layer = "$ABLATED_LAYER"
json_out = "${JSON_OUT}" == "true"

deltas = []
total_delta = 0.0
count = 0

for m in METRICS_TO_CHECK:
    if m in full and m in ablated:
        d = full[m] - ablated[m]
        deltas.append({"metric": m, "full": full[m], "ablated": ablated[m], "delta": round(d, 4)})
        total_delta += d
        count += 1

for m in INVERSE:
    if m in full and m in ablated:
        d = ablated[m] - full[m]  # inverse: more hallucination is worse
        deltas.append({"metric": m, "full": full[m], "ablated": ablated[m], "delta": round(d, 4), "inverse": True})
        total_delta += d
        count += 1

avg_delta = round(total_delta / count, 4) if count > 0 else 0.0

# Assess: did ablation produce expected degradation?
status = "VALUABLE" if avg_delta >= min_delta else "QUESTIONABLE"
exit_code = 0 if status == "VALUABLE" else 1

if json_out:
    print(json.dumps({
        "ablated_layer": ablated_layer,
        "min_delta": min_delta,
        "avg_delta": avg_delta,
        "status": status,
        "deltas": deltas
    }))
else:
    print(f"=== Ablation Seam Test: {ablated_layer} ===")
    print(f"Min expected delta: {min_delta}")
    print(f"Average observed delta: {avg_delta}")
    print(f"Status: {status}")
    print()
    print(f"{'Metric':<24} {'Full':<8} {'Ablated':<8} {'Delta':<8}")
    for d in deltas:
        tag = " (inverse)" if d.get("inverse") else ""
        print(f"  {d['metric']:<22} {d['full']:<8} {d['ablated']:<8} {d['delta']:<8}{tag}")

sys.exit(exit_code)
PY
