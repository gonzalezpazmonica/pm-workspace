#!/usr/bin/env bash
# graphrag-quality-gate.sh — SE-030-T
# Validates a metrics JSON against 12 canonical GraphRAG thresholds.
# Ref: docs/rules/domain/graphrag-quality-gates.md
#
# Usage:
#   bash scripts/graphrag-quality-gate.sh --metrics FILE [--phase 1|2|3] [--json]
#
# Phases:
#   1 = WARN only (default, rollout phase 1)
#   2 = FAIL on generation layer
#   3 = FAIL on all 12
#
# Exit codes:
#   0 = all applicable thresholds PASS
#   1 = some FAIL in current phase (or all WARN if phase 1)
#   2 = input malformed

set -uo pipefail

METRICS=""
PHASE=1
JSON_OUT=false

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --metrics) METRICS="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    --json) JSON_OUT=true; shift ;;
    --help|-h) usage ;;
    *) echo "Error: unknown flag $1" >&2; exit 2 ;;
  esac
done

[[ -z "$METRICS" ]] && { echo "Error: --metrics required" >&2; exit 2; }
[[ ! -f "$METRICS" ]] && { echo "Error: file not found: $METRICS" >&2; exit 2; }

# ── Thresholds ───────────────────────────────────────────────────────────────
# (metric_name min_threshold layer direction)
# direction: ge = >=, le = <=

python3 <<PY
import json, sys

THRESHOLDS = [
    # (name,              min,   layer,       direction)
    ("ndcg_at_10",        0.75,  "retrieval",  "ge"),
    ("recall_at_20",      0.85,  "retrieval",  "ge"),
    ("mrr",               0.6,   "retrieval",  "ge"),
    ("cross_repo_precision", 0.7,"retrieval",  "ge"),
    ("context_coherence", 0.9,   "reasoning",  "ge"),
    ("relevance",         0.8,   "reasoning",  "ge"),
    ("completeness",      0.85,  "reasoning",  "ge"),
    ("groundedness",      0.9,   "generation", "ge"),
    ("hallucination",     0.1,   "generation", "le"),
    ("attribution_accuracy", 0.95, "generation", "ge"),
    ("factual_accuracy",  0.9,   "generation", "ge"),
    ("coherence_gen",     0.85,  "generation", "ge"),
]

phase = $PHASE
json_out = "${JSON_OUT}" == "true"

try:
    with open("$METRICS") as f:
        data = json.load(f)
except Exception as e:
    sys.stderr.write(f"Error: could not parse metrics JSON: {e}\n")
    sys.exit(2)

results = []
fails = 0
warns = 0
missing = 0

for name, threshold, layer, direction in THRESHOLDS:
    if name not in data:
        results.append({"metric": name, "status": "MISSING", "layer": layer})
        missing += 1
        continue
    value = data[name]
    passed = (value >= threshold) if direction == "ge" else (value <= threshold)
    # Determine if FAIL is enforced at this phase
    enforced = False
    if phase >= 3:
        enforced = True
    elif phase == 2 and layer == "generation":
        enforced = True
    # phase 1: WARN only

    if passed:
        status = "PASS"
    elif enforced:
        status = "FAIL"
        fails += 1
    else:
        status = "WARN"
        warns += 1

    results.append({
        "metric": name, "value": value, "threshold": threshold,
        "direction": direction, "layer": layer, "status": status
    })

if json_out:
    print(json.dumps({
        "phase": phase, "fails": fails, "warns": warns, "missing": missing,
        "metrics": results
    }))
else:
    print(f"=== GraphRAG Quality Gate (phase {phase}) ===")
    for r in results:
        if r["status"] == "MISSING":
            print(f"  [MISSING] {r['metric']}")
        else:
            sign = "≥" if r["direction"] == "ge" else "≤"
            print(f"  [{r['status']:5}] {r['metric']:<22} {r['value']:<6} {sign} {r['threshold']}")
    print(f"\nSummary: {fails} FAIL, {warns} WARN, {missing} MISSING")

# Exit codes
if fails > 0 or missing > 0:
    sys.exit(1)
elif warns > 0 and phase == 1:
    sys.exit(1)  # phase 1: any WARN is also non-zero exit
else:
    sys.exit(0)
PY
