#!/usr/bin/env python3
"""evals-paired-delta.py — SPEC-151 paired-delta calculation.

Compares baseline scores against current scores to detect regressions.
Uses paired-delta (per-test comparison) instead of aggregate pass-rate,
as recommended by DeepEval CI docs and Future AGI 2026.

Threshold: 5% degradation on mean_delta = fail.
Configurable via SAVIA_EVAL_DELTA_THRESHOLD env var.

Input:
  --baseline  path to baseline JSON (list of {id, score, ...})
  --current   path to current JSON  (list of {id, score, ...})

Output JSON:
  {mean_delta, std_delta, degradation_count, improvement_count,
   threshold_pass, threshold_used, pairs_evaluated}
"""

import argparse
import json
import math
import os
import sys
from pathlib import Path
from typing import Any


def load_scores(path: str) -> dict[str, float]:
    """Load scores from a JSON file. Returns {id: score}."""
    data = json.loads(Path(path).read_text())
    # Support both list-of-dicts and dict-of-dicts
    if isinstance(data, list):
        return {item["id"]: float(item["score"]) for item in data}
    if isinstance(data, dict):
        return {k: float(v["score"]) if isinstance(v, dict) else float(v) for k, v in data.items()}
    raise ValueError(f"Unexpected format in {path}")


def compute_paired_delta(
    baseline: dict[str, float],
    current: dict[str, float],
    threshold: float = 0.05,
) -> dict[str, Any]:
    """Compute paired delta between baseline and current score sets.

    Returns:
        mean_delta:        mean(current_score - baseline_score) per pair
        std_delta:         std dev of deltas
        degradation_count: number of pairs where delta < -threshold
        improvement_count: number of pairs where delta > 0
        threshold_pass:    True if mean_delta >= -threshold
        threshold_used:    threshold value applied
        pairs_evaluated:   number of matched pairs
    """
    # Only evaluate IDs present in both
    common_ids = sorted(set(baseline.keys()) & set(current.keys()))
    if not common_ids:
        return {
            "mean_delta": 0.0,
            "std_delta": 0.0,
            "degradation_count": 0,
            "improvement_count": 0,
            "threshold_pass": True,
            "threshold_used": threshold,
            "pairs_evaluated": 0,
            "warning": "no common IDs between baseline and current",
        }

    deltas = [current[id_] - baseline[id_] for id_ in common_ids]
    mean_delta = sum(deltas) / len(deltas)
    variance = sum((d - mean_delta) ** 2 for d in deltas) / len(deltas) if len(deltas) > 1 else 0.0
    std_delta = math.sqrt(variance)

    degradation_count = sum(1 for d in deltas if d < -threshold)
    improvement_count = sum(1 for d in deltas if d > 0)

    # Fail if mean_delta falls below -threshold (5% degradation on average)
    threshold_pass = mean_delta >= -threshold

    return {
        "mean_delta": round(mean_delta, 6),
        "std_delta": round(std_delta, 6),
        "degradation_count": degradation_count,
        "improvement_count": improvement_count,
        "threshold_pass": threshold_pass,
        "threshold_used": threshold,
        "pairs_evaluated": len(common_ids),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compute paired-delta between eval baseline and current results.",
    )
    parser.add_argument("--baseline", required=True, metavar="PATH",
                        help="Path to baseline JSON scores")
    parser.add_argument("--current", required=True, metavar="PATH",
                        help="Path to current JSON scores")
    parser.add_argument("--threshold", type=float, default=None, metavar="FLOAT",
                        help="Degradation threshold (default: SAVIA_EVAL_DELTA_THRESHOLD or 0.05)")

    args = parser.parse_args()

    # Threshold: CLI arg > env var > default 0.05
    if args.threshold is not None:
        threshold = args.threshold
    else:
        env_threshold = os.environ.get("SAVIA_EVAL_DELTA_THRESHOLD")
        threshold = float(env_threshold) if env_threshold else 0.05

    try:
        baseline_scores = load_scores(args.baseline)
        current_scores = load_scores(args.current)
    except (json.JSONDecodeError, KeyError, ValueError) as exc:
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        sys.exit(1)

    result = compute_paired_delta(baseline_scores, current_scores, threshold)
    print(json.dumps(result, indent=2))

    # Exit code: 0 = pass, 1 = degradation detected
    sys.exit(0 if result["threshold_pass"] else 1)


if __name__ == "__main__":
    main()
