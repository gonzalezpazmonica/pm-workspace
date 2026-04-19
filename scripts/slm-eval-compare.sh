#!/usr/bin/env bash
# slm-eval-compare.sh — A/B compare eval results between 2 SLM versions.
#
# Compara 2 archivos JSON de eval-run (output de slm-eval-run.py o similar)
# y emite un report con deltas por benchmark. Útil para decidir promote/
# rollback entre versiones.
#
# Input format (JSON):
#   {
#     "model": "savia-context:sft-v1",
#     "benchmarks": {
#       "coherence": {"score": 4.2, "pass_threshold": 4.0, "passed": true},
#       "pii-leak": {"score": 1.0, "pass_threshold": 1.0, "passed": true},
#       ...
#     },
#     "overall_score": 0.87,
#     "n_prompts": 50
#   }
#
# NO ejecuta eval — consume JSON ya generado.
#
# Usage:
#   slm-eval-compare.sh --baseline eval-v1.json --candidate eval-v2.json
#   slm-eval-compare.sh --baseline b.json --candidate c.json --json
#   slm-eval-compare.sh --baseline b.json --candidate c.json --min-improvement 0.05
#
# Exit codes:
#   0 — candidate ≥ baseline on all benchmarks (or --min-improvement satisfied)
#   1 — candidate regresses on 1+ benchmarks
#   2 — usage error
#
# Ref: SPEC-SE-027 §Eval, docs/rules/domain/slm-training-pipeline.md §Fase 5
# Safety: read-only, set -uo pipefail.

set -uo pipefail

BASELINE=""
CANDIDATE=""
JSON=0
MIN_IMPROVEMENT="0"

usage() {
  cat <<EOF
Usage:
  $0 --baseline FILE --candidate FILE [--json] [--min-improvement PCT]

  --baseline FILE           JSON con eval results del modelo existente
  --candidate FILE          JSON con eval results del nuevo modelo
  --min-improvement PCT     Mínima mejora total requerida (0.0-1.0, default 0)
  --json                    Output JSON estructurado

Compara per-benchmark y overall. Exit 1 si candidate regresa, 0 si mejora.

Ref: SPEC-SE-027 §Eval
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --baseline) BASELINE="$2"; shift 2 ;;
    --candidate) CANDIDATE="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    --min-improvement) MIN_IMPROVEMENT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$BASELINE" ]] && { echo "ERROR: --baseline required" >&2; exit 2; }
[[ -z "$CANDIDATE" ]] && { echo "ERROR: --candidate required" >&2; exit 2; }
[[ ! -f "$BASELINE" ]] && { echo "ERROR: baseline not found: $BASELINE" >&2; exit 2; }
[[ ! -f "$CANDIDATE" ]] && { echo "ERROR: candidate not found: $CANDIDATE" >&2; exit 2; }

# Validate min-improvement is a float in [0,1].
if ! [[ "$MIN_IMPROVEMENT" =~ ^0?\.[0-9]+$|^1\.0*$|^0$|^1$ ]]; then
  echo "ERROR: --min-improvement must be float in [0,1], got '$MIN_IMPROVEMENT'" >&2
  exit 2
fi

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required" >&2; exit 2; }

python3 - "$BASELINE" "$CANDIDATE" "$JSON" "$MIN_IMPROVEMENT" <<'PY'
import json, sys

baseline_path = sys.argv[1]
candidate_path = sys.argv[2]
json_out = int(sys.argv[3])
min_improvement = float(sys.argv[4])

try:
    with open(baseline_path) as f: baseline = json.load(f)
    with open(candidate_path) as f: candidate = json.load(f)
except json.JSONDecodeError as e:
    print(f"ERROR: invalid JSON — {e}", file=sys.stderr)
    sys.exit(2)

b_bench = baseline.get("benchmarks", {})
c_bench = candidate.get("benchmarks", {})

# Compare per-benchmark.
comparisons = []
regressions = []
improvements = []

all_names = sorted(set(b_bench.keys()) | set(c_bench.keys()))
for name in all_names:
    b = b_bench.get(name, {})
    c = c_bench.get(name, {})
    b_score = b.get("score")
    c_score = c.get("score")
    if b_score is None or c_score is None:
        comparisons.append({"benchmark": name, "status": "incomparable",
                            "baseline": b_score, "candidate": c_score})
        continue
    delta = c_score - b_score
    status = "improved" if delta > 0 else ("regressed" if delta < 0 else "unchanged")
    entry = {
        "benchmark": name,
        "baseline": b_score,
        "candidate": c_score,
        "delta": round(delta, 4),
        "status": status,
    }
    comparisons.append(entry)
    if status == "regressed":
        regressions.append(entry)
    elif status == "improved":
        improvements.append(entry)

# Overall.
b_overall = baseline.get("overall_score", 0.0)
c_overall = candidate.get("overall_score", 0.0)
overall_delta = round(c_overall - b_overall, 4)

# Verdict.
verdict_code = 0
verdict = "PROMOTE"
reason = "candidate ≥ baseline on all benchmarks"

if regressions:
    verdict_code = 1
    verdict = "ROLLBACK"
    reason = f"{len(regressions)} benchmark regression(s): " + ", ".join(r["benchmark"] for r in regressions[:3])
elif overall_delta < min_improvement:
    verdict_code = 1
    verdict = "REJECT"
    reason = f"overall delta {overall_delta:+.4f} < min-improvement {min_improvement:+.4f}"

report = {
    "verdict": verdict,
    "reason": reason,
    "baseline_model": baseline.get("model", "?"),
    "candidate_model": candidate.get("model", "?"),
    "baseline_overall": b_overall,
    "candidate_overall": c_overall,
    "overall_delta": overall_delta,
    "n_benchmarks_compared": len(all_names),
    "n_improvements": len(improvements),
    "n_regressions": len(regressions),
    "comparisons": comparisons,
}

if json_out:
    print(json.dumps(report, ensure_ascii=False, indent=2))
else:
    print(f"=== Eval Compare ===")
    print(f"Baseline:  {report['baseline_model']} (overall {b_overall:.4f})")
    print(f"Candidate: {report['candidate_model']} (overall {c_overall:.4f})")
    print(f"Delta:     {overall_delta:+.4f}")
    print()
    print("Per-benchmark:")
    for c in comparisons:
        if c["status"] == "incomparable":
            print(f"  {c['benchmark']:<25} {'N/A':<10} {'N/A':<10} (missing in one side)")
        else:
            marker = "📈" if c["status"] == "improved" else ("📉" if c["status"] == "regressed" else "=")
            print(f"  {c['benchmark']:<25} {c['baseline']:<10.4f} → {c['candidate']:<10.4f} {marker} {c['delta']:+.4f}")
    print()
    print(f"Summary: {len(improvements)} improved, {len(regressions)} regressed, {len(comparisons)-len(improvements)-len(regressions)} unchanged")
    print()
    print(f"VERDICT: {verdict}")
    print(f"  {reason}")

sys.exit(verdict_code)
PY
rc=$?
exit $rc
