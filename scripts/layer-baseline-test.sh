#!/usr/bin/env bash
# layer-baseline-test.sh — SE-348: criterion 7 (falsability) for coordination layers
#
# Decides whether a complex coordination layer (multi-agent orchestrator, tribunal,
# skill) justifies its complexity over a simpler baseline (single agent, no layer,
# ablated layer). Rule: if the complex system does not beat the simple baseline,
# the complexity is not justified.
#
# Usage:
#   layer-baseline-test.sh --full-metrics FULL.json --baseline-metrics BASE.json \
#     [--cost-multiplier N] [--min-delta X] [--json]
#
#   --full-metrics      metrics of the full system (WITH the layer)
#   --baseline-metrics  metrics of the simple baseline (WITHOUT the layer)
#   --cost-multiplier   default 1.0 — effective threshold = min_delta * multiplier.
#                       Justifies extra latency/cost: a layer costing 2x must win 2x.
#   --min-delta         default 0.05 — minimum required average delta
#
# Decision: JUSTIFIED if avg_delta STRICTLY > effective_threshold (exit 0),
#           UNJUSTIFIED otherwise (exit 1). Input errors → exit 2.
#
# Metrics: numeric keys present in BOTH files are compared (null/strings ignored).
# Ref: docs/propuestas/SE-348-resiliencia-baseline-capas.md
# CRIT-001: local computation only.

set -uo pipefail

FULL=""
BASELINE=""
MIN_DELTA="0.05"
COST_MULT="1.0"
JSON_OUT=false

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full-metrics) FULL="$2"; shift 2 ;;
    --baseline-metrics) BASELINE="$2"; shift 2 ;;
    --min-delta) MIN_DELTA="$2"; shift 2 ;;
    --cost-multiplier) COST_MULT="$2"; shift 2 ;;
    --json) JSON_OUT=true; shift ;;
    --help|-h) usage ;;
    *) echo "Error: unknown flag '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$FULL" ]] && { echo "Error: --full-metrics required" >&2; exit 2; }
[[ -z "$BASELINE" ]] && { echo "Error: --baseline-metrics required" >&2; exit 2; }
[[ ! -f "$FULL" ]] && { echo "Error: file not found: $FULL" >&2; exit 2; }
[[ ! -f "$BASELINE" ]] && { echo "Error: file not found: $BASELINE" >&2; exit 2; }

export SE348_FULL="$FULL"
export SE348_BASELINE="$BASELINE"
export SE348_MIN_DELTA="$MIN_DELTA"
export SE348_COST_MULT="$COST_MULT"
export SE348_JSON="$JSON_OUT"

python3 <<'PY'
import json, os, sys

def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def main():
    try:
        full = load(os.environ["SE348_FULL"])
        baseline = load(os.environ["SE348_BASELINE"])
    except Exception as e:
        sys.stderr.write(f"Error loading metrics: {e}\n")
        sys.exit(2)

    min_delta = float(os.environ["SE348_MIN_DELTA"])
    cost_mult = float(os.environ["SE348_COST_MULT"])
    as_json = os.environ.get("SE348_JSON") == "true"

    keys = [k for k in full if k in baseline
            and isinstance(full[k], (int, float)) and not isinstance(full[k], bool)
            and isinstance(baseline[k], (int, float)) and not isinstance(baseline[k], bool)
            and full[k] is not None and baseline[k] is not None]

    deltas = [{"metric": k, "full": full[k], "baseline": baseline[k],
               "delta": round(full[k] - baseline[k], 4)} for k in keys]
    avg_delta = round(sum(d["delta"] for d in deltas) / len(deltas), 4) if deltas else 0.0

    threshold = min_delta * cost_mult
    # Strict >: a layer that merely ties its baseline is not justified.
    status = "JUSTIFIED" if avg_delta > threshold else "UNJUSTIFIED"
    exit_code = 0 if status == "JUSTIFIED" else 1

    if as_json:
        print(json.dumps({
            "min_delta": min_delta,
            "cost_multiplier": cost_mult,
            "threshold": threshold,
            "avg_delta": avg_delta,
            "status": status,
            "compared_metrics": len(deltas),
            "deltas": deltas,
        }, indent=2))
    else:
        print("=== Layer Baseline Test (criterion 7) ===")
        print(f"Min delta: {min_delta}   Cost multiplier: {cost_mult}   Effective threshold: {threshold}")
        print(f"Metrics compared: {len(deltas)}   Average observed delta: {avg_delta}")
        print(f"Status: {status}")
        print()
        print(f"{'Metric':<28} {'Full':<10} {'Baseline':<10} {'Delta':<10}")
        for d in deltas:
            print(f"  {d['metric']:<26} {d['full']:<10} {d['baseline']:<10} {d['delta']:<10}")
        if not deltas:
            print("(no common numeric metrics — cannot judge)")

    sys.exit(exit_code)

if __name__ == "__main__":
    main()
PY
